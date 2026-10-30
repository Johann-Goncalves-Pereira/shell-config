//! Host + USB diagnostics so a “missing” cable never stays silent.

use std::path::{Path, PathBuf};

use serde::Serialize;

use crate::adb;
use crate::agent;
use crate::config::Config;
use crate::error::Result;
use crate::json_out;
use crate::runner::CommandRunner;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CheckStatus {
    Ok,
    Warn,
    Fail,
}

#[derive(Debug, Clone, Serialize)]
pub struct Check {
    pub name: String,
    pub status: CheckStatus,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct DoctorReport {
    pub ok: bool,
    pub checks: Vec<Check>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SamsungUsb {
    pub present: bool,
    pub serial: Option<String>,
    pub id_product: Option<u32>,
    pub mode: UsbMode,
    pub adb_interface: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum UsbMode {
    Absent,
    Mtp,
    Rndis,
    Other,
}

/// Run host checks. With `--save`, store this Mac’s `adbkey.pub` as the lab expected key.
pub fn doctor(
    runner: &dyn CommandRunner,
    cfg: &Config,
    save_expected_key: bool,
    json: bool,
) -> Result<()> {
    if save_expected_key {
        save_expected_adbkey_pub(cfg)?;
    }
    let report = collect(runner, cfg);
    if json {
        return json_out::print_ok(&report);
    }
    print_human(&report);
    if report.ok {
        Ok(())
    } else {
        Err(crate::error::AdbError::DoctorFailed.into())
    }
}

fn print_human(report: &DoctorReport) {
    for c in &report.checks {
        let tag = match c.status {
            CheckStatus::Ok => "ok  ",
            CheckStatus::Warn => "warn",
            CheckStatus::Fail => "fail",
        };
        println!("[{tag}] {}: {}", c.name, c.detail);
    }
    if report.ok {
        println!("doctor: pass");
    } else {
        println!("doctor: FAIL — fix fail items before expecting cable ADB");
    }
}

pub fn collect(runner: &dyn CommandRunner, cfg: &Config) -> DoctorReport {
    let serial = cfg.read_serial();
    let checks = vec![
        check_adb_bin(runner),
        check_host_adbkey(),
        check_expected_adbkey(cfg),
        check_pin(cfg),
        check_watch_agent(),
        check_adb_devices(runner, &serial),
        check_samsung_usb(runner, &serial),
        check_saved_hosts(runner, cfg),
        crate::ssh_ops::check_ssh(cfg),
    ];
    let ok = !checks.iter().any(|c| c.status == CheckStatus::Fail);
    DoctorReport { ok, checks }
}

fn check_adb_bin(runner: &dyn CommandRunner) -> Check {
    match adb::require_adb(runner) {
        Ok(()) => check("adb", CheckStatus::Ok, "adb on PATH"),
        Err(e) => check("adb", CheckStatus::Fail, e.to_string()),
    }
}

fn check_host_adbkey() -> Check {
    let path = adbkey_pub_path();
    if path.is_file() {
        check(
            "adbkey",
            CheckStatus::Ok,
            format!("present ({})", path.display()),
        )
    } else {
        check(
            "adbkey",
            CheckStatus::Fail,
            format!(
                "missing {} — copy lab ~/.android/adbkey* to this Mac",
                path.display()
            ),
        )
    }
}

fn check_expected_adbkey(cfg: &Config) -> Check {
    let expected = cfg.expected_adbkey_pub_path();
    if !expected.is_file() {
        return check(
            "adbkey_match",
            CheckStatus::Warn,
            "no expected-adbkey.pub — run: phone doctor --save (on the trusted Mac)",
        );
    }
    let Some(want) = read_pub_token(&expected) else {
        return check(
            "adbkey_match",
            CheckStatus::Fail,
            "expected-adbkey.pub unreadable",
        );
    };
    let Some(got) = read_pub_token(&adbkey_pub_path()) else {
        return check(
            "adbkey_match",
            CheckStatus::Fail,
            "local adbkey.pub missing — cannot match lab key",
        );
    };
    if want == got {
        check(
            "adbkey_match",
            CheckStatus::Ok,
            "local adbkey.pub matches lab expected key",
        )
    } else {
        check(
            "adbkey_match",
            CheckStatus::Fail,
            "local adbkey.pub differs from lab — cable will show unauthorized/empty; copy trusted adbkey*",
        )
    }
}

fn check_pin(cfg: &Config) -> Check {
    if cfg.read_pin().is_some() {
        check("pin", CheckStatus::Ok, "PHONE_ADB_PIN or pin file set")
    } else {
        check(
            "pin",
            CheckStatus::Warn,
            "no pin saved — phone unlock / pm auto-unlock unavailable",
        )
    }
}

fn check_watch_agent() -> Check {
    let plist = agent::plist_path();
    if plist.is_file() {
        check(
            "watch",
            CheckStatus::Ok,
            format!("LaunchAgent plist present ({})", plist.display()),
        )
    } else {
        check(
            "watch",
            CheckStatus::Fail,
            "phone watch not installed on this Mac — run: phone watch",
        )
    }
}

fn check_adb_devices(runner: &dyn CommandRunner, serial: &str) -> Check {
    let Ok(text) = adb::adb_stdout(runner, &["devices", "-l"]) else {
        return check("adb_devices", CheckStatus::Fail, "adb devices failed");
    };
    match adb::device_state(runner, serial).as_deref() {
        Some("device") => check(
            "adb_devices",
            CheckStatus::Ok,
            format!("{serial} state=device"),
        ),
        Some("unauthorized") => check(
            "adb_devices",
            CheckStatus::Fail,
            format!(
                "{serial} unauthorized — wrong adbkey on this Mac or Allow dialog pending"
            ),
        ),
        Some(other) => check(
            "adb_devices",
            CheckStatus::Warn,
            format!("{serial} state={other}"),
        ),
        None => {
            if text.lines().any(|l| l.contains('\t')) {
                check(
                    "adb_devices",
                    CheckStatus::Warn,
                    format!(
                        "serial {serial} not listed; other devices present"
                    ),
                )
            } else {
                check(
                    "adb_devices",
                    CheckStatus::Warn,
                    "no adb devices — check USB mode / lock / tether (see samsung_usb)",
                )
            }
        }
    }
}

fn check_samsung_usb(runner: &dyn CommandRunner, expect_serial: &str) -> Check {
    let sight = probe_samsung_usb(runner);
    if !sight.present {
        return check(
            "samsung_usb",
            CheckStatus::Warn,
            "no SAMSUNG_Android in ioreg — cable unplugged or not enumerated",
        );
    }
    let serial = sight.serial.as_deref().unwrap_or("?");
    let serial_note = if serial == expect_serial {
        "serial match"
    } else {
        "serial mismatch vs config"
    };
    match sight.mode {
        UsbMode::Rndis => check(
            "samsung_usb",
            CheckStatus::Fail,
            format!(
                "present ({serial}, {serial_note}) RNDIS/tether — phone watch flips to MTP via wireless ADB when LAN/WAN is up"
            ),
        ),
        UsbMode::Mtp if !sight.adb_interface => check(
            "samsung_usb",
            CheckStatus::Fail,
            format!(
                "present ({serial}, MTP, {serial_note}) no ADB iface — watch unlocks+forces MTP over wireless if reachable"
            ),
        ),
        UsbMode::Mtp => check(
            "samsung_usb",
            CheckStatus::Ok,
            format!("present ({serial}, MTP+ADB, {serial_note})"),
        ),
        UsbMode::Other => check(
            "samsung_usb",
            CheckStatus::Warn,
            format!(
                "present ({serial}, other usb mode, adb_iface={}, {serial_note})",
                sight.adb_interface
            ),
        ),
        UsbMode::Absent => {
            check("samsung_usb", CheckStatus::Warn, "ioreg text inconsistent")
        }
    }
}

fn check_saved_hosts(runner: &dyn CommandRunner, cfg: &Config) -> Check {
    let mut parts = Vec::new();
    for (label, host) in
        [("lan", cfg.read_host()), ("wan", cfg.read_wan_host())]
    {
        let Some(host) = host else {
            parts.push(format!("{label}=unset"));
            continue;
        };
        let _ = adb::adb_connect(runner, &host);
        match adb::device_state(runner, &host).as_deref() {
            Some("device") => parts.push(format!("{label}={host} device")),
            Some(st) => parts.push(format!("{label}={host} {st}")),
            None => parts.push(format!("{label}={host} unreachable")),
        }
    }
    let detail = parts.join("; ");
    if detail.contains(" device") {
        check("wireless", CheckStatus::Ok, detail)
    } else {
        check(
            "wireless",
            CheckStatus::Warn,
            format!(
                "{detail} — ok if USB works; after reboot need watch/tcpip"
            ),
        )
    }
}

pub fn check(
    name: &str,
    status: CheckStatus,
    detail: impl Into<String>,
) -> Check {
    Check {
        name: name.into(),
        status,
        detail: detail.into(),
    }
}

pub fn probe_samsung_usb(runner: &dyn CommandRunner) -> SamsungUsb {
    let out = runner
        .output("ioreg", &["-p", "IOService", "-n", "SAMSUNG_Android", "-r"]);
    let text = out
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();
    parse_samsung_usb(&text)
}

/// Parse macOS `ioreg -n SAMSUNG_Android -r` text.
pub fn parse_samsung_usb(text: &str) -> SamsungUsb {
    if !text.contains("SAMSUNG_Android") && !text.contains("idProduct") {
        return SamsungUsb {
            present: false,
            serial: None,
            id_product: None,
            mode: UsbMode::Absent,
            adb_interface: false,
        };
    }
    let id_product = parse_id_product(text);
    let serial = parse_usb_serial(text);
    let adb_interface = text.contains("ADB Interface");
    let mode = classify_mode(id_product, text);
    SamsungUsb {
        present: true,
        serial,
        id_product,
        mode,
        adb_interface,
    }
}

fn parse_id_product(text: &str) -> Option<u32> {
    quoted_ioreg_value(text, "idProduct")?.parse().ok()
}

fn parse_usb_serial(text: &str) -> Option<String> {
    quoted_ioreg_value(text, "kUSBSerialNumberString")
        .or_else(|| quoted_ioreg_value(text, "USB Serial Number"))
}

fn quoted_ioreg_value(text: &str, key: &str) -> Option<String> {
    let needle = format!("\"{key}\" = ");
    text.lines().find_map(|line| {
        let idx = line.find(&needle)?;
        let rest = line[idx + needle.len()..].trim().trim_matches('"');
        if rest.is_empty() {
            None
        } else {
            Some(rest.to_string())
        }
    })
}

fn classify_mode(id_product: Option<u32>, text: &str) -> UsbMode {
    if text.contains("RNDIS") {
        return UsbMode::Rndis;
    }
    if text.contains("MTP@") || text.contains("MTP ") {
        return UsbMode::Mtp;
    }
    match id_product {
        // Observed S23 Ultra: MTP (+ optional ADB) vs RNDIS tether.
        Some(0x6860) => UsbMode::Mtp,
        Some(0x6863) => UsbMode::Rndis,
        Some(_) => UsbMode::Other,
        None => UsbMode::Other,
    }
}

fn adbkey_pub_path() -> PathBuf {
    home().join(".android/adbkey.pub")
}

fn home() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}

fn read_pub_token(path: &Path) -> Option<String> {
    let text = std::fs::read_to_string(path).ok()?;
    text.split_whitespace().next().map(str::to_string)
}

fn save_expected_adbkey_pub(cfg: &Config) -> Result<()> {
    let src = adbkey_pub_path();
    let bytes = std::fs::read(&src).map_err(|source| {
        crate::error::ConfigError::Write {
            path: src.clone(),
            source,
        }
    })?;
    let dest = cfg.expected_adbkey_pub_path();
    std::fs::write(&dest, bytes).map_err(|source| {
        crate::error::ConfigError::Write { path: dest, source }
    })?;
    println!(
        "Saved lab expected adbkey.pub → {}",
        cfg.expected_adbkey_pub_path().display()
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const IOREG_MTP_ADB: &str = r#"
+-o SAMSUNG_Android@01100000
  |   "idProduct" = 26720
  |   "kUSBSerialNumberString" = "RXCW102PVAP"
  +-o MTP@0
  +-o ADB Interface@3
"#;

    const IOREG_MTP_ONLY: &str = r#"
+-o SAMSUNG_Android@01100000
  |   "idProduct" = 26720
  |   "kUSBSerialNumberString" = "RXCW102PVAP"
  +-o MTP@0
  +-o CDC Abstract Control Model (ACM)@1
"#;

    const IOREG_RNDIS: &str = r#"
+-o SAMSUNG_Android@01100000
  |   "idProduct" = 26723
  |   "kUSBSerialNumberString" = "RXCW102PVAP"
  +-o RNDIS Communications Control@0
  +-o RNDIS Ethernet Data@1
"#;

    #[test]
    fn parse_mtp_with_adb() -> Result<()> {
        let s = parse_samsung_usb(IOREG_MTP_ADB);
        assert!(s.present);
        assert_eq!(s.serial.as_deref(), Some("RXCW102PVAP"));
        assert_eq!(s.mode, UsbMode::Mtp);
        assert!(s.adb_interface);
        assert_eq!(s.id_product, Some(26720));
        Ok(())
    }

    #[test]
    fn parse_mtp_without_adb() -> Result<()> {
        let s = parse_samsung_usb(IOREG_MTP_ONLY);
        assert_eq!(s.mode, UsbMode::Mtp);
        assert!(!s.adb_interface);
        Ok(())
    }

    #[test]
    fn parse_rndis_tether() -> Result<()> {
        let s = parse_samsung_usb(IOREG_RNDIS);
        assert_eq!(s.mode, UsbMode::Rndis);
        assert!(!s.adb_interface);
        Ok(())
    }

    #[test]
    fn parse_absent() -> Result<()> {
        let s = parse_samsung_usb("");
        assert!(!s.present);
        assert_eq!(s.mode, UsbMode::Absent);
        Ok(())
    }
}
