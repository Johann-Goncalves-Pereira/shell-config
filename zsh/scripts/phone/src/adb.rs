//! ADB helpers over an injected [`CommandRunner`].

use std::process::Output;

use crate::error::{AdbError, Result};
use crate::runner::CommandRunner;

pub fn require_adb(runner: &dyn CommandRunner) -> Result<()> {
    let out = runner.output("which", &["adb"])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(AdbError::MissingBinary.into())
    }
}

pub fn require_scrcpy(runner: &dyn CommandRunner) -> Result<()> {
    let out = runner.output("which", &["scrcpy"])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(AdbError::MissingScrcpy.into())
    }
}

pub fn adb(runner: &dyn CommandRunner, args: &[&str]) -> Result<Output> {
    require_adb(runner)?;
    runner.output("adb", args)
}

pub fn adb_status(runner: &dyn CommandRunner, args: &[&str]) -> Result<()> {
    let out = adb(runner, args)?;
    if out.status.success() {
        return Ok(());
    }
    Err(AdbError::CommandFailed {
        args: args.join(" "),
        stderr: merge_streams(&out),
    }
    .into())
}

pub fn adb_stdout(runner: &dyn CommandRunner, args: &[&str]) -> Result<String> {
    let out = adb(runner, args)?;
    Ok(trim_output(&out.stdout))
}

pub fn adb_ok(runner: &dyn CommandRunner, args: &[&str]) -> bool {
    adb(runner, args)
        .map(|o| o.status.success())
        .unwrap_or(false)
}

pub fn authorized_transports(
    runner: &dyn CommandRunner,
) -> Result<Vec<String>> {
    let text = adb_stdout(runner, &["devices"])?;
    Ok(parse_device_lines(&text))
}

pub fn is_device(runner: &dyn CommandRunner, id: &str) -> bool {
    authorized_transports(runner)
        .ok()
        .is_some_and(|t| t.iter().any(|x| x == id))
}

pub fn shell(
    runner: &dyn CommandRunner,
    transport: &str,
    cmd: &str,
) -> Result<String> {
    adb_stdout(runner, &["-s", transport, "shell", cmd])
}

/// `adb -s TRANSPORT exec-out ARGS...` — binary-safe stdout (e.g. screencap).
pub fn exec_out(
    runner: &dyn CommandRunner,
    transport: &str,
    args: &[&str],
) -> Result<Vec<u8>> {
    require_adb(runner)?;
    let mut v: Vec<&str> = vec!["-s", transport, "exec-out"];
    v.extend_from_slice(args);
    let out = runner.output("adb", &v)?;
    if out.status.success() {
        return Ok(out.stdout);
    }
    Err(AdbError::CommandFailed {
        args: v.join(" "),
        stderr: merge_streams(&out),
    }
    .into())
}

pub fn settings_get(
    runner: &dyn CommandRunner,
    transport: &str,
    ns: &str,
    key: &str,
) -> Result<String> {
    shell(runner, transport, &format!("settings get {ns} {key}"))
}

pub fn settings_put(
    runner: &dyn CommandRunner,
    transport: &str,
    ns: &str,
    key: &str,
    val: &str,
) -> Result<()> {
    if val == "null" {
        let _ = adb(
            runner,
            &["-s", transport, "shell", "settings", "delete", ns, key],
        );
        return Ok(());
    }
    adb_status(
        runner,
        &["-s", transport, "shell", "settings", "put", ns, key, val],
    )
}

pub fn wifi_ip(runner: &dyn CommandRunner, transport: &str) -> Result<String> {
    let raw = shell(runner, transport, "ip -f inet addr show wlan0")?;
    parse_wlan_ip(&raw).ok_or_else(|| AdbError::NoWifiIp.into())
}

pub fn tailscale_ip(
    runner: &dyn CommandRunner,
    transport: &str,
) -> Option<String> {
    if let Ok(ip) = shell(
        runner,
        transport,
        "command -v tailscale >/dev/null && tailscale ip -4",
    ) {
        let ip = ip.trim().to_string();
        if ip.starts_with("100.") {
            return Some(ip);
        }
    }
    let raw = shell(runner, transport, "ip -f inet addr show").ok()?;
    parse_tailscale_ip(&raw)
}

/// Resolve the phone's Tailscale IPv4 from the Mac CLI (no USB needed).
pub fn mac_tailscale_peer_ip(
    runner: &dyn CommandRunner,
    peer: &str,
) -> Option<String> {
    let out = runner.output("tailscale", &["ip", "-4", peer]).ok()?;
    if !out.status.success() {
        return None;
    }
    let ip = trim_output(&out.stdout);
    if ip.starts_with("100.") {
        Some(ip)
    } else {
        None
    }
}

pub fn devices_l(runner: &dyn CommandRunner) -> Result<String> {
    adb_stdout(runner, &["devices", "-l"])
}

pub fn run_inherit(
    runner: &dyn CommandRunner,
    bin: &str,
    args: &[&str],
) -> Result<()> {
    runner.status_inherit(bin, args)
}

fn merge_streams(out: &Output) -> String {
    let mut s = String::from_utf8_lossy(&out.stdout).into_owned();
    s.push_str(&String::from_utf8_lossy(&out.stderr));
    s
}

fn trim_output(bytes: &[u8]) -> String {
    String::from_utf8_lossy(bytes)
        .trim_end_matches(['\r', '\n'])
        .to_string()
}

fn parse_device_lines(text: &str) -> Vec<String> {
    let mut out = Vec::new();
    for line in text.lines().skip(1) {
        let mut parts = line.split_whitespace();
        let Some(id) = parts.next() else {
            continue;
        };
        let Some(state) = parts.next() else {
            continue;
        };
        if state == "device" {
            out.push(id.to_string());
        }
    }
    out
}

fn parse_wlan_ip(raw: &str) -> Option<String> {
    for line in raw.lines() {
        let line = line.trim();
        let Some(rest) = line.strip_prefix("inet ") else {
            continue;
        };
        let ip = rest.split('/').next().unwrap_or("").trim();
        if !ip.is_empty() {
            return Some(ip.to_string());
        }
    }
    None
}

fn parse_tailscale_ip(raw: &str) -> Option<String> {
    for line in raw.lines() {
        let line = line.trim();
        let Some(rest) = line.strip_prefix("inet ") else {
            continue;
        };
        let ip = rest.split('/').next().unwrap_or("").trim();
        if ip.starts_with("100.") {
            return Some(ip.to_string());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_devices_table() -> Result<()> {
        let text = "List of devices attached\nRXC\tdevice\n1.2.3.4:5555\tunauthorized\n";
        let ids = parse_device_lines(text);
        assert_eq!(ids, vec!["RXC".to_string()]);
        Ok(())
    }

    #[test]
    fn parse_wifi_and_tailscale() -> Result<()> {
        let wlan = "46: wlan0: ...\n    inet 192.0.2.10/24 brd ...\n";
        assert_eq!(parse_wlan_ip(wlan).as_deref(), Some("192.0.2.10"));
        let all = "inet 192.0.2.10/24\ninet 100.64.1.2/32\n";
        assert_eq!(parse_tailscale_ip(all).as_deref(), Some("100.64.1.2"));
        Ok(())
    }
}
