//! Persist wireless ADB as far as stock Android allows.
//!
//! Samsung Intelligent / Auto Wi‑Fi will turn the radio off when it thinks
//! you are "away" — kill those edges hard so the lab phone stays reachable.

use crate::adb;
use crate::config::{Config, DEFAULT_ADB_PORT};
use crate::error::{AdbError, Result};
use crate::harden;
use crate::runner::{CommandRunner, Wait};
use crate::transport;

const TAILSCALE_PKG: &str = "com.tailscale.ipn";

/// Samsung / AOSP keys that must stay forced for always-reachable Wi‑Fi.
/// `(key, value)` under `settings global`.
pub const WIFI_ALWAYS_ON: &[(&str, &str)] = &[
    ("wifi_on", "1"),
    ("wifi_sleep_policy", "2"), // NEVER sleep
    ("wifi_wakeup_enabled", "1"),
    ("wifi_scan_always_available", "1"),
    ("wifi_watchdog_poor_network_test_enabled", "0"),
    ("network_avoid_bad_wifi", "0"),
    // Samsung Intelligent / Auto Wi‑Fi — these turn Wi‑Fi off "when away".
    ("auto_wifi", "0"),
    ("sem_auto_wifi_control_enabled", "0"),
    ("sem_wifi_switch_to_better_wifi_enabled", "0"),
    ("sem_wifi_switch_to_better_wifi_on_screen_enabled", "0"),
    // Battery / doze edges that cut radios or background VPN.
    ("adaptive_battery_management_enabled", "0"),
    ("adaptive_power_saving_setting", "0"),
    ("low_power", "0"),
    ("low_power_sticky", "0"),
    ("low_power_back_data_off", "0"),
    ("airplane_mode_on", "0"),
    ("stay_on_while_plugged_in", "7"),
    ("mobile_data_always_on", "1"),
    ("adb_wifi_enabled", "1"),
    ("adb_allowed_connection_time", "0"),
];

/// Packages that try to "manage" Wi‑Fi and can drop connectivity.
const WIFI_MEDDLERS: &[&str] = &[
    "com.samsung.android.wifi.ai",
    "com.samsung.android.net.wifi.wifiguider",
];

/// Arm phone for post-reboot reachability (USB preferred).
pub fn persist(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    let serial = cfg.read_serial();
    if !adb::is_device(runner, &serial) {
        return Err(AdbError::UsbUnauthorized { serial }.into());
    }
    println!("Persisting always-on ADB profile on {serial}...");
    harden::apply(runner, &serial)?;
    force_wifi_always_on(runner, &serial, true)?;
    force_usb_lab_mode(runner, &serial, true)?;
    try_persist_tcp_port(runner, &serial);
    keep_tailscale_alive(runner, &serial);
    transport::tcpip(runner, wait, cfg, DEFAULT_ADB_PORT)?;
    save_tailscale_wan(runner, cfg, &serial)?;
    open_tailscale(runner, &serial);
    println!(
        "Persist done. Classic :{DEFAULT_ADB_PORT} may still reset on reboot \
         unless persist.adb.tcp.port stuck — use `phone watch` on this Mac."
    );
    transport::status(runner, cfg, false)
}

/// Force lab USB gadget mode: This device + MTP (file transfer) + ADB.
///
/// Samsung “Connected device” is OTG host — do not force that. Safe to call
/// repeatedly from the Mac watcher while USB is present.
pub fn force_usb_lab_mode(
    runner: &dyn CommandRunner,
    transport: &str,
    verbose: bool,
) -> Result<()> {
    if verbose {
        println!("Forcing USB lab mode on {transport} (This device + MTP)...");
    }
    let _ = adb::shell(runner, transport, "svc usb setFunctions mtp");
    let _ =
        adb::shell(runner, transport, "svc usb setScreenUnlockedFunctions mtp");
    try_persist_usb_config(runner, transport, verbose);
    verify_usb_lab_mode(runner, transport, verbose);
    Ok(())
}

fn try_persist_usb_config(
    runner: &dyn CommandRunner,
    transport: &str,
    verbose: bool,
) {
    let _ =
        adb::shell(runner, transport, "setprop persist.sys.usb.config mtp,adb");
    let got = adb::shell(runner, transport, "getprop persist.sys.usb.config")
        .unwrap_or_default();
    let got = got.trim();
    if got.contains("mtp") {
        log_nonempty(verbose, "persist.sys.usb.config", got);
    } else if verbose {
        println!(
            "persist.sys.usb.config: missed (Samsung often blocks; \
             getprop={got:?} — screen-unlocked MTP still applied)"
        );
    }
}

fn verify_usb_lab_mode(
    runner: &dyn CommandRunner,
    transport: &str,
    verbose: bool,
) {
    let funcs = adb::shell(runner, transport, "svc usb getFunctions")
        .unwrap_or_default();
    let funcs = funcs.trim();
    if funcs.contains("mtp") {
        if verbose {
            println!("USB lab mode: ok (functions={funcs})");
        }
    } else if verbose {
        println!("USB lab mode: warn — getFunctions={funcs:?} (expected mtp)");
    }
}

/// Force Wi‑Fi never-off profile. Safe to call repeatedly from the Mac watcher.
pub fn force_wifi_always_on(
    runner: &dyn CommandRunner,
    transport: &str,
    verbose: bool,
) -> Result<()> {
    if verbose {
        println!("Forcing Wi‑Fi always-on on {transport}...");
    }
    apply_wifi_settings(runner, transport)?;
    enable_wifi_radio(runner, transport);
    disable_wifi_meddlers(runner, transport, verbose);
    if verbose {
        verify_wifi_always_on(runner, transport);
    }
    Ok(())
}

fn apply_wifi_settings(
    runner: &dyn CommandRunner,
    transport: &str,
) -> Result<()> {
    for &(key, val) in WIFI_ALWAYS_ON {
        // Best-effort: Samsung may reject some keys; do not abort the rest.
        if let Err(e) = adb::settings_put(runner, transport, "global", key, val)
        {
            eprintln!("warn: settings put global {key}={val}: {e}");
        }
    }
    Ok(())
}

fn enable_wifi_radio(runner: &dyn CommandRunner, transport: &str) {
    let _ = adb::shell(runner, transport, "cmd wifi set-wifi-enabled enabled");
    let _ = adb::shell(
        runner,
        transport,
        "cmd wifi set-scan-always-available enabled",
    );
    let _ = adb::shell(runner, transport, "svc wifi enable");
    let _ =
        adb::shell(runner, transport, "cmd connectivity airplane-mode disable");
}

fn disable_wifi_meddlers(
    runner: &dyn CommandRunner,
    transport: &str,
    verbose: bool,
) {
    for pkg in WIFI_MEDDLERS {
        let cmd = format!("pm disable-user --user 0 {pkg}");
        match adb::shell(runner, transport, &cmd) {
            Ok(out) => log_nonempty(
                verbose,
                &format!("Wi‑Fi meddler {pkg}"),
                out.trim(),
            ),
            Err(_) => log_disable_fail(verbose, pkg),
        }
    }
}

fn log_disable_fail(verbose: bool, pkg: &str) {
    if verbose {
        eprintln!("warn: disable {pkg} failed");
    }
}

fn log_nonempty(verbose: bool, label: &str, text: &str) {
    if verbose && !text.is_empty() {
        println!("{label}: {text}");
    }
}

fn verify_wifi_always_on(runner: &dyn CommandRunner, transport: &str) {
    let mut misses = Vec::new();
    for &(key, want) in WIFI_ALWAYS_ON {
        // Samsung blocks adb_wifi_enabled; classic tcpip :5555 still works.
        if key == "adb_wifi_enabled" {
            continue;
        }
        let got = adb::settings_get(runner, transport, "global", key)
            .unwrap_or_default();
        let got = got.trim();
        if got != want {
            misses.push(format!("{key} want={want} got={got:?}"));
        }
    }
    if misses.is_empty() {
        println!("Wi‑Fi always-on: ok (radio never-sleep + Auto Wi‑Fi killed)");
    } else {
        println!(
            "Wi‑Fi always-on: {} key(s) did not stick — {}",
            misses.len(),
            misses.join("; ")
        );
    }
}

fn try_persist_tcp_port(runner: &dyn CommandRunner, transport: &str) {
    let port = DEFAULT_ADB_PORT.to_string();
    let _ = adb::shell(
        runner,
        transport,
        &format!("setprop persist.adb.tcp.port {port}"),
    );
    let _ = adb::shell(
        runner,
        transport,
        &format!("setprop service.adb.tcp.port {port}"),
    );
    let persist = adb::shell(runner, transport, "getprop persist.adb.tcp.port")
        .unwrap_or_default();
    let service = adb::shell(runner, transport, "getprop service.adb.tcp.port")
        .unwrap_or_default();
    // Only persist.* survives reboot; service.* is session-only.
    if persist.trim() == port {
        println!("persist tcp port: ok (persist.adb.tcp.port={port})");
    } else {
        println!(
            "persist tcp port: missed (Samsung/stock often blocks setprop; \
             getprop persist={persist:?} service={service:?} — \
             :{port} needs USB re-arm or mDNS after reboot)"
        );
    }
}

fn keep_tailscale_alive(runner: &dyn CommandRunner, transport: &str) {
    let cmds = [
        format!("dumpsys deviceidle whitelist +{TAILSCALE_PKG}"),
        format!("cmd appops set {TAILSCALE_PKG} RUN_IN_BACKGROUND allow"),
        format!("cmd appops set {TAILSCALE_PKG} RUN_ANY_IN_BACKGROUND allow"),
        format!("am set-inactive {TAILSCALE_PKG} false"),
    ];
    for cmd in &cmds {
        match adb::shell(runner, transport, cmd) {
            Ok(out) => log_nonempty(true, "Tailscale keep-alive", out.trim()),
            Err(e) => eprintln!("warn: Tailscale keep-alive `{cmd}`: {e}"),
        }
    }
    println!("Tailscale battery whitelist + background ops: requested");
}

fn save_tailscale_wan(
    runner: &dyn CommandRunner,
    cfg: &Config,
    transport: &str,
) -> Result<()> {
    if let Some(ip) = adb::tailscale_ip(runner, transport) {
        let host = format!("{ip}:{DEFAULT_ADB_PORT}");
        cfg.write_wan_host(&host)?;
        println!("Saved WAN host: {host}");
        let _ = adb::adb(runner, &["connect", &host]);
    } else {
        println!(
            "No Tailscale IP on phone yet — open Tailscale (connect on boot), then: phone wan"
        );
    }
    Ok(())
}

fn open_tailscale(runner: &dyn CommandRunner, transport: &str) {
    println!(
        "Opening Tailscale — enable Connect on boot / VPN always-on if prompted."
    );
    let _ = adb::adb(
        runner,
        &[
            "-s",
            transport,
            "shell",
            "monkey",
            "-p",
            TAILSCALE_PKG,
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        ],
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::runner::ScriptedRunner;
    use std::cell::RefCell;
    use std::collections::HashMap;

    #[test]
    fn force_usb_lab_mode_sets_mtp_functions() -> Result<()> {
        let mut replies = HashMap::new();
        replies.insert("svc usb getFunctions".into(), "mtp,adb".into());
        replies
            .insert("getprop persist.sys.usb.config".into(), "mtp,adb".into());
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTEST\tdevice\n".into(),
            shell_replies: RefCell::new(replies),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        force_usb_lab_mode(&runner, "TEST", false)?;
        let shells = runner.shells.borrow();
        assert!(shells.iter().any(|c| c == "svc usb setFunctions mtp"));
        assert!(
            shells
                .iter()
                .any(|c| { c == "svc usb setScreenUnlockedFunctions mtp" })
        );
        Ok(())
    }

    #[test]
    fn try_persist_reports_miss_when_getprop_empty() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTEST\tdevice\n".into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        try_persist_tcp_port(&runner, "TEST");
        Ok(())
    }

    #[test]
    fn force_wifi_writes_never_sleep_and_kills_auto_wifi() -> Result<()> {
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTEST\tdevice\n".into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(None),
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        force_wifi_always_on(&runner, "TEST", false)?;
        let puts = runner.puts.borrow();
        assert!(puts.iter().any(|p| {
            p.0 == "global" && p.1 == "wifi_sleep_policy" && p.2 == "2"
        }));
        assert!(
            puts.iter().any(|p| {
                p.0 == "global" && p.1 == "auto_wifi" && p.2 == "0"
            })
        );
        assert!(puts.iter().any(|p| {
            p.0 == "global"
                && p.1 == "sem_auto_wifi_control_enabled"
                && p.2 == "0"
        }));
        assert!(
            puts.iter()
                .any(|p| { p.0 == "global" && p.1 == "wifi_on" && p.2 == "1" })
        );
        Ok(())
    }

    #[test]
    fn wifi_always_on_table_covers_samsung_auto_wifi() -> Result<()> {
        assert!(
            WIFI_ALWAYS_ON
                .iter()
                .any(|&(k, v)| k == "auto_wifi" && v == "0")
        );
        assert!(
            WIFI_ALWAYS_ON
                .iter()
                .any(|&(k, v)| { k == "wifi_sleep_policy" && v == "2" })
        );
        Ok(())
    }
}
