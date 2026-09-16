//! Config paths for the lab phone. Device IDs live only in gitignored local files / env.

use std::fs;
use std::path::{Path, PathBuf};

use crate::error::{ConfigError, Result};

pub const DEFAULT_ADB_PORT: u16 = 5555;

pub struct Config {
    serial: String,
    dir: PathBuf,
    tailscale_peer: String,
}

impl Config {
    pub fn load() -> Result<Self> {
        let dir = config_dir();
        fs::create_dir_all(&dir).map_err(|source| ConfigError::CreateDir {
            path: dir.clone(),
            source,
        })?;
        let serial = resolve_serial(&dir)?;
        let tailscale_peer = resolve_tailscale_peer(&dir);
        let cfg = Self {
            serial: serial.clone(),
            dir,
            tailscale_peer,
        };
        if !cfg.serial_path().exists() {
            cfg.write_serial(&serial)?;
        }
        Ok(cfg)
    }

    pub fn with_dir(serial: String, dir: PathBuf) -> Result<Self> {
        fs::create_dir_all(&dir).map_err(|source| ConfigError::CreateDir {
            path: dir.clone(),
            source,
        })?;
        let cfg = Self {
            serial,
            dir,
            tailscale_peer: String::new(),
        };
        cfg.write_serial(&cfg.serial)?;
        Ok(cfg)
    }

    pub fn tailscale_peer(&self) -> &str {
        &self.tailscale_peer
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    pub fn serial_path(&self) -> PathBuf {
        self.dir.join("serial")
    }

    pub fn host_path(&self) -> PathBuf {
        self.dir.join("host")
    }

    pub fn wan_host_path(&self) -> PathBuf {
        self.dir.join("wan-host")
    }

    pub fn tailscale_peer_path(&self) -> PathBuf {
        self.dir.join("tailscale-peer")
    }

    pub fn apks_dir(&self) -> PathBuf {
        self.dir.join("apks")
    }

    pub fn read_serial(&self) -> String {
        read_trim(&self.serial_path()).unwrap_or_else(|| self.serial.clone())
    }

    pub fn write_serial(&self, serial: &str) -> Result<()> {
        write_line(&self.serial_path(), serial)
    }

    pub fn read_host(&self) -> Option<String> {
        read_trim(&self.host_path())
    }

    pub fn write_host(&self, host: &str) -> Result<()> {
        write_line(&self.host_path(), host)
    }

    pub fn read_wan_host(&self) -> Option<String> {
        read_trim(&self.wan_host_path())
    }

    pub fn write_wan_host(&self, host: &str) -> Result<()> {
        write_line(&self.wan_host_path(), host)
    }
}

fn resolve_serial(dir: &Path) -> Result<String> {
    if let Ok(s) = std::env::var("PHONE_ADB_SERIAL") {
        let s = s.trim().to_string();
        if !s.is_empty() {
            return Ok(s);
        }
    }
    if let Some(s) = read_trim(&dir.join("serial")) {
        return Ok(s);
    }
    Err(ConfigError::MissingSerial.into())
}

fn resolve_tailscale_peer(dir: &Path) -> String {
    if let Ok(s) = std::env::var("PHONE_TAILSCALE_PEER") {
        let s = s.trim().to_string();
        if !s.is_empty() {
            return s;
        }
    }
    read_trim(&dir.join("tailscale-peer")).unwrap_or_default()
}

fn config_dir() -> PathBuf {
    if let Ok(p) = std::env::var("PHONE_ADB_DIR") {
        return PathBuf::from(p);
    }
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    let xdg = PathBuf::from(&home).join(".config/phone-adb");
    if dir_writable(&xdg) {
        return xdg;
    }
    let fallback = PathBuf::from(home).join(".shell-config/zsh/data/phone-adb");
    let _ = fs::create_dir_all(&fallback);
    fallback
}

/// Prefer a directory only when create + probe write succeed.
fn dir_writable(path: &Path) -> bool {
    if fs::create_dir_all(path).is_err() {
        return false;
    }
    let probe = path.join(".write-probe");
    match fs::write(&probe, b"ok") {
        Ok(()) => {
            let _ = fs::remove_file(&probe);
            true
        }
        Err(_) => false,
    }
}

fn read_trim(path: &Path) -> Option<String> {
    fs::read_to_string(path)
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn write_line(path: &Path, value: &str) -> Result<()> {
    fs::write(path, format!("{value}\n")).map_err(|source| {
        ConfigError::Write {
            path: path.to_path_buf(),
            source,
        }
        .into()
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn roundtrip_host_and_serial() -> Result<()> {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| std::io::Error::other(e.to_string()))?
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("phone-cfg-{stamp}"));
        let cfg = Config::with_dir("SERIAL1".into(), dir)?;
        assert_eq!(cfg.read_serial(), "SERIAL1");
        cfg.write_host("10.0.0.1:5555")?;
        assert_eq!(cfg.read_host().as_deref(), Some("10.0.0.1:5555"));
        cfg.write_wan_host("100.64.0.1:5555")?;
        assert_eq!(cfg.read_wan_host().as_deref(), Some("100.64.0.1:5555"));
        Ok(())
    }
}
