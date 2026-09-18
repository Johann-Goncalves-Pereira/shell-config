use clap::{Parser, Subcommand};
use fix_call_audio::agent;
use fix_call_audio::devices;
use fix_call_audio::enforce::{self, EnforceOpts};
use fix_call_audio::error::Result;
use fix_call_audio::json_out;
use fix_call_audio::runner::{RealRunner, RealWait};
use fix_call_audio::session;
use serde::Serialize;

#[derive(Parser)]
#[command(
    name = "fix-call-audio",
    about = "Keep Bluetooth headphones in A2DP; hide BT mic for this connection",
    version
)]
struct Cli {
    /// Emit one JSON object on stdout (errors as JSON on stderr)
    #[arg(long, global = true)]
    json: bool,

    /// Suppress banners
    #[arg(long)]
    quiet: bool,

    /// Skip Bluetooth reconnect (still hides BT mic)
    #[arg(long)]
    no_reset: bool,

    /// Optional input device name override
    input: Option<String>,

    /// Optional output device name override
    output: Option<String>,

    #[command(subcommand)]
    cmd: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Show devices, HFP state, and hide session
    Status,
    /// Install/start the LaunchAgent guard
    Watch,
    /// Stop and remove the LaunchAgent
    Unwatch,
    /// Long-running guard loop (LaunchAgent entrypoint)
    Guard,
}

#[derive(Serialize)]
struct StatusOut {
    input: String,
    output: String,
    hfp: bool,
    session: Option<String>,
    devices: Vec<devices::Device>,
}

fn main() {
    let cli = Cli::parse();
    let runner = RealRunner;
    let wait = RealWait;
    let result = dispatch(&cli, &runner, &wait);
    if let Err(err) = result {
        if cli.json {
            json_out::print_err(&err);
        } else {
            eprintln!("error: {err}");
        }
        std::process::exit(1);
    }
}

fn dispatch(cli: &Cli, runner: &RealRunner, wait: &RealWait) -> Result<()> {
    match &cli.cmd {
        None => run_enforce(cli, runner, wait),
        Some(Commands::Status) => run_status(cli, runner),
        Some(Commands::Watch) => agent::watch(runner),
        Some(Commands::Unwatch) => agent::unwatch(runner),
        Some(Commands::Guard) => agent::guard_loop(runner, wait),
    }
}

fn run_enforce(cli: &Cli, runner: &RealRunner, wait: &RealWait) -> Result<()> {
    let opts = EnforceOpts {
        quiet: cli.quiet,
        reset: !cli.no_reset,
        force_hide: true,
        input: cli.input.clone(),
        output: cli.output.clone(),
        session_path: session::default_path(),
    };
    let report = enforce::enforce(runner, wait, &opts)?;
    if cli.json {
        json_out::print_ok(&report_json(&report))?;
    }
    Ok(())
}

#[derive(Serialize)]
struct EnforceJson {
    input: String,
    output: String,
    hfp_after: bool,
    hidden: bool,
}

fn report_json(r: &enforce::EnforceReport) -> EnforceJson {
    EnforceJson {
        input: r.input.clone(),
        output: r.output.clone(),
        hfp_after: r.hfp_after,
        hidden: r.hidden,
    }
}

fn run_status(cli: &Cli, runner: &RealRunner) -> Result<()> {
    devices::ensure_switch_audio(runner)?;
    let list = devices::list_cli(runner)?;
    let input = devices::current(runner, "input")?;
    let output = devices::current(runner, "output")?;
    let hfp = enforce::hfp_active(runner, &list)?;
    let session = session::read(&session::default_path())?;
    let status = StatusOut {
        input,
        output,
        hfp,
        session,
        devices: list,
    };
    if cli.json {
        json_out::print_ok(&status)?;
    } else {
        println!("Input:  {}", status.input);
        println!("Output: {}", status.output);
        println!("HFP:    {}", status.hfp);
        match &status.session {
            Some(s) => println!("Session hide: {s}"),
            None => println!("Session hide: (none)"),
        }
    }
    Ok(())
}
