//! Push Termux USB MTP guard (boot + background loop) while ADB is available.

use std::path::PathBuf;

use crate::adb;
use crate::config::Config;
use crate::error::{AdbError, Result};
use crate::runner::{CommandRunner, Wait};
use crate::transport;

const REMOTE_DIR: &str = "/sdcard/phone-lab";
const PKGS: &[&str] = &["com.termux", "com.termux.boot", "com.termux.tasker"];

/// Install/update scripts on device and (re)start the Termux background guard.
pub fn install(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    push_assets(runner, cfg, &t)?;
    whitelist_termux(runner, &t);
    run_bootstrap_in_termux(runner, wait, &t)?;
    read_bootstrap_result(runner, &t)
}

fn push_assets(
    runner: &dyn CommandRunner,
    cfg: &Config,
    t: &str,
) -> Result<()> {
    let local = guard_dir();
    adb::adb_status(runner, &["-s", t, "shell", "mkdir", "-p", REMOTE_DIR])?;
    for name in ["usb-lab-guard.sh", "bootstrap.sh", "probe.sh"] {
        push_one(
            runner,
            t,
            &local.join(name),
            &format!("{REMOTE_DIR}/{name}"),
        )?;
    }
    let key = home().join(".android/adbkey");
    let pub_key = home().join(".android/adbkey.pub");
    if key.is_file() {
        push_one(runner, t, &key, &format!("{REMOTE_DIR}/adbkey"))?;
    }
    if pub_key.is_file() {
        push_one(runner, t, &pub_key, &format!("{REMOTE_DIR}/adbkey.pub"))?;
    }
    let ssh_pub = cfg.dir().join("id_phone_ed25519.pub");
    if ssh_pub.is_file() {
        push_one(
            runner,
            t,
            &ssh_pub,
            &format!("{REMOTE_DIR}/id_phone_ed25519.pub"),
        )?;
    }
    Ok(())
}

fn push_one(
    runner: &dyn CommandRunner,
    t: &str,
    src: &std::path::Path,
    dest: &str,
) -> Result<()> {
    if !src.is_file() {
        return Err(AdbError::CommandFailed {
            args: format!("missing {}", src.display()),
            stderr: "termux-usb-guard assets not found next to crate".into(),
        }
        .into());
    }
    adb::adb_status(runner, &["-s", t, "push", &src.to_string_lossy(), dest])
}

fn whitelist_termux(runner: &dyn CommandRunner, t: &str) {
    for pkg in PKGS {
        let _ = adb::shell(
            runner,
            t,
            &format!("dumpsys deviceidle whitelist +{pkg}"),
        );
        let _ = adb::shell(
            runner,
            t,
            &format!("cmd appops set {pkg} RUN_IN_BACKGROUND allow"),
        );
        let _ = adb::shell(
            runner,
            t,
            &format!("cmd appops set {pkg} RUN_ANY_IN_BACKGROUND allow"),
        );
    }
}

fn run_bootstrap_in_termux(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    t: &str,
) -> Result<()> {
    let _ = adb::adb(
        runner,
        &[
            "-s",
            t,
            "shell",
            "monkey",
            "-p",
            "com.termux.boot",
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        ],
    );
    wait.wait_ms(800);
    adb::adb_status(
        runner,
        &[
            "-s",
            t,
            "shell",
            "am",
            "start",
            "-n",
            "com.termux/.app.TermuxActivity",
        ],
    )?;
    wait.wait_ms(600);
    adb::adb_status(
        runner,
        &[
            "-s",
            t,
            "shell",
            "input",
            "text",
            "bash%s/sdcard/phone-lab/bootstrap.sh",
        ],
    )?;
    adb::adb_status(
        runner,
        &["-s", t, "shell", "input", "keyevent", "KEYCODE_ENTER"],
    )?;
    wait.wait_ms(8000);
    Ok(())
}

fn read_bootstrap_result(runner: &dyn CommandRunner, t: &str) -> Result<()> {
    let result =
        adb::shell(runner, t, "cat /sdcard/phone-lab/bootstrap-result.txt")
            .unwrap_or_default();
    let result = result.trim();
    if result.starts_with("ok") {
        println!("Termux USB guard: {result}");
        return Ok(());
    }
    Err(AdbError::CommandFailed {
        args: "termux bootstrap".into(),
        stderr: format!(
            "bootstrap-result={result:?} — open Termux once if empty, then: phone termux-guard"
        ),
    }
    .into())
}

fn guard_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("termux-usb-guard")
}

fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}
