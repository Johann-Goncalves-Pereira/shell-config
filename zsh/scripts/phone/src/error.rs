//! Domain errors for the phone lab CLI.

use std::io;
use std::path::PathBuf;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum Error {
    #[error(transparent)]
    Config(#[from] ConfigError),
    #[error(transparent)]
    Adb(#[from] AdbError),
    #[error(transparent)]
    Harden(#[from] HardenError),
    #[error(transparent)]
    Wan(#[from] WanError),
    #[error(transparent)]
    Io(#[from] io::Error),
}

#[derive(Debug, Error)]
pub enum ConfigError {
    #[error("create config dir {path}: {source}")]
    CreateDir { path: PathBuf, source: io::Error },
    #[error("write {path}: {source}")]
    Write { path: PathBuf, source: io::Error },
    #[error(
        "phone serial unknown — set PHONE_ADB_SERIAL or write it to the gitignored config serial file"
    )]
    MissingSerial,
}

#[derive(Debug, Error)]
pub enum AdbError {
    #[error("adb not found — brew install android-platform-tools")]
    MissingBinary,
    #[error("scrcpy not found — brew install scrcpy")]
    MissingScrcpy,
    #[error("adb {args}: {stderr}")]
    CommandFailed { args: String, stderr: String },
    #[error(
        "phone not reachable — plug USB or run: phone connect / phone tcpip / phone wan"
    )]
    Unreachable,
    #[error(
        "USB device {serial} not in 'device' state — plug cable and authorize"
    )]
    UsbUnauthorized { serial: String },
    #[error("could not read wlan0 IP — is Wi‑Fi connected?")]
    NoWifiIp,
    #[error("no host saved — pass IP:port or run phone tcpip")]
    NoSavedHost,
    #[error("failed to spawn {bin}: {source}")]
    Spawn { bin: String, source: io::Error },
    #[error("{bin} exited with status {status}")]
    ExitStatus { bin: String, status: String },
}

#[derive(Debug, Error)]
pub enum HardenError {
    #[error("settings put {ns}/{key} failed: {source}")]
    SettingsPut {
        ns: String,
        key: String,
        source: AdbError,
    },
}

#[derive(Debug, Error)]
pub enum WanError {
    #[error("Tailscale APK download failed")]
    ApkDownload,
    #[error("Tailscale APK install failed: {source}")]
    ApkInstall {
        #[from]
        source: AdbError,
    },
}

pub type Result<T> = std::result::Result<T, Error>;
