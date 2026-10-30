//! Mac LaunchAgent: re-arm tcpip on USB, reconnect Tailscale/LAN/mDNS.

use std::path::{Path, PathBuf};

use crate::adb;
use crate::config::Config;
use crate::error::{AgentError, Result};
use crate::runner::{CommandRunner, Wait};
use crate::transport;

pub const LABEL: &str = "com.shell-config.phone-watch";
pub const POLL_SECS: u64 = 15;

pub fn plist_path() -> PathBuf {
    home()
        .join("Library/LaunchAgents")
        .join(format!("{LABEL}.plist"))
}

pub fn log_path() -> PathBuf {
    home().join("Library/Logs/phone-watch.log")
}

fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

pub fn release_bin() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/release/phone")
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
        path: plist.clone(),
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
		<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:{home_s}/Library/Android/sdk/platform-tools</string>
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
    let bin = release_bin();
    if !bin.is_file() {
        return Err(AgentError::MissingBinary { path: bin }.into());
    }
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
        let detail = String::from_utf8_lossy(&out.stderr).into_owned()
            + &String::from_utf8_lossy(&out.stdout);
        Err(AgentError::Bootstrap { detail }.into())
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
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

pub fn guard_loop(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    eprintln!(
        "phone-watch started (poll={POLL_SECS}s) serial={}",
        cfg.read_serial()
    );
    let mut usb_was_present = false;
    let mut was_reachable = false;
    loop {
        guard_tick(runner, wait, cfg, &mut usb_was_present, &mut was_reachable);
        wait.wait_ms(POLL_SECS * 1000);
    }
}

fn guard_tick(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
    usb_was_present: &mut bool,
    was_reachable: &mut bool,
) {
    let serial = cfg.read_serial();
    let sight = crate::doctor::probe_samsung_usb(runner);
    let state = adb::device_state(runner, &serial);
    let usb_now = state.as_deref() == Some("device");

    if sight.present && !usb_now {
        recover_silent_cable(runner, cfg, &sight, state.as_deref());
    }

    if usb_now {
        // Re-force every poll while cabled — Samsung Auto Wi‑Fi / USB mode flips.
        let _ = crate::persist::force_wifi_always_on(runner, &serial, false);
        let _ = crate::persist::force_usb_lab_mode(runner, &serial, false);
        if !*usb_was_present {
            on_usb_authorized(runner, wait, cfg, &serial);
        }
    }
    *usb_was_present = usb_now;

    match transport::transport(runner, cfg) {
        Ok(t) => {
            if !*was_reachable {
                eprintln!("reachable via {t}");
            }
            *was_reachable = true;
            maybe_periodic_backup(cfg);
        }
        Err(_) => {
            if *was_reachable {
                eprintln!("unreachable — will retry");
            }
            *was_reachable = false;
        }
    }
}

fn on_usb_authorized(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
    serial: &str,
) {
    eprintln!("USB appeared ({serial}) — re-arming tcpip {DEFAULT_PORT}");
    match transport::tcpip(runner, wait, cfg, DEFAULT_PORT) {
        Ok(()) => eprintln!("tcpip re-armed"),
        Err(e) => eprintln!("tcpip re-arm failed: {e}"),
    }
    if cfg.read_pin().is_some() {
        match crate::control::unlock(runner, cfg, None, false) {
            Ok(()) => eprintln!("unlock keystrokes sent"),
            Err(e) => eprintln!("unlock skipped: {e}"),
        }
    }
}

fn recover_silent_cable(
    runner: &dyn CommandRunner,
    cfg: &Config,
    sight: &crate::doctor::SamsungUsb,
    adb_state: Option<&str>,
) {
    use crate::doctor::UsbMode;
    let serial = sight.serial.as_deref().unwrap_or("?");
    match (sight.mode, sight.adb_interface) {
        (UsbMode::Rndis, _) => eprintln!(
            "cable: Samsung {serial} RNDIS/tether — flipping to MTP via wireless ADB"
        ),
        (UsbMode::Mtp, false) => eprintln!(
            "cable: Samsung {serial} MTP without ADB iface — unlock + force MTP via wireless"
        ),
        (UsbMode::Mtp, true) => {
            eprintln!(
                "cable: Samsung {serial} MTP+ADB but adb state={adb_state:?} — bouncing adbd client"
            );
            let _ = runner.output("adb", &["kill-server"]);
            let _ = runner.output("adb", &["start-server"]);
            poke_saved_hosts(runner, cfg);
        }
        (UsbMode::Other, adb_iface) => eprintln!(
            "cable: Samsung {serial} other usb mode adb_iface={adb_iface} — force MTP via wireless"
        ),
        (UsbMode::Absent, _) => {}
    }
    if adb_state == Some("unauthorized") {
        eprintln!(
            "cable: unauthorized — this Mac’s adbkey ≠ lab key (phone doctor --save / copy adbkey*)"
        );
    }
    // RNDIS/no-ADB-iface cannot be fixed on the cable itself — need LAN/WAN adbd.
    let needs_mtp_flip = matches!(
        (sight.mode, sight.adb_interface),
        (UsbMode::Rndis, _) | (UsbMode::Mtp, false) | (UsbMode::Other, _)
    );
    if needs_mtp_flip {
        repair_usb_mode_over_wireless(runner, cfg);
    }
}

fn repair_usb_mode_over_wireless(runner: &dyn CommandRunner, cfg: &Config) {
    if cfg.read_pin().is_some() {
        let _ = crate::control::unlock(runner, cfg, None, false);
    }
    match crate::persist::force_mtp_via_reachable(runner, cfg) {
        Ok(t) => eprintln!(
            "cable: forced File transfer/MTP via {t} (USB ADB should reappear)"
        ),
        Err(e) => eprintln!(
            "cable: cannot flip USB mode — wireless ADB down ({e}); keep Wi‑Fi/Tailscale up"
        ),
    }
}

fn poke_saved_hosts(runner: &dyn CommandRunner, cfg: &Config) {
    for host in [cfg.read_host(), cfg.read_wan_host()].into_iter().flatten() {
        let _ = adb::adb_connect(runner, &host);
    }
}

fn maybe_periodic_backup(cfg: &Config) {
    let stamp_file = cfg.dir().join("last_backup_epoch");
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    let last = std::fs::read_to_string(&stamp_file)
        .ok()
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(0);

    // 24 hours = 86400 seconds
    if now.saturating_sub(last) >= 86400 {
        let _ = std::fs::write(&stamp_file, now.to_string());
        let bin = release_bin();
        if bin.is_file() {
            eprintln!("starting scheduled 24h background backup...");
            let _ = std::process::Command::new(bin)
                .arg("backup")
                .stdin(std::process::Stdio::null())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn();
        }
    }
}

const DEFAULT_PORT: u16 = crate::config::DEFAULT_ADB_PORT;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runner::{RecordingWait, ScriptedRunner};
    use std::cell::RefCell;
    use std::collections::HashMap;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn plist_body_contains_label_and_guard() -> Result<()> {
        let body = plist_body(Path::new("/tmp/phone"), Path::new("/tmp/log"));
        assert!(body.contains(LABEL));
        assert!(body.contains("guard"));
        assert!(body.contains("/tmp/phone"));
        Ok(())
    }

    #[test]
    fn guard_tick_rearms_tcpip_when_usb_appears() -> Result<()> {
        let mut replies = HashMap::new();
        replies.insert(
            "ip -f inet addr show wlan0".into(),
            "46: wlan0:\n    inet 192.0.2.10/24\n".into(),
        );
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTESTSERIAL\tdevice\n".into(),
            shell_replies: RefCell::new(replies),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
            ioreg: RefCell::new(None),
        };
        let wait = RecordingWait {
            calls: RefCell::new(Vec::new()),
        };
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| std::io::Error::other(e.to_string()))?
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("phone-guard-{stamp}"));
        let cfg = Config::with_dir("TESTSERIAL".into(), dir)?;
        let mut usb_was = false;
        let mut reachable = false;
        guard_tick(&runner, &wait, &cfg, &mut usb_was, &mut reachable);
        assert!(usb_was);
        assert!(reachable);
        assert!(wait.calls.borrow().contains(&1500));
        Ok(())
    }
}
