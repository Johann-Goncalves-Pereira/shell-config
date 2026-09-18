//! Best-effort report of what may be holding the headset mic.

use crate::devices::stdout_utf8;
use crate::error::Result;
use crate::hide;
use crate::runner::CommandRunner;

pub fn report(runner: &dyn CommandRunner) -> Result<String> {
    let mut lines = Vec::new();
    lines.push("Looking for what's using the mic...".to_string());
    append_hide_status(runner, &mut lines);
    append_frontmost(runner, &mut lines);
    append_tcc(runner, &mut lines);
    Ok(lines.join("\n"))
}

fn append_hide_status(runner: &dyn CommandRunner, lines: &mut Vec<String>) {
    let Ok(status) = hide::status(runner) else {
        return;
    };
    for line in status.lines() {
        lines.push(format!("  {line}"));
    }
}

fn append_frontmost(runner: &dyn CommandRunner, lines: &mut Vec<String>) {
    let Ok(front) = frontmost(runner) else {
        return;
    };
    if front.is_empty() {
        return;
    }
    lines.push(format!("  Frontmost app: {front}"));
}

fn append_tcc(runner: &dyn CommandRunner, lines: &mut Vec<String>) {
    let Ok(tcc) = tcc_mic_log(runner) else {
        return;
    };
    if tcc.trim().is_empty() {
        return;
    }
    lines.push("  Recent microphone TCC log:".to_string());
    push_tcc_lines(lines, &tcc);
}

fn push_tcc_lines(lines: &mut Vec<String>, tcc: &str) {
    for line in tcc.lines().take(8) {
        lines.push(format!("    {line}"));
    }
}

fn frontmost(runner: &dyn CommandRunner) -> Result<String> {
    let out = runner.output(
        "osascript",
        &[
            "-e",
            "tell application \"System Events\" to get name of first application process whose frontmost is true",
        ],
    )?;
    Ok(stdout_utf8(&out).trim().to_string())
}

fn tcc_mic_log(runner: &dyn CommandRunner) -> Result<String> {
    let out = runner.output(
        "log",
        &[
            "show",
            "--last",
            "2m",
            "--style",
            "compact",
            "--predicate",
            "subsystem == \"com.apple.TCC\" AND composedMessage CONTAINS[c] \"Microphone\"",
        ],
    )?;
    Ok(stdout_utf8(&out))
}
