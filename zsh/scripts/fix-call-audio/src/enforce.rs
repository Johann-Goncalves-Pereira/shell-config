//! Enforce Mac mic + BT out; reconnect on HFP; hide BT mic for this connection.

use std::path::{Path, PathBuf};

use crate::devices::{self, Device};
use crate::error::{DeviceError, Result};
use crate::hfp;
use crate::hide;
use crate::offender;
use crate::runner::{CommandRunner, Wait};
use crate::session;

#[derive(Debug, Clone)]
pub struct EnforceOpts {
    pub quiet: bool,
    /// When true, always reconnect BT (manual run). When false, only on HFP.
    pub reset: bool,
    pub force_hide: bool,
    pub input: Option<String>,
    pub output: Option<String>,
    pub session_path: PathBuf,
}

#[derive(Debug)]
pub struct EnforceReport {
    pub input: String,
    pub output: String,
    pub hfp_after: bool,
    pub hidden: bool,
}

pub fn profiler_hfp(runner: &dyn CommandRunner) -> Result<bool> {
    let out = runner.output("system_profiler", &["SPAudioDataType"])?;
    Ok(hfp::hfp_from_profiler(&devices::stdout_utf8(&out)))
}

pub fn hfp_active(
    runner: &dyn CommandRunner,
    devices_list: &[Device],
) -> Result<bool> {
    let current_in = devices::current(runner, "input")?;
    if devices_list.iter().any(|d| {
        d.kind == "input" && d.name == current_in && devices::is_bt_uid(&d.uid)
    }) {
        return Ok(true);
    }
    profiler_hfp(runner)
}

pub fn enforce(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    opts: &EnforceOpts,
) -> Result<EnforceReport> {
    devices::ensure_switch_audio(runner)?;
    if opts.reset {
        devices::ensure_blueutil(runner)?;
    }

    let mut list = devices::list_cli(runner)?;
    let current_out = devices::current(runner, "output")?;
    let bt_uid = devices::bt_output_uid(&list, &current_out);
    session::sync(&opts.session_path, bt_uid.as_deref())?;

    let output = resolve_output(opts, &list, &current_out)?;
    let is_hfp = hfp_active(runner, &list)?;
    let need_reset = opts.reset || is_hfp;
    let do_hide = opts.force_hide
        || need_reset
        || session::should_hide(&opts.session_path, bt_uid.as_deref())?;

    if do_hide {
        hide::run_hide(runner, true)?;
        list = devices::list_cli(runner)?;
    }

    let input = resolve_input(opts, &list)?;
    finish(
        runner,
        wait,
        opts,
        &list,
        RoutePlan {
            input: &input,
            output: &output,
            need_reset,
            do_hide,
        },
    )
}

fn resolve_output(
    opts: &EnforceOpts,
    list: &[Device],
    current_out: &str,
) -> Result<String> {
    if let Some(name) = &opts.output
        && devices::device_exists(list, name, "output")
    {
        return Ok(name.clone());
    }
    if let Some(name) = &opts.output {
        return Err(DeviceError::NotFound {
            name: name.clone(),
            kind: "output".into(),
        }
        .into());
    }
    devices::default_output(list, current_out)
}

fn resolve_input(opts: &EnforceOpts, list: &[Device]) -> Result<String> {
    if let Some(name) = &opts.input
        && devices::device_exists(list, name, "input")
    {
        return Ok(name.clone());
    }
    devices::default_input(list)
}

struct RoutePlan<'a> {
    input: &'a str,
    output: &'a str,
    need_reset: bool,
    do_hide: bool,
}

fn finish(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    opts: &EnforceOpts,
    list: &[Device],
    plan: RoutePlan<'_>,
) -> Result<EnforceReport> {
    if plan.need_reset && !opts.quiet {
        print_offender(runner);
    }
    let _ = devices::set_device(runner, "input", plan.input);
    if plan.need_reset {
        devices::ensure_blueutil(runner)?;
        reconnect_bt(runner, wait, list, plan.output)?;
        hide_and_mark(runner, opts)?;
    } else if plan.do_hide {
        hide_and_mark(runner, opts)?;
    }
    finalize(
        runner,
        opts,
        plan.input,
        plan.output,
        plan.do_hide || plan.need_reset,
    )
}

fn print_offender(runner: &dyn CommandRunner) {
    if let Ok(report) = offender::report(runner) {
        println!("{report}");
    }
}

fn hide_and_mark(runner: &dyn CommandRunner, opts: &EnforceOpts) -> Result<()> {
    hide::run_hide(runner, opts.quiet)?;
    mark_session(runner, &opts.session_path)
}

fn finalize(
    runner: &dyn CommandRunner,
    opts: &EnforceOpts,
    input_fallback: &str,
    output: &str,
    hidden: bool,
) -> Result<EnforceReport> {
    let list = devices::list_cli(runner)?;
    let input = match devices::default_input(&list) {
        Ok(name) => name,
        Err(_) => input_fallback.to_string(),
    };
    let _ = devices::set_device(runner, "input", &input);
    devices::set_device(runner, "output", output)?;
    let input_now = devices::current(runner, "input")?;
    let output_now = devices::current(runner, "output")?;
    let hfp_after = hfp_active(runner, &list)?;
    if !opts.quiet {
        print_done(&input_now, &output_now, hfp_after, hidden);
    }
    Ok(EnforceReport {
        input: input_now,
        output: output_now,
        hfp_after,
        hidden,
    })
}

fn reconnect_bt(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    list: &[Device],
    output: &str,
) -> Result<()> {
    let addr = devices::bt_address_for_output(list, output)?;
    let _ = runner.output("blueutil", &["--disconnect", &addr]);
    wait.wait_ms(2000);
    let out = runner.output("blueutil", &["--connect", &addr])?;
    if !out.status.success() {
        return Err(DeviceError::NotBluetooth {
            name: output.to_string(),
        }
        .into());
    }
    wait_for_output(runner, wait, output)
}

fn wait_for_output(
    runner: &dyn CommandRunner,
    wait: &dyn Wait,
    name: &str,
) -> Result<()> {
    for _ in 0..15 {
        let list = devices::list_cli(runner)?;
        if devices::device_exists(&list, name, "output") {
            return Ok(());
        }
        wait.wait_ms(1000);
    }
    Err(DeviceError::ReconnectTimeout {
        name: name.to_string(),
    }
    .into())
}

fn mark_session(runner: &dyn CommandRunner, path: &Path) -> Result<()> {
    let list = devices::list_cli(runner)?;
    let current_out = devices::current(runner, "output")?;
    if let Some(uid) = devices::bt_output_uid(&list, &current_out) {
        session::mark(path, &uid)?;
    }
    Ok(())
}

fn print_done(input: &str, output: &str, hfp: bool, hidden: bool) {
    println!();
    println!("Done:");
    println!("  Input:  {input}");
    println!("  Output: {output}");
    if hfp {
        println!(
            "Warning: Bluetooth still looks like HFP. An app may still hold the headset mic."
        );
    } else if hidden {
        println!(
            "  Bluetooth mic hidden for this connection (reconnect restores it)."
        );
    }
}
