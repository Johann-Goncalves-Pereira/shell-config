//! Soft-disable the physical panel (broken screen). Easy to re-enable.

use serde::Serialize;

use crate::adb;
use crate::config::Config;
use crate::error::Result;
use crate::json_out;
use crate::runner::{CommandRunner, Wait};
use crate::transport;

/// Android KEYCODE_SLEEP — turn panel off without full power cycle.
const KEYCODE_SLEEP: &str = "223";
/// Android KEYCODE_WAKEUP.
const KEYCODE_WAKEUP: &str = "224";
const GUARD_POLL_MS: u64 = 750;

#[derive(Debug, Serialize)]
pub struct ScreenStatus {
    pub ok: bool,
    pub disabled: bool,
    pub brightness: String,
    pub wakefulness: String,
    pub stay_on_while_plugged: String,
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
    println!(
        "screen disabled flag: {}",
        if info.disabled { "on" } else { "off" }
    );
    println!("display brightness:   {}", info.brightness);
    println!("wakefulness:          {}", info.wakefulness);
    println!("stay_on_while_plugged: {}", info.stay_on_while_plugged);
    if info.disabled {
        println!(
            "Tip: keep `phone screen guard` running so power-button wakes get put back to sleep."
        );
    }
    Ok(())
}

fn collect_status(
    runner: &dyn CommandRunner,
    cfg: &Config,
) -> Result<ScreenStatus> {
    let t = transport::transport(runner, cfg)?;
    let bright = adb::shell(runner, &t, "cmd display get-brightness")
        .unwrap_or_else(|_| "?".into());
    let wake = wakefulness(runner, &t).unwrap_or_else(|| "unknown".into());
    let stay =
        adb::settings_get(runner, &t, "global", "stay_on_while_plugged_in")
            .unwrap_or_else(|_| "?".into());
    Ok(ScreenStatus {
        ok: true,
        disabled: cfg.screen_disabled(),
        brightness: bright,
        wakefulness: wake,
        stay_on_while_plugged: stay,
    })
}

/// Dim + sleep panel; remember prior brightness / stay-on for restore.
pub fn disable(runner: &dyn CommandRunner, cfg: &Config) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    save_restore_state(runner, cfg, &t)?;
    apply_off(runner, &t)?;
    cfg.write_screen_disabled(true)?;
    // stay_on forces the panel on while charging — fights a dead-screen lab.
    adb::settings_put(runner, &t, "global", "stay_on_while_plugged_in", "0")?;
    println!("Physical screen disabled (brightness 0 + sleep).");
    println!("Re-enable:  phone screen on");
    println!("Power button may wake briefly — run: phone screen guard");
    Ok(())
}

/// Restore brightness / stay-on and wake the panel path for a future working display.
pub fn enable(runner: &dyn CommandRunner, cfg: &Config) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    let bright = cfg.read_screen_brightness().unwrap_or_else(|| "0.4".into());
    let stay = cfg.read_screen_stay_on().unwrap_or_else(|| "7".into());
    let _ =
        adb::shell(runner, &t, &format!("cmd display set-brightness {bright}"));
    adb::settings_put(runner, &t, "system", "screen_brightness_mode", "0")?;
    // Map float 0..1 to 0..255 best-effort for system setting.
    if let Ok(v) = bright.parse::<f32>() {
        let level = ((v.clamp(0.0, 1.0)) * 255.0).round() as u32;
        let _ = adb::settings_put(
            runner,
            &t,
            "system",
            "screen_brightness",
            &level.to_string(),
        );
    }
    adb::settings_put(runner, &t, "global", "stay_on_while_plugged_in", &stay)?;
    let _ = adb::adb(
        runner,
        &["-s", &t, "shell", "input", "keyevent", KEYCODE_WAKEUP],
    );
    cfg.write_screen_disabled(false)?;
    println!("Physical screen enabled (brightness {bright}, stay_on {stay}).");
    Ok(())
}

/// Loop: if the panel wakes (e.g. power button), force sleep + brightness 0 again.
pub fn guard(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    cfg: &Config,
) -> Result<()> {
    if !cfg.screen_disabled() {
        println!("Screen not marked disabled — running disable first...");
        disable(runner, cfg)?;
    }
    let t = transport::transport(runner, cfg)?;
    println!(
        "Screen guard on {t} (Ctrl+C to stop). Power wakes will be put back to sleep."
    );
    loop {
        if !cfg.screen_disabled() {
            println!("screen disabled flag cleared — guard exiting.");
            return Ok(());
        }
        if is_awake(runner, &t) {
            let _ = apply_off(runner, &t);
        }
        wait.wait_ms(GUARD_POLL_MS);
    }
}

fn save_restore_state(
    runner: &dyn CommandRunner,
    cfg: &Config,
    transport: &str,
) -> Result<()> {
    if let Ok(b) = adb::shell(runner, transport, "cmd display get-brightness") {
        let b = b.trim();
        if !b.is_empty() && b != "0" && b != "0.0" {
            cfg.write_screen_brightness(b)?;
        } else if cfg.read_screen_brightness().is_none() {
            cfg.write_screen_brightness("0.4")?;
        }
    }
    if let Ok(s) = adb::settings_get(
        runner,
        transport,
        "global",
        "stay_on_while_plugged_in",
    ) {
        let s = s.trim();
        if !s.is_empty() && s != "null" {
            cfg.write_screen_stay_on(s)?;
        }
    }
    Ok(())
}

fn apply_off(runner: &dyn CommandRunner, transport: &str) -> Result<()> {
    let _ = adb::shell(runner, transport, "cmd display set-brightness 0");
    let _ = adb::settings_put(
        runner,
        transport,
        "system",
        "screen_brightness_mode",
        "0",
    );
    let _ = adb::settings_put(
        runner,
        transport,
        "system",
        "screen_brightness",
        "0",
    );
    let _ = adb::adb(
        runner,
        &["-s", transport, "shell", "input", "keyevent", KEYCODE_SLEEP],
    );
    Ok(())
}

fn wakefulness(runner: &dyn CommandRunner, transport: &str) -> Option<String> {
    let raw = adb::shell(runner, transport, "dumpsys power").ok()?;
    parse_wakefulness(&raw)
}

fn is_awake(runner: &dyn CommandRunner, transport: &str) -> bool {
    wakefulness(runner, transport)
        .is_some_and(|w| w.eq_ignore_ascii_case("Awake"))
}

fn parse_wakefulness(raw: &str) -> Option<String> {
    for line in raw.lines() {
        let line = line.trim();
        let Some(rest) = line.strip_prefix("mWakefulness=") else {
            continue;
        };
        // Prefer the string form (Awake/Dozing/Asleep), skip numeric mWakefulness=1
        let val = rest.split_whitespace().next().unwrap_or("").trim();
        if val.chars().next().is_some_and(|c| c.is_ascii_alphabetic()) {
            return Some(val.to_string());
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_wakefulness_prefers_word_form() -> Result<()> {
        let raw = "  mWakefulness=Awake\nmWakefulness=1\n";
        assert_eq!(parse_wakefulness(raw).as_deref(), Some("Awake"));
        let doze = "mWakefulness=Dozing\nmWakefulness=3\n";
        assert_eq!(parse_wakefulness(doze).as_deref(), Some("Dozing"));
        Ok(())
    }
}
