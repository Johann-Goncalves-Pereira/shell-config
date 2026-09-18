//! JSON stdout envelope for agent-friendly CLI output.

use serde::Serialize;

use crate::error::{
    AgentError, DeviceError, Error, HideError, SessionError, ToolError,
};

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
        Error::Tool(ToolError::MissingSwitchAudio) => "missing_switchaudio",
        Error::Tool(ToolError::MissingBlueutil) => "missing_blueutil",
        Error::Tool(ToolError::MissingSwiftc) => "missing_swiftc",
        Error::Tool(ToolError::Spawn { .. }) => "spawn",
        Error::Tool(ToolError::ExitStatus { .. }) => "exit_status",
        Error::Tool(ToolError::CommandFailed { .. }) => "command_failed",
        Error::Device(DeviceError::MissingBuiltInMic) => "missing_mic",
        Error::Device(DeviceError::MissingBluetoothOut) => "missing_bt_out",
        Error::Device(DeviceError::NotFound { .. }) => "device_not_found",
        Error::Device(DeviceError::NotBluetooth { .. }) => "not_bluetooth",
        Error::Device(DeviceError::ReconnectTimeout { .. }) => {
            "reconnect_timeout"
        }
        Error::Session(SessionError::CreateDir { .. }) => "session_dir",
        Error::Session(SessionError::Write { .. }) => "session_write",
        Error::Session(SessionError::Read { .. }) => "session_read",
        Error::Hide(HideError::MissingSource { .. }) => "hide_missing_src",
        Error::Hide(HideError::Compile { .. }) => "hide_compile",
        Error::Hide(HideError::Run { .. }) => "hide_run",
        Error::Agent(AgentError::Bootstrap { .. }) => "agent_bootstrap",
        Error::Agent(AgentError::WritePlist { .. }) => "agent_plist",
        Error::Io(_) => "io",
    }
}
