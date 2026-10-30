//! Out-of-band SSH and rsync backup operations to the phone's Termux environment.

use std::net::{SocketAddr, TcpStream};
use std::path::Path;
use std::process::Command;
use std::time::Duration;

use crate::config::{Config, DEFAULT_SSH_PORT, DEFAULT_SSH_USER};
use crate::doctor::{Check, CheckStatus, check};
use crate::error::{Result, SshError};

/// Resolve the best IP for SSH: check LAN host first, then WAN/Tailscale.
pub fn resolve_ssh_ip(cfg: &Config) -> Result<String> {
    let lan_ip = cfg.read_host().and_then(|h| extract_ip(&h));
    let wan_ip = cfg.read_wan_host().and_then(|h| extract_ip(&h));

    if let Some(ref ip) = lan_ip
        && is_port_open(ip, DEFAULT_SSH_PORT)
    {
        return Ok(ip.clone());
    }

    if let Some(ref ip) = wan_ip
        && is_port_open(ip, DEFAULT_SSH_PORT)
    {
        return Ok(ip.clone());
    }

    if let Some(ip) = lan_ip.or(wan_ip) {
        return Ok(ip);
    }

    Err(SshError::TargetUnreachable {
        lan: cfg.read_host(),
        wan: cfg.read_wan_host(),
    }
    .into())
}

fn extract_ip(host_port: &str) -> Option<String> {
    let trimmed = host_port.trim();
    if trimmed.is_empty() {
        return None;
    }
    if let Some((ip, _)) = trimmed.rsplit_once(':') {
        Some(ip.to_string())
    } else {
        Some(trimmed.to_string())
    }
}

fn is_port_open(ip: &str, port: u16) -> bool {
    let Ok(addr) = format!("{ip}:{port}").parse::<SocketAddr>() else {
        return false;
    };
    TcpStream::connect_timeout(&addr, Duration::from_millis(800)).is_ok()
}

/// Run interactive or command-based SSH into Termux.
pub fn ssh(cfg: &Config, user_args: &[String]) -> Result<()> {
    let ip = resolve_ssh_ip(cfg)?;
    let key = cfg.ssh_key_path();
    let port_str = DEFAULT_SSH_PORT.to_string();
    let dest = format!("{DEFAULT_SSH_USER}@{ip}");

    let mut cmd = Command::new("ssh");
    cmd.arg("-p")
        .arg(&port_str)
        .arg("-i")
        .arg(&key)
        .arg("-o")
        .arg("StrictHostKeyChecking=no")
        .arg("-o")
        .arg("UserKnownHostsFile=/dev/null")
        .arg("-o")
        .arg("LogLevel=ERROR")
        .arg(&dest);

    for arg in user_args {
        cmd.arg(arg);
    }

    let status = cmd
        .status()
        .map_err(|e| SshError::CommandFailed(e.to_string()))?;
    if !status.success() {
        let code = status.code().unwrap_or(1);
        std::process::exit(code);
    }
    Ok(())
}

/// Backup phone directories to Mac using rsync or adb pull fallback.
pub fn backup(
    cfg: &Config,
    dest: Option<&Path>,
    remote_paths: &[String],
) -> Result<()> {
    let target_dest = match dest {
        Some(d) => d.to_path_buf(),
        None => cfg.backup_dir(),
    };
    std::fs::create_dir_all(&target_dest).map_err(|e| {
        SshError::BackupFailed(format!("mkdir {}: {e}", target_dest.display()))
    })?;

    let default_paths = vec![
        "/sdcard/DCIM".to_string(),
        "/sdcard/Documents".to_string(),
        "/sdcard/Download".to_string(),
    ];
    let paths = if remote_paths.is_empty() {
        &default_paths
    } else {
        remote_paths
    };

    let ip = resolve_ssh_ip(cfg).ok();
    let key = cfg.ssh_key_path();

    for remote in paths {
        let folder_name = Path::new(remote)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("data");
        let local_folder = target_dest.join(folder_name);
        std::fs::create_dir_all(&local_folder).map_err(|e| {
            SshError::BackupFailed(format!(
                "mkdir {}: {e}",
                local_folder.display()
            ))
        })?;

        println!("Backing up {remote} -> {}...", local_folder.display());
        let synced = if let Some(ref host_ip) = ip {
            run_rsync(&key, host_ip, remote, &local_folder)
        } else {
            false
        };

        if !synced {
            println!(
                "rsync over SSH failed/unavailable; falling back to adb pull..."
            );
            run_adb_pull(cfg, remote, &local_folder)?;
        }
        println!("Backup of {remote}: done");
    }
    println!("All backups finished -> {}", target_dest.display());
    Ok(())
}

fn run_rsync(key: &Path, ip: &str, remote: &str, local: &Path) -> bool {
    let ssh_opt = format!(
        "ssh -p {} -i {} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR",
        DEFAULT_SSH_PORT,
        key.display()
    );
    let src = format!("{}@{ip}:{remote}/", DEFAULT_SSH_USER);
    let status = Command::new("rsync")
        .arg("-avz")
        .arg("--delete")
        .arg("-e")
        .arg(&ssh_opt)
        .arg(&src)
        .arg(local)
        .status();

    matches!(status, Ok(s) if s.success())
}

fn run_adb_pull(cfg: &Config, remote: &str, local: &Path) -> Result<()> {
    let serial = cfg.read_serial();
    let status = Command::new("adb")
        .arg("-s")
        .arg(&serial)
        .arg("pull")
        .arg(remote)
        .arg(local)
        .status()
        .map_err(|e| SshError::BackupFailed(e.to_string()))?;

    if status.success() {
        Ok(())
    } else {
        Err(SshError::BackupFailed(format!("adb pull {remote} failed")).into())
    }
}

/// Doctor check for SSH out-of-band layer.
pub fn check_ssh(cfg: &Config) -> Check {
    let key = cfg.ssh_key_path();
    if !key.is_file() {
        return check(
            "ssh_key",
            CheckStatus::Warn,
            format!("missing {} — run: phone termux-guard", key.display()),
        );
    }
    match resolve_ssh_ip(cfg) {
        Ok(ip) => {
            if is_port_open(&ip, DEFAULT_SSH_PORT) {
                check(
                    "ssh_daemon",
                    CheckStatus::Ok,
                    format!("ready ({ip}:{DEFAULT_SSH_PORT} open)"),
                )
            } else {
                check(
                    "ssh_daemon",
                    CheckStatus::Warn,
                    format!(
                        "key ok, but {ip}:{DEFAULT_SSH_PORT} not responding"
                    ),
                )
            }
        }
        Err(_) => check(
            "ssh_daemon",
            CheckStatus::Warn,
            "no reachable IP found (check Wi‑Fi / Tailscale)",
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_ip_handles_various_formats() {
        assert_eq!(
            extract_ip("192.168.1.100:5555"),
            Some("192.168.1.100".to_string())
        );
        assert_eq!(
            extract_ip("100.105.116.21:5555"),
            Some("100.105.116.21".to_string())
        );
        assert_eq!(
            extract_ip("192.168.1.50"),
            Some("192.168.1.50".to_string())
        );
        assert_eq!(extract_ip("   "), None);
    }
}
