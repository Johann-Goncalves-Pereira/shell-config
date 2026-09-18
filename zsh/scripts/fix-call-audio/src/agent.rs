//! LaunchAgent install and long-running guard loop.

use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use crate::devices;
use crate::enforce::{self, EnforceOpts};
use crate::error::{AgentError, Result};
use crate::hide;
use crate::runner::{CommandRunner, Wait};
use crate::session;

pub const LABEL: &str = "com.shell-config.fix-call-audio";
pub const POLL_SECS: u64 = 2;
pub const RECONNECT_COOLDOWN_SECS: u64 = 20;

pub fn plist_path() -> PathBuf {
    home()
        .join("Library/LaunchAgents")
        .join(format!("{LABEL}.plist"))
}

pub fn log_path() -> PathBuf {
    home().join("Library/Logs/fix-call-audio-guard.log")
}

pub fn session_path() -> PathBuf {
    session::default_path()
}

fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

pub fn release_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("target/release/fix-call-audio")
}

pub fn write_plist(bin: &Path) -> Result<()> {
    let plist = plist_path();
    if let Some(parent) = plist.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let log = log_path();
    if let Some(parent) = log.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let body = plist_body(bin, &log);
    std::fs::write(&plist, body).map_err(|source| AgentError::WritePlist {
        path: plist,
        source,
    })?;
    Ok(())
}

fn plist_body(bin: &Path, log: &Path) -> String {
    let bin_s = bin.display().to_string();
    let log_s = log.display().to_string();
    let home_s = home().display().to_string();
    let root = env!("CARGO_MANIFEST_DIR");
    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>{LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>{bin_s}</string>
		<string>guard</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>{log_s}</string>
	<key>StandardErrorPath</key>
	<string>{log_s}</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
		<key>HOME</key>
		<string>{home_s}</string>
		<key>CARGO_MANIFEST_DIR</key>
		<string>{root}</string>
	</dict>
</dict>
</plist>
"#
    )
}

pub fn watch(runner: &dyn CommandRunner) -> Result<()> {
    devices::ensure_switch_audio(runner)?;
    devices::ensure_blueutil(runner)?;
    let _ = hide::ensure_built(runner)?;
    let bin = release_bin();
    write_plist(&bin)?;
    let uid = user_id(runner)?;
    let domain = format!("gui/{uid}");
    let label_path = format!("{domain}/{LABEL}");
    let _ = runner.output("launchctl", &["bootout", &label_path]);
    let plist = plist_path();
    let plist_s = plist.to_string_lossy().into_owned();
    let out = runner.output("launchctl", &["bootstrap", &domain, &plist_s])?;
    if out.status.success() {
        println!("Watching: {LABEL} (log: {})", log_path().display());
        Ok(())
    } else {
        Err(AgentError::Bootstrap {
            detail: devices::stdout_utf8(&out),
        }
        .into())
    }
}

pub fn unwatch(runner: &dyn CommandRunner) -> Result<()> {
    let uid = user_id(runner)?;
    let label_path = format!("gui/{uid}/{LABEL}");
    let _ = runner.output("launchctl", &["bootout", &label_path]);
    let plist = plist_path();
    if plist.exists() {
        std::fs::remove_file(&plist)?;
    }
    println!("Stopped: {LABEL}");
    Ok(())
}

fn user_id(runner: &dyn CommandRunner) -> Result<String> {
    let out = runner.output("id", &["-u"])?;
    Ok(devices::stdout_utf8(&out).trim().to_string())
}

pub fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

pub fn guard_loop(runner: &dyn CommandRunner, wait: &dyn Wait) -> Result<()> {
    eprintln!(
        "{} started (poll={POLL_SECS}s cooldown={RECONNECT_COOLDOWN_SECS}s mode=hide-bt-mic-on-hfp)",
        log_ts()
    );
    let mut last_reconnect: u64 = 0;
    let mut last_bt_uid = String::new();
    loop {
        guard_tick(runner, wait, &mut last_reconnect, &mut last_bt_uid)?;
        wait.wait_ms(POLL_SECS * 1000);
    }
}

fn log_ts() -> String {
    // Prefer shell date for consistency with old logs; fall back to unix secs.
    format!("{}", now_secs())
}

fn guard_tick(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    last_reconnect: &mut u64,
    last_bt_uid: &mut String,
) -> Result<()> {
    if devices::ensure_switch_audio(runner).is_err() {
        return Ok(());
    }
    let list = match devices::list_cli(runner) {
        Ok(l) => l,
        Err(_) => return Ok(()),
    };
    let current_out = devices::current(runner, "output").unwrap_or_default();
    let uid = devices::bt_output_uid(&list, &current_out).unwrap_or_default();
    track_connection(&uid, last_bt_uid);
    session::sync(
        &session_path(),
        if uid.is_empty() { None } else { Some(&uid) },
    )?;

    let Ok(output) = devices::default_output(&list, &current_out) else {
        return Ok(());
    };
    let Ok(input) = devices::default_input(&list) else {
        return Ok(());
    };

    if enforce::hfp_active(runner, &list)? {
        return handle_hfp(runner, wait, &input, &output, last_reconnect);
    }
    maintain_session(runner, &input, &output)
}

fn track_connection(uid: &str, last_bt_uid: &mut String) {
    if !last_bt_uid.is_empty() && !uid.is_empty() && uid != last_bt_uid.as_str()
    {
        eprintln!(
            "{} new BT connection ({uid}) — mic available until HFP / fix-call-audio",
            log_ts()
        );
        let _ = session::clear(&session_path());
    }
    if uid.is_empty() && !last_bt_uid.is_empty() {
        eprintln!("{} BT output gone — clearing hide session", log_ts());
        let _ = session::clear(&session_path());
    }
    *last_bt_uid = uid.to_string();
}

fn handle_hfp(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    input: &str,
    output: &str,
    last_reconnect: &mut u64,
) -> Result<()> {
    let now = now_secs();
    if now.saturating_sub(*last_reconnect) < RECONNECT_COOLDOWN_SECS {
        let _ = devices::set_device(runner, "input", input);
        let _ = hide::run_hide(runner, true);
        return Ok(());
    }
    eprintln!(
        "{} HFP detected → hide BT mic + reconnect {output}",
        log_ts()
    );
    let opts = EnforceOpts {
        quiet: true,
        reset: true,
        force_hide: true,
        input: Some(input.to_string()),
        output: Some(output.to_string()),
        session_path: session_path(),
    };
    match enforce::enforce(runner, wait, &opts) {
        Ok(report) => {
            *last_reconnect = now;
            if report.hfp_after {
                eprintln!("{} reconnected but still HFP — re-hiding", log_ts());
                let _ = hide::run_hide(runner, true);
            } else {
                eprintln!(
                    "{} restored A2DP; BT mic hidden for this connection",
                    log_ts()
                );
            }
        }
        Err(e) => eprintln!("{} enforce failed: {e}", log_ts()),
    }
    Ok(())
}

fn maintain_session(
    runner: &dyn CommandRunner,
    input: &str,
    output: &str,
) -> Result<()> {
    let list = devices::list_cli(runner)?;
    let current_out = devices::current(runner, "output")?;
    let uid = devices::bt_output_uid(&list, &current_out);
    if session::should_hide(&session_path(), uid.as_deref())? {
        let current_in = devices::current(runner, "input")?;
        if current_in != input {
            eprintln!(
                "{} session hide active — input {current_in} → {input}",
                log_ts()
            );
            let _ = devices::set_device(runner, "input", input);
        }
        let _ = hide::run_hide(runner, true);
    }
    let current_out_now = devices::current(runner, "output")?;
    if current_out_now != output {
        eprintln!(
            "{} output drifted to '{current_out_now}' → {output}",
            log_ts()
        );
        let _ = devices::set_device(runner, "output", output);
    }
    Ok(())
}
