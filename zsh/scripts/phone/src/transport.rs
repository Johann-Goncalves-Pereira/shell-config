//! Resolve USB vs wireless transport; connect / tcpip / mirror / prep.

use serde::Serialize;

use crate::adb;
use crate::config::{Config, DEFAULT_ADB_PORT};
use crate::error::{AdbError, Result};
use crate::harden;
use crate::json_out;
use crate::runner::{CommandRunner, Wait};

/// Prefer USB cable; else Tailscale WAN; else LAN. Used by `pm` / shell.
pub fn transport(runner: &dyn CommandRunner, cfg: &Config) -> Result<String> {
    adb::require_adb(runner)?;
    let serial = cfg.read_serial();
    if adb::is_device(runner, &serial) {
        return Ok(serial);
    }
    if let Some(t) = try_connect_candidates(runner, cfg) {
        return Ok(t);
    }
    Err(AdbError::Unreachable.into())
}

fn try_connect_candidates(
    runner: &dyn CommandRunner,
    cfg: &Config,
) -> Option<String> {
    let port = DEFAULT_ADB_PORT;
    let mut candidates: Vec<String> = Vec::new();
    if let Some(w) = cfg.read_wan_host() {
        candidates.push(w);
    }
    if !cfg.tailscale_peer().is_empty()
        && let Some(ip) =
            adb::mac_tailscale_peer_ip(runner, cfg.tailscale_peer())
    {
        candidates.push(format!("{ip}:{port}"));
    }
    if let Some(h) = cfg.read_host() {
        candidates.push(h);
    }
    for host in candidates {
        if let Some(t) = ensure_tcp_device(runner, cfg, &host) {
            return Some(t);
        }
    }
    None
}

fn ensure_tcp_device(
    runner: &dyn CommandRunner,
    cfg: &Config,
    host: &str,
) -> Option<String> {
    if adb::is_device(runner, host) {
        return Some(host.to_string());
    }
    let _ = adb::adb(runner, &["connect", host]);
    if adb::is_device(runner, host) {
        if host.starts_with("100.") {
            let _ = cfg.write_wan_host(host);
        }
        return Some(host.to_string());
    }
    None
}

#[derive(Debug, Serialize)]
pub struct StatusInfo {
    pub ok: bool,
    pub reachable: bool,
    pub transport: Option<String>,
    pub via: Option<String>,
    pub serial: String,
    pub host: Option<String>,
    pub wan_host: Option<String>,
    pub devices: Vec<String>,
    pub config_dir: String,
    pub screen_disabled: bool,
}

pub fn status(
    runner: &dyn CommandRunner,
    cfg: &Config,
    json: bool,
) -> Result<()> {
    let info = collect_status(runner, cfg)?;
    if json {
        return json_out::print_ok(&info);
    }
    println!("ADB devices:\n{}", adb::devices_l(runner)?);
    println!("Saved serial: {}", info.serial);
    match &info.host {
        Some(h) => println!("Saved host:   {h}"),
        None => println!(
            "Saved host:   (none — run phone tcpip while USB-connected)"
        ),
    }
    if let Some(w) = &info.wan_host {
        println!("WAN host:     {w}");
    }
    if let Some(t) = &info.transport {
        println!("Transport:    {t} ({})", info.via.as_deref().unwrap_or("?"));
    } else {
        println!("Transport:    (unreachable)");
    }
    println!("Config dir:  {}", info.config_dir);
    Ok(())
}

pub fn collect_status(
    runner: &dyn CommandRunner,
    cfg: &Config,
) -> Result<StatusInfo> {
    let _ = adb::require_adb(runner);
    let devices = adb::authorized_transports(runner).unwrap_or_default();
    let serial = cfg.read_serial();
    let host = cfg.read_host();
    let wan_host = cfg.read_wan_host();
    let (reachable, transport, via) = match transport(runner, cfg) {
        Ok(t) => {
            let via = via_label(cfg, &t);
            (true, Some(t), Some(via))
        }
        Err(_) => (false, None, None),
    };
    Ok(StatusInfo {
        ok: true,
        reachable,
        transport,
        via,
        serial,
        host,
        wan_host,
        devices,
        config_dir: cfg.dir().display().to_string(),
        screen_disabled: cfg.screen_disabled(),
    })
}

fn via_label(cfg: &Config, t: &str) -> String {
    if t == cfg.read_serial() {
        "USB".into()
    } else if t.starts_with("100.") {
        "Tailscale".into()
    } else {
        "LAN".into()
    }
}

pub fn connect(
    runner: &dyn CommandRunner,
    cfg: &Config,
    host: Option<&str>,
) -> Result<()> {
    let host = resolve_connect_host(cfg, host)?;
    println!("Connecting to {host}...");
    adb::adb_status(runner, &["connect", &host])?;
    cfg.write_host(&host)?;
    println!("{}", adb::devices_l(runner)?);
    Ok(())
}

fn resolve_connect_host(cfg: &Config, host: Option<&str>) -> Result<String> {
    if let Some(h) = host {
        return Ok(h.to_string());
    }
    cfg.read_host().ok_or_else(|| AdbError::NoSavedHost.into())
}

pub fn tcpip(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
    port: u16,
) -> Result<()> {
    let serial = cfg.read_serial();
    if !adb::is_device(runner, &serial) {
        return Err(AdbError::UsbUnauthorized { serial }.into());
    }
    let ip = adb::wifi_ip(runner, &serial)?;
    println!("Restarting adbd in TCP mode on port {port} (IP {ip})...");
    adb::adb_status(runner, &["-s", &serial, "tcpip", &port.to_string()])?;
    wait.wait_ms(1500);
    let host = format!("{ip}:{port}");
    cfg.write_host(&host)?;
    println!("Connecting to {host}...");
    adb::adb_status(runner, &["connect", &host])?;
    println!("Wireless ADB ready: {host}");
    println!("{}", adb::devices_l(runner)?);
    Ok(())
}

pub fn lock_trust(runner: &dyn CommandRunner, cfg: &Config) -> Result<()> {
    let t = transport(runner, cfg)?;
    adb::settings_put(
        runner,
        &t,
        "global",
        "adb_allowed_connection_time",
        "0",
    )?;
    adb::settings_put(runner, &t, "global", "adb_enabled", "1")?;
    adb::settings_put(runner, &t, "global", "adb_wifi_enabled", "1")?;
    let v =
        adb::settings_get(runner, &t, "global", "adb_allowed_connection_time")?;
    println!("Trust locked: adb_allowed_connection_time={v}");
    Ok(())
}

pub fn prep(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    let t = transport(runner, cfg)?;
    println!("Applying always-on server profile...");
    harden::apply(runner, &t)?;
    adb::settings_put(runner, &t, "global", "wifi_sleep_policy", "2")?;
    adb::settings_put(runner, &t, "global", "wifi_wakeup_enabled", "1")?;
    adb::settings_put(runner, &t, "global", "stay_on_while_plugged_in", "7")?;
    adb::settings_put(runner, &t, "global", "mobile_data_always_on", "1")?;
    ensure_tcpip_if_usb(runner, wait, cfg)?;
    println!("Server prep done. Mirror with screen off: phone mirror");
    status(runner, cfg, false)
}

fn ensure_tcpip_if_usb(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    let serial = cfg.read_serial();
    if !adb::is_device(runner, &serial) {
        return Ok(());
    }
    let Ok(ip) = adb::wifi_ip(runner, &serial) else {
        return Ok(());
    };
    println!("Ensuring wireless ADB on {ip}:{DEFAULT_ADB_PORT}...");
    let port = DEFAULT_ADB_PORT.to_string();
    let _ = adb::adb_status(runner, &["-s", &serial, "tcpip", &port]);
    wait.wait_ms(1500);
    let host = format!("{ip}:{DEFAULT_ADB_PORT}");
    let _ = adb::adb(runner, &["connect", &host]);
    cfg.write_host(&host)?;
    Ok(())
}

pub fn mirror(
    runner: &dyn CommandRunner,
    cfg: &Config,
    extra: &[String],
) -> Result<()> {
    adb::require_scrcpy(runner)?;
    let t = transport(runner, cfg)?;
    let via = via_label(cfg, &t);
    println!("Mirroring {t} via {via} (screen off on device)...");
    let serial_flag = format!("--serial={t}");
    let mut args: Vec<&str> = vec!["-S", "--no-power-on", &serial_flag];
    for a in extra {
        args.push(a.as_str());
    }
    if cfg.screen_disabled() {
        let _ = crate::screen::disable(runner, cfg);
    }
    adb::run_inherit(runner, "scrcpy", &args)
}

pub fn shell_cmd(
    runner: &dyn CommandRunner,
    cfg: &Config,
    args: &[String],
) -> Result<()> {
    let t = transport(runner, cfg)?;
    if args.is_empty() {
        return adb::run_inherit(runner, "adb", &["-s", &t, "shell"]);
    }
    let mut v: Vec<&str> = vec!["-s", &t, "shell"];
    for a in args {
        v.push(a);
    }
    adb::run_inherit(runner, "adb", &v)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runner::{RecordingWait, ScriptedRunner};
    use std::cell::RefCell;
    use std::collections::HashMap;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn runner_usb() -> ScriptedRunner {
        ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTESTSERIAL\tdevice\n".into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
        }
    }

    fn temp_cfg(tag: &str) -> Result<Config> {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| std::io::Error::other(e.to_string()))?
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("phone-{tag}-{stamp}"));
        Config::with_dir("TESTSERIAL".into(), dir)
    }

    #[test]
    fn transport_prefers_usb_serial() -> Result<()> {
        let runner = runner_usb();
        let cfg = temp_cfg("tr")?;
        let t = transport(&runner, &cfg)?;
        assert_eq!(t, "TESTSERIAL");
        Ok(())
    }

    #[test]
    fn tcpip_saves_host_and_waits() -> Result<()> {
        let mut replies = HashMap::new();
        replies.insert(
            "ip -f inet addr show wlan0".into(),
            "inet 192.168.0.50/24".into(),
        );
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTESTSERIAL\tdevice\n192.168.0.50:5555\tdevice\n"
                .into(),
            shell_replies: RefCell::new(replies),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
        };
        let wait = RecordingWait {
            calls: RefCell::new(Vec::new()),
        };
        let cfg = temp_cfg("tcp")?;
        tcpip_with_extended(&runner, &wait, &cfg)?;
        assert_eq!(cfg.read_host().as_deref(), Some("192.168.0.50:5555"));
        assert_eq!(wait.calls.borrow().as_slice(), &[1500]);
        Ok(())
    }

    #[test]
    fn transport_falls_back_to_wan_host() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\n100.64.0.2:5555\tdevice\n"
                .into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
        };
        let cfg = temp_cfg("wan")?;
        cfg.write_wan_host("100.64.0.2:5555")?;
        let t = transport(&runner, &cfg)?;
        assert_eq!(t, "100.64.0.2:5555");
        Ok(())
    }

    #[test]
    fn transport_prefers_usb_over_wan() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTESTSERIAL\tdevice\n100.64.0.2:5555\tdevice\n"
                .into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
        };
        let cfg = temp_cfg("usbwan")?;
        cfg.write_wan_host("100.64.0.2:5555")?;
        let t = transport(&runner, &cfg)?;
        assert_eq!(t, "TESTSERIAL");
        Ok(())
    }

    #[test]
    fn collect_status_reachable_json_shape() -> Result<()> {
        let runner = runner_usb();
        let cfg = temp_cfg("st")?;
        let info = collect_status(&runner, &cfg)?;
        assert!(info.ok);
        assert!(info.reachable);
        assert_eq!(info.transport.as_deref(), Some("TESTSERIAL"));
        assert_eq!(info.via.as_deref(), Some("USB"));
        Ok(())
    }

    #[test]
    fn collect_status_unreachable() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\n".into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
        };
        let cfg = temp_cfg("unr")?;
        let info = collect_status(&runner, &cfg)?;
        assert!(info.ok);
        assert!(!info.reachable);
        assert!(info.transport.is_none());
        Ok(())
    }

    fn tcpip_with_extended(
        runner: &ScriptedRunner,
        wait: &RecordingWait,
        cfg: &Config,
    ) -> Result<()> {
        let serial = cfg.read_serial();
        let ip = adb::wifi_ip(runner, &serial)?;
        wait.wait_ms(1500);
        let host = format!("{ip}:5555");
        cfg.write_host(&host)?;
        Ok(())
    }
}
