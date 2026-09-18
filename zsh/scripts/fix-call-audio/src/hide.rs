//! Build and run the Swift hide-bt-input helper.

use std::path::{Path, PathBuf};
use std::process::Output;

use crate::devices::stdout_utf8;
use crate::error::{HideError, Result, ToolError};
use crate::runner::CommandRunner;

pub fn crate_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

pub fn swift_source() -> PathBuf {
    crate_root().join("swift/hide-bt-input.swift")
}

pub fn hide_bin() -> PathBuf {
    crate_root().join("bin/hide-bt-input")
}

pub fn ensure_built(runner: &dyn CommandRunner) -> Result<PathBuf> {
    let src = swift_source();
    let bin = hide_bin();
    if !src.is_file() {
        return Err(HideError::MissingSource { path: src }.into());
    }
    if bin_is_fresh(&src, &bin) {
        return Ok(bin);
    }
    ensure_swiftc(runner)?;
    if let Some(parent) = bin.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let out = runner.output(
        "swiftc",
        &[
            "-O",
            "-o",
            bin.to_str().unwrap_or("bin/hide-bt-input"),
            src.to_str().unwrap_or("swift/hide-bt-input.swift"),
        ],
    )?;
    if !out.status.success() {
        return Err(HideError::Compile {
            detail: String::from_utf8_lossy(&out.stderr).into_owned(),
        }
        .into());
    }
    Ok(bin)
}

fn bin_is_fresh(src: &Path, bin: &Path) -> bool {
    let Ok(bin_meta) = std::fs::metadata(bin) else {
        return false;
    };
    let Ok(src_meta) = std::fs::metadata(src) else {
        return false;
    };
    let Ok(bin_mtime) = bin_meta.modified() else {
        return false;
    };
    let Ok(src_mtime) = src_meta.modified() else {
        return false;
    };
    bin_mtime >= src_mtime
}

fn ensure_swiftc(runner: &dyn CommandRunner) -> Result<()> {
    let out = runner.output("which", &["swiftc"])?;
    if out.status.success() {
        Ok(())
    } else {
        Err(ToolError::MissingSwiftc.into())
    }
}

pub fn run_hide(runner: &dyn CommandRunner, quiet: bool) -> Result<Output> {
    let bin = ensure_built(runner)?;
    let bin_s = bin.to_string_lossy().into_owned();
    let out = runner.output(&bin_s, &[])?;
    if out.status.success() {
        if !quiet {
            print!("{}", stdout_utf8(&out));
        }
        Ok(out)
    } else {
        Err(HideError::Run {
            detail: String::from_utf8_lossy(&out.stderr).into_owned(),
        }
        .into())
    }
}

pub fn status(runner: &dyn CommandRunner) -> Result<String> {
    let bin = ensure_built(runner)?;
    let bin_s = bin.to_string_lossy().into_owned();
    let out = runner.output(&bin_s, &["--status"])?;
    Ok(stdout_utf8(&out))
}
