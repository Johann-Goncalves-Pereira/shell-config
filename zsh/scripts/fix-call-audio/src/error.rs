//! Domain errors for the fix-call-audio lab CLI.

use std::io;
use std::path::PathBuf;

use thiserror::Error;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Error)]
pub enum Error {
    #[error(transparent)]
    Tool(#[from] ToolError),
    #[error(transparent)]
    Device(#[from] DeviceError),
    #[error(transparent)]
    Session(#[from] SessionError),
    #[error(transparent)]
    Hide(#[from] HideError),
    #[error(transparent)]
    Agent(#[from] AgentError),
    #[error(transparent)]
    Io(#[from] io::Error),
}

#[derive(Debug, Error)]
pub enum ToolError {
    #[error("SwitchAudioSource not found — brew install switchaudio-osx")]
    MissingSwitchAudio,
    #[error("blueutil not found — brew install blueutil")]
    MissingBlueutil,
    #[error("swiftc not found — install Xcode Command Line Tools")]
    MissingSwiftc,
    #[error("spawn {bin}: {source}")]
    Spawn { bin: String, source: io::Error },
    #[error("{bin} failed: {status}")]
    ExitStatus { bin: String, status: String },
    #[error("{bin}: {stderr}")]
    CommandFailed { bin: String, stderr: String },
}

#[derive(Debug, Error)]
pub enum DeviceError {
    #[error("built-in Mac microphone not found")]
    MissingBuiltInMic,
    #[error("no connected Bluetooth audio output found")]
    MissingBluetoothOut,
    #[error("device not found: {name} ({kind})")]
    NotFound { name: String, kind: String },
    #[error("{name} is not a Bluetooth output (cannot reconnect)")]
    NotBluetooth { name: String },
    #[error("timed out waiting for {name} after reconnect")]
    ReconnectTimeout { name: String },
}

#[derive(Debug, Error)]
pub enum SessionError {
    #[error("create session dir {path}: {source}")]
    CreateDir { path: PathBuf, source: io::Error },
    #[error("write session {path}: {source}")]
    Write { path: PathBuf, source: io::Error },
    #[error("read session {path}: {source}")]
    Read { path: PathBuf, source: io::Error },
}

#[derive(Debug, Error)]
pub enum HideError {
    #[error("hide-bt-input source missing: {path}")]
    MissingSource { path: PathBuf },
    #[error("compile hide-bt-input failed: {detail}")]
    Compile { detail: String },
    #[error("hide-bt-input failed: {detail}")]
    Run { detail: String },
}

#[derive(Debug, Error)]
pub enum AgentError {
    #[error("launchctl bootstrap failed: {detail}")]
    Bootstrap { detail: String },
    #[error("write plist {path}: {source}")]
    WritePlist { path: PathBuf, source: io::Error },
}
