//! Curated developer-option profile for a headless lab phone.

use crate::adb;
use crate::error::{Error, HardenError, Result};
use crate::runner::CommandRunner;

/// `(namespace, key, value)` — value `"null"` deletes the key.
pub const DESIRED: &[(&str, &str, &str)] = &[
    ("global", "adb_enabled", "1"),
    ("global", "adb_wifi_enabled", "1"),
    ("global", "adb_allowed_connection_time", "0"),
    ("global", "development_settings_enabled", "1"),
    ("global", "stay_on_while_plugged_in", "7"),
    ("global", "mobile_data_always_on", "1"),
    ("global", "always_finish_activities", "0"),
    ("global", "wait_for_debugger", "0"),
    ("global", "window_animation_scale", "0.5"),
    ("global", "transition_animation_scale", "0.5"),
    ("global", "animator_duration_scale", "0.5"),
    ("global", "force_resizable_activities", "1"),
    ("global", "enable_freeform_support", "1"),
    ("global", "wifi_scan_throttle_enabled", "0"),
    ("global", "verifier_verify_adb_installs", "0"),
    ("global", "art_verifier_verify_debuggable", "0"),
    ("global", "wifi_verbose_logging_enabled", "0"),
    ("global", "bluetooth_hci_log", "0"),
    ("global", "overlay_display_devices", "null"),
    ("global", "debug_view_attributes", "0"),
    ("system", "show_touches", "0"),
    ("system", "pointer_location", "0"),
    ("secure", "mock_location", "0"),
    ("secure", "anr_show_background", "0"),
    ("secure", "usb_audio_automatic_routing_disabled", "0"),
];

pub fn show(runner: &dyn CommandRunner, transport: &str) -> Result<()> {
    println!("Developer options ({transport}):");
    for &(ns, key, _) in DESIRED {
        print_setting(runner, transport, ns, key);
    }
    Ok(())
}

pub fn apply(runner: &dyn CommandRunner, transport: &str) -> Result<()> {
    println!("Hardening developer options on {transport}...");
    for &(ns, key, val) in DESIRED {
        put_one(runner, transport, ns, key, val)?;
    }
    let _ = adb::adb(
        runner,
        &[
            "-s",
            transport,
            "shell",
            "settings",
            "put",
            "global",
            "app_process_limit",
            "-1",
        ],
    );
    best_effort_props(runner, transport);
    best_effort_phantom(runner, transport);
    println!("Hardened. Re-check with: phone harden --show");
    show(runner, transport)
}

fn print_setting(
    runner: &dyn CommandRunner,
    transport: &str,
    ns: &str,
    key: &str,
) {
    let val = adb::settings_get(runner, transport, ns, key)
        .unwrap_or_else(|_| "<error>".into());
    let display = if val.is_empty() || val == "null" {
        "<unset>"
    } else {
        val.as_str()
    };
    println!("  {ns:<8} {key:<40} = {display}");
}

fn put_one(
    runner: &dyn CommandRunner,
    transport: &str,
    ns: &str,
    key: &str,
    val: &str,
) -> Result<()> {
    match adb::settings_put(runner, transport, ns, key, val) {
        Ok(()) => Ok(()),
        Err(Error::Adb(source)) => Err(HardenError::SettingsPut {
            ns: ns.to_string(),
            key: key.to_string(),
            source,
        }
        .into()),
        Err(Error::Config(e)) => Err(Error::Config(e)),
        Err(Error::Harden(e)) => Err(Error::Harden(e)),
        Err(Error::Wan(e)) => Err(Error::Wan(e)),
        Err(Error::Io(e)) => Err(Error::Io(e)),
    }
}

fn best_effort_props(runner: &dyn CommandRunner, transport: &str) {
    for prop in [
        "debug.layout false",
        "debug.hwui.overdraw false",
        "debug.hwui.profile false",
        "debug.egl.force_msaa false",
        "debug.force_rtl false",
    ] {
        let _ = adb::shell(runner, transport, &format!("setprop {prop}"));
    }
}

fn best_effort_phantom(runner: &dyn CommandRunner, transport: &str) {
    let _ = adb::shell(
        runner,
        transport,
        "/system/bin/device_config put activity_manager max_phantom_processes 2147483647",
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn desired_table_has_timeout_zero() -> Result<()> {
        let hit = DESIRED.iter().any(|&(ns, key, val)| {
            ns == "global" && key == "adb_allowed_connection_time" && val == "0"
        });
        assert!(hit);
        let stay = DESIRED.iter().any(|&(ns, key, val)| {
            ns == "global" && key == "stay_on_while_plugged_in" && val == "7"
        });
        assert!(stay);
        Ok(())
    }
}
