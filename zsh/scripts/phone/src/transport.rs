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
    for host in collect_candidates(runner, cfg) {
        if let Some(t) = ensure_tcp_device(runner, cfg, &host) {
            return Some(t);
        }
    }
    None
}

fn collect_candidates(runner: &dyn CommandRunner, cfg: &Config) -> Vec<String> {
    let port = DEFAULT_ADB_PORT;
    let mut candidates: Vec<String> = Vec::new();
    push_unique(&mut candidates, cfg.read_wan_host());
    if !cfg.tailscale_peer().is_empty()
        && let Some(ip) =
            adb::mac_tailscale_peer_ip(runner, cfg.tailscale_peer())
    {
        push_unique(&mut candidates, Some(format!("{ip}:{port}")));
    }
    push_unique(&mut candidates, cfg.read_host());
    for host in adb::mdns_hosts(runner) {
        push_unique(&mut candidates, Some(host));
    }
    candidates
}

fn push_unique(out: &mut Vec<String>, host: Option<String>) {
    let Some(host) = host else {
        return;
    };
    if !out.iter().any(|h| h == &host) {
        out.push(host);
    }
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
    } else if is_nondefault_adb_port(t) {
        "mDNS".into()
    } else {
        "LAN".into()
    }
}

fn is_nondefault_adb_port(host: &str) -> bool {
    host.rsplit_once(':')
        .and_then(|(_, p)| p.parse::<u16>().ok())
        .is_some_and(|p| p != DEFAULT_ADB_PORT)
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
    let serial = cfg.read_serial();
    if adb::is_device(runner, &serial) {
        return crate::persist::persist(runner, wait, cfg);
    }
    println!("USB not present — applying soft prep over current transport...");
    let t = transport(runner, cfg)?;
    harden::apply(runner, &t)?;
    crate::persist::force_wifi_always_on(runner, &t, true)?;
    println!("Soft prep done (full persist needs USB). Mirror: phone mirror");
    status(runner, cfg, false)
}

pub fn mirror(
    runner: &dyn CommandRunner,
    cfg: &Config,
    extra: &[String],
) -> Result<()> {
    adb::require_scrcpy(runner)?;
    let t = transport(runner, cfg)?;
    let via = via_label(cfg, &t);
    // Scrcpy -S streams while the panel is off, but starting from Dozing /
    // brightness 0 yields a black window. Wake first; do not screen::disable
    // (that forces sleep and blacks the framebuffer).
    wake_for_mirror(runner, &t);
    println!("Mirroring {t} via {via} (screen off on device)...");
    let serial_flag = format!("--serial={t}");
    let mut args: Vec<&str> = vec!["-S", "--no-power-on", &serial_flag];
    // Tailscale/LAN: keep stream light. Prefer USB (`phone usb` if cabled).
    if via != "USB" {
        args.extend_from_slice(&[
            "--max-size=800",
            "--video-bit-rate=2M",
            "--max-fps=20",
            "--no-audio",
            "--video-buffer=50",
        ]);
        println!(
            "WAN tune: -m800 -b2M 20fps no-audio (cable? run: phone usb && pm)"
        );
    }
    for a in extra {
        args.push(a.as_str());
    }
    adb::run_inherit(runner, "scrcpy", &args)
}

/// KEYCODE_WAKEUP — needed so scrcpy gets real frames before `-S`.
fn wake_for_mirror(runner: &dyn CommandRunner, transport: &str) {
    let _ = adb::adb(
        runner,
        &["-s", transport, "shell", "input", "keyevent", "224"],
    );
}

/// Switch adbd back to USB (cable required). Prefer this for fast `pm`.
pub fn usb(runner: &dyn CommandRunner, cfg: &Config) -> Result<()> {
    adb::require_adb(runner)?;
    let serial = cfg.read_serial();
    // May be reached over TCP right now; `adb -s … usb` still works.
    let t = if adb::is_device(runner, &serial) {
        serial.clone()
    } else {
        transport(runner, cfg)?
    };
    println!("Restarting adbd in USB mode ({t})...");
    adb::adb_status(runner, &["-s", &t, "usb"])?;
    println!("Waiting for USB device {serial}...");
    for _ in 0..20 {
        if adb::is_device(runner, &serial) {
            println!("USB ready: {serial}");
            println!("{}", adb::devices_l(runner)?);
            return Ok(());
        }
        std::thread::sleep(std::time::Duration::from_millis(250));
    }
    Err(AdbError::UsbUnauthorized { serial }.into())
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
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
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
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        let wait = RecordingWait {
            calls: RefCell::new(Vec::new()),
        };
        let cfg = temp_cfg("tcp")?;
        tcpip(&runner, &wait, &cfg, DEFAULT_ADB_PORT)?;
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
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
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
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
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
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        let cfg = temp_cfg("unr")?;
        let info = collect_status(&runner, &cfg)?;
        assert!(info.ok);
        assert!(!info.reachable);
        assert!(info.transport.is_none());
        Ok(())
    }

    #[test]
    fn transport_falls_back_to_mdns() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\n192.0.2.10:37123\tdevice\n"
                .into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
            mdns: RefCell::new(Some(
                "List of discovered mdns services\n\
adb-x\t_adb-tls-connect._tcp\t192.0.2.10:37123\n"
                    .into(),
            )),
            shells: RefCell::new(Vec::new()),
        };
        let cfg = temp_cfg("mdns")?;
        let t = transport(&runner, &cfg)?;
        assert_eq!(t, "192.0.2.10:37123");
        Ok(())
    }

    #[test]
    fn via_label_marks_mdns_port() -> Result<()> {
        let cfg = temp_cfg("via")?;
        assert_eq!(via_label(&cfg, "192.0.2.1:37123"), "mDNS");
        assert_eq!(via_label(&cfg, "192.0.2.1:5555"), "LAN");
        Ok(())
    }
}
