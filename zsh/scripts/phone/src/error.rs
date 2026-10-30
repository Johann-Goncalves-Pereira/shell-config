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
    Control(#[from] ControlError),
    #[error(transparent)]
    Agent(#[from] AgentError),
    #[error(transparent)]
    Ssh(#[from] SshError),
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
    #[error(
        "lock PIN unknown — set PHONE_ADB_PIN or write it to the gitignored config pin file"
    )]
    MissingPin,
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
        "USB device {serial} not authorized on this Mac — the phone stores one RSA key per computer; with a dead panel copy ~/.android/adbkey* from a Mac that already runs pm, or accept Allow USB debugging once on a working display"
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
    #[error(
        "--json is not supported for `{cmd}` (interactive or long-running)"
    )]
    JsonUnsupported { cmd: String },
    #[error("doctor found failing checks — run: phone doctor")]
    DoctorFailed,
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

#[derive(Debug, Error)]
pub enum ControlError {
    #[error(
        "unknown key name `{name}` — use BACK/HOME/ENTER/SLEEP/WAKEUP or a numeric keycode"
    )]
    UnknownKey { name: String },
    #[error("screenshot write {path}: {source}")]
    ShotWrite { path: PathBuf, source: io::Error },
}

impl ControlError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::UnknownKey { .. } => "unknown_key",
            Self::ShotWrite { .. } => "shot_write",
        }
    }
}

#[derive(Debug, Error)]
pub enum AgentError {
    #[error("write LaunchAgent plist {path}: {source}")]
    WritePlist { path: PathBuf, source: io::Error },
    #[error("phone release binary missing at {path} — cargo build --release")]
    MissingBinary { path: PathBuf },
    #[error("launchctl bootstrap failed: {detail}")]
    Bootstrap { detail: String },
}

impl AgentError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::WritePlist { .. } => "agent_write_plist",
            Self::MissingBinary { .. } => "agent_missing_bin",
            Self::Bootstrap { .. } => "agent_bootstrap",
        }
    }
}

#[derive(Debug, Error)]
pub enum SshError {
    #[error("ssh target unreachable (tried LAN {lan:?} and WAN {wan:?})")]
    TargetUnreachable {
        lan: Option<String>,
        wan: Option<String>,
    },
    #[error("ssh command failed: {0}")]
    CommandFailed(String),
    #[error("backup failed: {0}")]
    BackupFailed(String),
}

impl SshError {
    pub fn code(&self) -> &'static str {
        match self {
            Self::TargetUnreachable { .. } => "ssh_target_unreachable",
            Self::CommandFailed(_) => "ssh_command_failed",
            Self::BackupFailed(_) => "ssh_backup_failed",
        }
    }
}

pub type Result<T> = std::result::Result<T, Error>;
