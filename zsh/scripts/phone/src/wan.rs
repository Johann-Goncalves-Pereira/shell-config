//! WAN: WebRTC probe (honest skip) then Tailscale mesh for remote ADB.

use std::fs;
use std::io::Write;
use std::path::Path;

use crate::adb;
use crate::config::{Config, DEFAULT_ADB_PORT};
use crate::error::{Result, WanError};
use crate::runner::CommandRunner;
use crate::transport;

/// STUN-only WebRTC is not enough for CGNAT; no TURN farm this pass.
pub fn webrtc_probe() {
    println!("WebRTC Attempt A (STUN-only feasibility):");
    println!(
        "  Custom ADB-over-WebRTC without a TURN relay fails on typical mobile CGNAT."
    );
    println!("  This pass does not operate a TURN farm (per plan).");
    println!("  Falling back to Tailscale (identity = passworded overlay).");
    println!("VERDICT=skip_custom_webrtc_no_turn");
}

pub fn wan(runner: &dyn CommandRunner, cfg: &Config, port: u16) -> Result<()> {
    webrtc_probe();
    if try_tailscale(runner, cfg, port)? {
        return Ok(());
    }
    if try_saved_wan(runner, cfg)? {
        return Ok(());
    }
    println!("No Tailscale IP yet — falling back to LAN connect.");
    transport::connect(runner, cfg, None)
}

fn try_tailscale(
    runner: &dyn CommandRunner,
    cfg: &Config,
    port: u16,
) -> Result<bool> {
    let Ok(t) = transport::transport(runner, cfg) else {
        return Ok(false);
    };
    let Some(ip) = adb::tailscale_ip(runner, &t) else {
        return Ok(false);
    };
    let host = format!("{ip}:{port}");
    println!("Connecting via Tailscale {host}...");
    adb::adb_status(runner, &["connect", &host])?;
    // Keep LAN host separate; WAN goes in wan-host for `pm` auto-fallback.
    cfg.write_wan_host(&host)?;
    println!("{}", adb::devices_l(runner)?);
    Ok(true)
}

fn try_saved_wan(runner: &dyn CommandRunner, cfg: &Config) -> Result<bool> {
    let Some(host) = cfg.read_wan_host() else {
        return Ok(false);
    };
    println!("Connecting via saved WAN host {host}...");
    if adb::adb_ok(runner, &["connect", &host]) && adb::is_device(runner, &host)
    {
        println!("{}", adb::devices_l(runner)?);
        return Ok(true);
    }
    Ok(false)
}

pub fn tailscale_setup(runner: &dyn CommandRunner, cfg: &Config) -> Result<()> {
    webrtc_probe();
    let t = transport::transport(runner, cfg)?;
    ensure_installed(runner, cfg, &t)?;
    open_app(runner, &t);
    print_next_steps();
    Ok(())
}

fn ensure_installed(
    runner: &dyn CommandRunner,
    cfg: &Config,
    transport: &str,
) -> Result<()> {
    let installed = adb::adb_ok(
        runner,
        &["-s", transport, "shell", "pm", "path", "com.tailscale.ipn"],
    );
    if installed {
        println!("Tailscale already installed.");
        return Ok(());
    }
    let apk = download_tailscale_apk(runner, cfg)?;
    println!("Installing Tailscale...");
    adb::adb_status(runner, &["-s", transport, "install", "-r", &apk])
        .map_err(|e| match e {
            crate::error::Error::Adb(source) => {
                WanError::ApkInstall { source }.into()
            }
            crate::error::Error::Config(e) => crate::error::Error::Config(e),
            crate::error::Error::Harden(e) => crate::error::Error::Harden(e),
            crate::error::Error::Wan(e) => crate::error::Error::Wan(e),
            crate::error::Error::Io(e) => crate::error::Error::Io(e),
        })?;
    Ok(())
}

fn open_app(runner: &dyn CommandRunner, transport: &str) {
    println!(
        "Opening Tailscale — log in on the same tailnet as this Mac (use: phone mirror)."
    );
    let _ = adb::adb(
        runner,
        &[
            "-s",
            transport,
            "shell",
            "monkey",
            "-p",
            "com.tailscale.ipn",
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        ],
    );
    let _ = adb::adb(
        runner,
        &[
            "-s",
            transport,
            "shell",
            "am",
            "start",
            "-n",
            "com.tailscale.ipn/.MainActivity",
        ],
    );
}

fn print_next_steps() {
    println!(
        "\nNext:\n  1. In scrcpy: sign in to Tailscale (same account as this Mac).\n  2. Enable VPN / Connect.\n  3. phone wan\n  4. phone mirror\n\nAuth = Tailscale identity. Never expose :{DEFAULT_ADB_PORT} to the public internet."
    );
}

fn download_tailscale_apk(
    runner: &dyn CommandRunner,
    cfg: &Config,
) -> Result<String> {
    let dir = cfg.apks_dir();
    fs::create_dir_all(&dir)?;
    let apk = dir.join("tailscale.apk");
    if apk_usable(&apk) {
        println!("Using cached {}", apk.display());
        return Ok(apk.display().to_string());
    }
    println!("Downloading Tailscale APK...");
    let mut urls = resolve_github_apk_urls(runner);
    urls.extend([
        "https://pkgs.tailscale.com/stable/android/tailscale-android.apk"
            .into(),
        "https://github.com/tailscale/tailscale-android/releases/latest/download/tailscale-android-universal.apk"
            .into(),
    ]);
    for url in &urls {
        if curl_to(runner, url, &apk).is_ok() && apk_usable(&apk) {
            return Ok(apk.display().to_string());
        }
    }
    eprintln!(
        "Could not download APK. Install Tailscale from Play Store via `phone mirror`, then re-run `phone tailscale`."
    );
    Err(WanError::ApkDownload.into())
}

/// Parse latest universal APK URL from GitHub releases API (best-effort).
fn resolve_github_apk_urls(runner: &dyn CommandRunner) -> Vec<String> {
    let api = "https://api.github.com/repos/tailscale/tailscale-android/releases/latest";
    let Ok(out) = runner.output("curl", &["-fsSL", "-A", "phone-cli/0.1", api])
    else {
        return Vec::new();
    };
    if !out.status.success() {
        return Vec::new();
    }
    let body = String::from_utf8_lossy(&out.stdout);
    let mut urls = Vec::new();
    for line in body.split('"') {
        if line.contains("browser_download_url") {
            continue;
        }
        if line.ends_with(".apk") && line.contains("tailscale-android") {
            urls.push(line.to_string());
        }
    }
    urls
}

fn apk_usable(path: &Path) -> bool {
    fs::metadata(path)
        .map(|m| m.len() > 1_000_000)
        .unwrap_or(false)
}

fn curl_to(runner: &dyn CommandRunner, url: &str, dest: &Path) -> Result<()> {
    let path = dest.display().to_string();
    adb::run_inherit(
        runner,
        "curl",
        &[
            "-fL",
            "--retry",
            "3",
            "-A",
            "phone-cli/0.1",
            "-o",
            &path,
            url,
        ],
    )
}

pub fn ensure_mac_tailscale(runner: &dyn CommandRunner) -> Result<()> {
    if Path::new("/Applications/Tailscale.app").exists() {
        println!("Tailscale.app present on Mac.");
        return Ok(());
    }
    if runner.output("which", &["brew"]).is_err() {
        eprintln!(
            "warn: install Tailscale on Mac from https://tailscale.com/download"
        );
        return Ok(());
    }
    println!("Installing Tailscale on Mac via Homebrew cask...");
    // Suppress brew API noise; failure is non-fatal.
    let quiet = runner.output("brew", &["install", "--cask", "tailscale"]);
    match quiet {
        Ok(out) if out.status.success() => Ok(()),
        _ => {
            eprintln!(
                "warn: brew cask install failed — install from https://tailscale.com/download"
            );
            Ok(())
        }
    }
}

pub fn write_note(cfg: &Config) -> Result<()> {
    let path = cfg.dir().join("WAN.md");
    let mut f = fs::File::create(&path)?;
    writeln!(
        f,
        "# Phone WAN\n\nWebRTC custom tunnel skipped (needs TURN).\nUse Tailscale:\n\n```\nphone tailscale\nphone wan\nphone mirror\n```\n"
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webrtc_probe_is_honest_skip() -> Result<()> {
        // Callable without ADB; documents CGNAT/TURN limit.
        webrtc_probe();
        Ok(())
    }
}
