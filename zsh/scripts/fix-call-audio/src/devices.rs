//! SwitchAudioSource device listing and selection.

use serde::Serialize;

use crate::error::{DeviceError, Result, ToolError};
use crate::runner::CommandRunner;

pub const HQ_CALL_MIC: &str = "HQ Call Mic";
pub const BUILTIN_MIC_UID: &str = "BuiltInMicrophoneDevice";

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Device {
    pub name: String,
    pub kind: String,
    pub id: String,
    pub uid: String,
}

pub fn stdout_utf8(out: &std::process::Output) -> String {
    String::from_utf8_lossy(&out.stdout).into_owned()
}

pub fn ensure_switch_audio(runner: &dyn CommandRunner) -> Result<()> {
    let out = runner.output("which", &["SwitchAudioSource"])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(ToolError::MissingSwitchAudio.into())
    }
}

pub fn ensure_blueutil(runner: &dyn CommandRunner) -> Result<()> {
    let out = runner.output("which", &["blueutil"])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(ToolError::MissingBlueutil.into())
    }
}

pub fn list_cli(runner: &dyn CommandRunner) -> Result<Vec<Device>> {
    let out = runner.output("SwitchAudioSource", &["-a", "-f", "cli"])?;
    if !out.status.success() {
        return Err(ToolError::CommandFailed {
            bin: "SwitchAudioSource".into(),
            stderr: String::from_utf8_lossy(&out.stderr).into_owned(),
        }
        .into());
    }
    Ok(parse_cli_list(&stdout_utf8(&out)))
}

pub fn parse_cli_list(text: &str) -> Vec<Device> {
    text.lines()
        .filter_map(|line| {
            let parts: Vec<&str> = line.splitn(4, ',').collect();
            if parts.len() != 4 {
                return None;
            }
            Some(Device {
                name: parts[0].to_string(),
                kind: parts[1].to_string(),
                id: parts[2].to_string(),
                uid: parts[3].to_string(),
            })
        })
        .collect()
}

/// Classic Bluetooth UIDs look like `AA-BB-CC-DD-EE-FF:input|output`.
pub fn is_bt_uid(uid: &str) -> bool {
    let Some((addr, rest)) = uid.split_once(':') else {
        return false;
    };
    if rest != "input" && rest != "output" {
        return false;
    }
    let parts: Vec<&str> = addr.split('-').collect();
    if parts.len() != 6 {
        return false;
    }
    parts
        .iter()
        .all(|p| p.len() == 2 && p.chars().all(|c| c.is_ascii_hexdigit()))
}

pub fn current(runner: &dyn CommandRunner, kind: &str) -> Result<String> {
    let out = runner.output("SwitchAudioSource", &["-t", kind, "-c"])?;
    Ok(stdout_utf8(&out).trim().to_string())
}

pub fn set_device(
    runner: &dyn CommandRunner,
    kind: &str,
    name: &str,
) -> Result<()> {
    let out = runner.output("SwitchAudioSource", &["-t", kind, "-s", name])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(DeviceError::NotFound {
            name: name.to_string(),
            kind: kind.to_string(),
        }
        .into())
    }
}

pub fn default_input(devices: &[Device]) -> Result<String> {
    if devices
        .iter()
        .any(|d| d.kind == "input" && d.name == HQ_CALL_MIC)
    {
        return Ok(HQ_CALL_MIC.to_string());
    }
    devices
        .iter()
        .find(|d| d.kind == "input" && d.uid == BUILTIN_MIC_UID)
        .map(|d| d.name.clone())
        .ok_or_else(|| DeviceError::MissingBuiltInMic.into())
}

pub fn default_output(devices: &[Device], current_out: &str) -> Result<String> {
    let candidates: Vec<&Device> = devices
        .iter()
        .filter(|d| d.kind == "output" && is_bt_uid(&d.uid))
        .collect();
    pick_bt_output(&candidates, devices, current_out)
}

fn pick_bt_output(
    candidates: &[&Device],
    devices: &[Device],
    current_out: &str,
) -> Result<String> {
    if candidates.is_empty() {
        return Err(DeviceError::MissingBluetoothOut.into());
    }
    if candidates.len() == 1 {
        return Ok(candidates[0].name.clone());
    }
    if let Some(d) = candidates.iter().find(|d| d.name == current_out) {
        return Ok(d.name.clone());
    }
    for c in candidates {
        let has_in = devices
            .iter()
            .any(|d| d.kind == "input" && d.name == c.name);
        if has_in {
            return Ok(c.name.clone());
        }
    }
    Ok(candidates[0].name.clone())
}

pub fn bt_address_for_output(devices: &[Device], name: &str) -> Result<String> {
    let uid = devices
        .iter()
        .find(|d| d.kind == "output" && d.name == name)
        .map(|d| d.uid.as_str())
        .ok_or_else(|| DeviceError::NotFound {
            name: name.to_string(),
            kind: "output".into(),
        })?;
    if !is_bt_uid(uid) {
        return Err(DeviceError::NotBluetooth {
            name: name.to_string(),
        }
        .into());
    }
    let addr = uid.split_once(':').map(|(a, _)| a).unwrap_or(uid);
    Ok(addr.to_string())
}

pub fn bt_output_uid(devices: &[Device], current_out: &str) -> Option<String> {
    let name = default_output(devices, current_out).ok()?;
    devices
        .iter()
        .find(|d| d.kind == "output" && d.name == name)
        .map(|d| d.uid.clone())
}

pub fn device_exists(devices: &[Device], name: &str, kind: &str) -> bool {
    devices.iter().any(|d| d.kind == kind && d.name == name)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::Result;

    #[test]
    fn parse_cli_and_pick_devices() -> Result<()> {
        let text = "\
MacBook Pro Microphone,input,96,BuiltInMicrophoneDevice
WH-1000XM5 - Johann,input,107,88-C9-E8-0B-46-FB:input
WH-1000XM5 - Johann,output,101,88-C9-E8-0B-46-FB:output
MacBook Pro Speakers,output,89,BuiltInSpeakerDevice
HQ Call Mic,input,200,com.shell-config.hq-call-mic
";
        let devices = parse_cli_list(text);
        assert_eq!(devices.len(), 5);
        assert!(is_bt_uid("88-C9-E8-0B-46-FB:output"));
        assert!(!is_bt_uid("BuiltInMicrophoneDevice"));
        assert_eq!(default_input(&devices)?, HQ_CALL_MIC);
        assert_eq!(
            default_output(&devices, "MacBook Pro Speakers")?,
            "WH-1000XM5 - Johann"
        );
        assert_eq!(
            bt_address_for_output(&devices, "WH-1000XM5 - Johann")?,
            "88-C9-E8-0B-46-FB"
        );
        Ok(())
    }
}
