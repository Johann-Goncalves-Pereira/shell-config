//! Test doubles for [`crate::runner`] (cfg(test) only via path include).

use super::CommandRunner;
use super::Wait;
use std::cell::RefCell;
use std::collections::HashMap;
use std::os::unix::process::ExitStatusExt;
use std::process::{ExitStatus, Output};

pub struct ScriptedRunner {
    pub which_adb: bool,
    pub devices: String,
    pub shell_replies: RefCell<HashMap<String, String>>,
    pub puts: RefCell<Vec<(String, String, String)>>,
    /// Bytes returned by `adb exec-out …` (e.g. screencap PNG).
    pub exec_out: RefCell<Option<Vec<u8>>>,
    /// stdout for `adb mdns services`
    pub mdns: RefCell<Option<String>>,
    /// Recorded `adb shell …` command strings (after transport).
    pub shells: RefCell<Vec<String>>,
}

impl CommandRunner for ScriptedRunner {
    fn output(&self, bin: &str, args: &[&str]) -> crate::error::Result<Output> {
        dispatch(self, bin, args)
    }

    fn status_inherit(
        &self,
        _bin: &str,
        _args: &[&str],
    ) -> crate::error::Result<()> {
        Ok(())
    }
}

fn dispatch(
    runner: &ScriptedRunner,
    bin: &str,
    args: &[&str],
) -> crate::error::Result<Output> {
    let ok = ExitStatus::from_raw(0);
    let fail = ExitStatus::from_raw(1 << 8);
    if bin == "which" && args == ["adb"] {
        return Ok(which_adb_output(runner.which_adb, ok, fail));
    }
    if bin == "adb" && (args == ["devices"] || args == ["devices", "-l"]) {
        return Ok(bytes_ok(ok, runner.devices.as_bytes()));
    }
    if bin == "adb" && args == ["mdns", "services"] {
        let text = runner
            .mdns
            .borrow()
            .clone()
            .unwrap_or_else(|| "List of discovered mdns services\n".into());
        return Ok(bytes_ok(ok, text.as_bytes()));
    }
    if bin == "adb" && args.len() == 4 && args[2] == "tcpip" {
        return Ok(bytes_ok(ok, b"restarting in TCP mode\n"));
    }
    if bin == "adb" && args.len() >= 4 && args[2] == "exec-out" {
        let data = runner
            .exec_out
            .borrow()
            .clone()
            .unwrap_or_else(|| b"PNG".to_vec());
        return Ok(bytes_ok(ok, &data));
    }
    if bin == "adb" && args.len() >= 4 && args[2] == "shell" {
        return scripted_shell(runner, args, ok);
    }
    if bin == "adb" && args.first() == Some(&"connect") {
        return Ok(bytes_ok(ok, b"connected\n"));
    }
    if bin == "tailscale" && args.len() == 3 && args[0] == "ip" {
        return Ok(bytes_ok(fail, b""));
    }
    Ok(bytes_ok(fail, b"unhandled\n"))
}

fn which_adb_output(present: bool, ok: ExitStatus, fail: ExitStatus) -> Output {
    if present {
        bytes_ok(ok, b"/usr/bin/adb\n")
    } else {
        bytes_ok(fail, b"")
    }
}

fn bytes_ok(status: ExitStatus, stdout: &[u8]) -> Output {
    Output {
        status,
        stdout: stdout.to_vec(),
        stderr: Vec::new(),
    }
}

fn scripted_shell(
    runner: &ScriptedRunner,
    args: &[&str],
    ok: ExitStatus,
) -> crate::error::Result<Output> {
    let cmd = args[3..].join(" ");
    runner.shells.borrow_mut().push(cmd.clone());
    if let Some(out) = handle_settings_put(runner, &cmd, ok) {
        return Ok(out);
    }
    if let Some(out) = handle_settings_get(runner, &cmd, ok) {
        return Ok(out);
    }
    if let Some(val) = runner.shell_replies.borrow().get(&cmd) {
        return Ok(bytes_ok(ok, format!("{val}\n").as_bytes()));
    }
    Ok(bytes_ok(ok, b""))
}

fn handle_settings_put(
    runner: &ScriptedRunner,
    cmd: &str,
    ok: ExitStatus,
) -> Option<Output> {
    let rest = cmd.strip_prefix("settings put ")?;
    let parts: Vec<&str> = rest.split_whitespace().collect();
    if parts.len() >= 3 {
        runner.puts.borrow_mut().push((
            parts[0].to_string(),
            parts[1].to_string(),
            parts[2..].join(" "),
        ));
    }
    Some(bytes_ok(ok, b""))
}

fn handle_settings_get(
    runner: &ScriptedRunner,
    cmd: &str,
    ok: ExitStatus,
) -> Option<Output> {
    let key = cmd.strip_prefix("settings get ")?;
    let val = runner
        .shell_replies
        .borrow()
        .get(key)
        .cloned()
        .unwrap_or_else(|| "null".into());
    Some(bytes_ok(ok, format!("{val}\n").as_bytes()))
}

pub struct RecordingWait {
    pub calls: RefCell<Vec<u64>>,
}

impl Wait for RecordingWait {
    fn wait_ms(&self, ms: u64) {
        self.calls.borrow_mut().push(ms);
    }
}
