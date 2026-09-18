//! Test doubles for [`crate::runner`] (cfg(test) only via path include).

use super::{CommandRunner, Wait};
use std::cell::RefCell;
use std::collections::HashMap;
use std::os::unix::process::ExitStatusExt;
use std::process::{ExitStatus, Output};

pub struct ScriptedRunner {
    pub replies: RefCell<HashMap<String, (i32, String, String)>>,
    pub calls: RefCell<Vec<String>>,
}

impl ScriptedRunner {
    pub fn new() -> Self {
        Self {
            replies: RefCell::new(HashMap::new()),
            calls: RefCell::new(Vec::new()),
        }
    }

    pub fn on(
        &self,
        key: impl Into<String>,
        code: i32,
        stdout: impl Into<String>,
        stderr: impl Into<String>,
    ) {
        self.replies
            .borrow_mut()
            .insert(key.into(), (code, stdout.into(), stderr.into()));
    }
}

impl Default for ScriptedRunner {
    fn default() -> Self {
        Self::new()
    }
}

impl CommandRunner for ScriptedRunner {
    fn output(&self, bin: &str, args: &[&str]) -> crate::error::Result<Output> {
        let key = format!("{bin} {}", args.join(" "));
        self.calls.borrow_mut().push(key.clone());
        let (code, stdout, stderr) = self
            .replies
            .borrow()
            .get(&key)
            .cloned()
            .unwrap_or((1, String::new(), format!("unhandled: {key}")));
        Ok(Output {
            status: ExitStatus::from_raw(code << 8),
            stdout: stdout.into_bytes(),
            stderr: stderr.into_bytes(),
        })
    }

    fn status_inherit(
        &self,
        bin: &str,
        args: &[&str],
    ) -> crate::error::Result<()> {
        let out = self.output(bin, args)?;
        if out.status.success() {
            Ok(())
        } else {
            Err(crate::error::ToolError::ExitStatus {
                bin: bin.to_string(),
                status: out.status.to_string(),
            }
            .into())
        }
    }
}

pub struct RecordingWait {
    pub calls: RefCell<Vec<u64>>,
}

impl Default for RecordingWait {
    fn default() -> Self {
        Self {
            calls: RefCell::new(Vec::new()),
        }
    }
}

impl Wait for RecordingWait {
    fn wait_ms(&self, ms: u64) {
        self.calls.borrow_mut().push(ms);
    }
}
