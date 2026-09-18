//! JSON stdout envelope for agent-friendly CLI output.

use serde::Serialize;

use crate::error::{AdbError, ConfigError, Error, HardenError, WanError};

#[derive(Debug, Serialize)]
pub struct ErrEnvelope {
    pub ok: bool,
    pub error: &'static str,
    pub message: String,
}

pub fn print_ok<T: Serialize>(value: &T) -> Result<(), Error> {
    let s = serde_json::to_string(value)
        .map_err(|e| std::io::Error::other(e.to_string()))?;
    println!("{s}");
    Ok(())
}

pub fn print_err(err: &Error) {
    let envelope = ErrEnvelope {
        ok: false,
        error: error_code(err),
        message: err.to_string(),
    };
    if let Ok(s) = serde_json::to_string(&envelope) {
        eprintln!("{s}");
    } else {
        eprintln!("error: {err}");
    }
}

pub fn error_code(err: &Error) -> &'static str {
    match err {
        Error::Config(ConfigError::MissingSerial) => "missing_serial",
        Error::Config(ConfigError::CreateDir { .. }) => "config_create_dir",
        Error::Config(ConfigError::Write { .. }) => "config_write",
        Error::Adb(AdbError::MissingBinary) => "missing_adb",
        Error::Adb(AdbError::MissingScrcpy) => "missing_scrcpy",
        Error::Adb(AdbError::Unreachable) => "unreachable",
        Error::Adb(AdbError::UsbUnauthorized { .. }) => "usb_unauthorized",
        Error::Adb(AdbError::NoWifiIp) => "no_wifi_ip",
        Error::Adb(AdbError::NoSavedHost) => "no_saved_host",
        Error::Adb(AdbError::CommandFailed { .. }) => "command_failed",
        Error::Adb(AdbError::Spawn { .. }) => "spawn_failed",
        Error::Adb(AdbError::ExitStatus { .. }) => "exit_status",
        Error::Adb(AdbError::JsonUnsupported { .. }) => "json_unsupported",
        Error::Harden(HardenError::SettingsPut { .. }) => "harden_put",
        Error::Wan(WanError::ApkDownload) => "apk_download",
        Error::Wan(WanError::ApkInstall { .. }) => "apk_install",
        Error::Control(e) => e.code(),
        Error::Agent(e) => e.code(),
        Error::Io(_) => "io",
    }
}
