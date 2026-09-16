//! Injectable process runner and wait (shell boundary).

use std::process::{Command, Output};
use std::thread;
use std::time::Duration;

use crate::error::{AdbError, Result};

pub trait CommandRunner {
    fn output(&self, bin: &str, args: &[&str]) -> Result<Output>;
    fn status_inherit(&self, bin: &str, args: &[&str]) -> Result<()>;
}

pub trait Wait {
    fn wait_ms(&self, ms: u64);
}

pub struct RealRunner;

impl CommandRunner for RealRunner {
    fn output(&self, bin: &str, args: &[&str]) -> Result<Output> {
        Command::new(bin).args(args).output().map_err(|source| {
            AdbError::Spawn {
                bin: bin.to_string(),
                source,
            }
            .into()
        })
    }

    fn status_inherit(&self, bin: &str, args: &[&str]) -> Result<()> {
        let status =
            Command::new(bin).args(args).status().map_err(|source| {
                AdbError::Spawn {
                    bin: bin.to_string(),
                    source,
                }
            })?;
        if status.success() {
            Ok(())
        } else {
            Err(AdbError::ExitStatus {
                bin: bin.to_string(),
                status: status.to_string(),
            }
            .into())
        }
    }
}

pub struct RealWait;

impl Wait for RealWait {
    fn wait_ms(&self, ms: u64) {
        thread::sleep(Duration::from_millis(ms));
    }
}

#[cfg(test)]
#[path = "runner_test_support.rs"]
mod test_support;

#[cfg(test)]
pub use test_support::{RecordingWait, ScriptedRunner};
