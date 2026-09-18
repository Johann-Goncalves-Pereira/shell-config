//! Hide-session file tied to the current Bluetooth output UID.

use std::fs;
use std::path::{Path, PathBuf};

use crate::error::{Result, SessionError};

pub fn default_path() -> PathBuf {
    dirs_cache().join("fix-call-audio-bt-session")
}

fn dirs_cache() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
        .join("Library/Caches")
}

pub fn read(path: &Path) -> Result<Option<String>> {
    if !path.exists() {
        return Ok(None);
    }
    let s = fs::read_to_string(path).map_err(|source| SessionError::Read {
        path: path.to_path_buf(),
        source,
    })?;
    let trimmed = s.trim();
    if trimmed.is_empty() {
        Ok(None)
    } else {
        Ok(Some(trimmed.to_string()))
    }
}

pub fn mark(path: &Path, uid: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|source| {
            SessionError::CreateDir {
                path: parent.to_path_buf(),
                source,
            }
        })?;
    }
    fs::write(path, format!("{uid}\n")).map_err(|source| {
        SessionError::Write {
            path: path.to_path_buf(),
            source,
        }
    })?;
    Ok(())
}

pub fn clear(path: &Path) -> Result<()> {
    if path.exists() {
        fs::remove_file(path)?;
    }
    Ok(())
}

/// Clear session when BT UID disappeared or changed to a new connection.
pub fn sync(path: &Path, current_uid: Option<&str>) -> Result<bool> {
    let marked = read(path)?;
    match (marked.as_deref(), current_uid) {
        (Some(_), None) => {
            clear(path)?;
            Ok(true)
        }
        (Some(m), Some(c)) if m != c => {
            clear(path)?;
            Ok(true)
        }
        _ => Ok(false),
    }
}

pub fn should_hide(path: &Path, current_uid: Option<&str>) -> Result<bool> {
    let Some(c) = current_uid else {
        return Ok(false);
    };
    Ok(read(path)?.as_deref() == Some(c))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::Result;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp_session() -> Result<PathBuf> {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0);
        let dir = std::env::temp_dir().join(format!("fca-sess-{nanos}"));
        fs::create_dir_all(&dir)?;
        Ok(dir.join("session"))
    }

    #[test]
    fn mark_sync_and_should_hide() -> Result<()> {
        let path = temp_session()?;
        mark(&path, "AA-BB-CC-DD-EE-FF:output")?;
        assert!(should_hide(&path, Some("AA-BB-CC-DD-EE-FF:output"))?);
        assert!(!should_hide(&path, Some("11-22-33-44-55-66:output"))?);
        assert!(sync(&path, Some("11-22-33-44-55-66:output"))?);
        assert!(read(&path)?.is_none());
        mark(&path, "11-22-33-44-55-66:output")?;
        assert!(sync(&path, None)?);
        assert!(read(&path)?.is_none());
        Ok(())
    }
}
