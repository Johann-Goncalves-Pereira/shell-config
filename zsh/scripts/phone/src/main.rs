use std::path::PathBuf;

use clap::{Parser, Subcommand};
use phone::config::{self, Config};
use phone::error::{AdbError, Result};
use phone::harden;
use phone::json_out;
use phone::runner::{RealRunner, RealWait};
use phone::{control, screen, transport, wan};

#[derive(Parser)]
#[command(
    name = "phone",
    about = "Dead-screen S23 Ultra lab phone via ADB",
    version
)]
struct Cli {
    /// Emit one JSON object on stdout (errors as JSON on stderr)
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    cmd: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show ADB devices and saved hosts
    Status,
    /// Apply curated developer options
    Harden {
        /// Only print current values
        #[arg(long)]
        show: bool,
    },
    /// Always-on profile (harden + Wi‑Fi never sleep + tcpip)
    Prep,
    /// Re-assert ADB trust never-expire
    Lock,
    /// adb connect to saved or given host
    Connect { host: Option<String> },
    /// Enable wireless ADB (USB required once)
    Tcpip {
        #[arg(default_value_t = config::DEFAULT_ADB_PORT)]
        port: u16,
    },
    /// Switch adbd back to USB (fast pm when cabled)
    Usb,
    /// Prefer Tailscale WAN, else LAN (skips custom WebRTC without TURN)
    Wan {
        #[arg(default_value_t = config::DEFAULT_ADB_PORT)]
        port: u16,
    },
    /// Install/open Tailscale on the phone (+ best-effort Mac cask)
    Tailscale,
    /// STUN/WebRTC feasibility note
    WebrtcProbe,
    /// Soft-disable / re-enable the physical panel
    Screen {
        #[command(subcommand)]
        cmd: ScreenCmd,
    },
    /// scrcpy with device screen off
    Mirror {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// adb shell
    Shell {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// Capture framebuffer PNG (works with panel soft-disabled)
    Shot {
        #[arg(long)]
        out: Option<PathBuf>,
    },
    /// Compact uiautomator node list
    Ui,
    /// Tap at framebuffer coordinates
    Tap { x: i32, y: i32 },
    /// Swipe between two points
    Swipe {
        x1: i32,
        y1: i32,
        x2: i32,
        y2: i32,
        #[arg(long, default_value_t = 300)]
        ms: u32,
    },
    /// Type text (spaces become %s for adb input)
    Type { text: String },
    /// Send a keyevent (BACK/HOME/ENTER/SLEEP/WAKEUP or numeric)
    Key { name: String },
    /// Launch app by package name
    Launch { package: String },
    /// Show focused package/activity
    Current,
}

#[derive(Subcommand)]
enum ScreenCmd {
    /// Dim + sleep panel (saves prior brightness for restore)
    Off,
    /// Restore brightness / stay-on and wake
    On,
    /// Show disabled flag + current wakefulness
    Status,
    /// Loop: force sleep again if power button wakes the panel
    Guard,
}

fn main() {
    let cli = Cli::parse();
    let json = cli.json;
    if let Err(e) = run(cli) {
        if json {
            json_out::print_err(&e);
        } else {
            eprintln!("error: {e}");
        }
        std::process::exit(1);
    }
}

fn run(cli: Cli) -> Result<()> {
    let json = cli.json;
    let cfg = Config::load()?;
    let runner = RealRunner;
    let wait = RealWait;
    match cli.cmd {
        Commands::Status => transport::status(&runner, &cfg, json),
        Commands::Harden { show } => run_harden(&runner, &cfg, show, json),
        Commands::Prep => {
            reject_json(json, "prep")?;
            transport::prep(&runner, &wait, &cfg)
        }
        Commands::Lock => {
            reject_json(json, "lock")?;
            transport::lock_trust(&runner, &cfg)
        }
        Commands::Connect { host } => {
            reject_json(json, "connect")?;
            transport::connect(&runner, &cfg, host.as_deref())
        }
        Commands::Tcpip { port } => {
            reject_json(json, "tcpip")?;
            transport::tcpip(&runner, &wait, &cfg, port)
        }
        Commands::Usb => {
            reject_json(json, "usb")?;
            transport::usb(&runner, &cfg)
        }
        Commands::Wan { port } => {
            reject_json(json, "wan")?;
            wan::wan(&runner, &cfg, port)
        }
        Commands::Tailscale => run_tailscale(&runner, &cfg, json),
        Commands::WebrtcProbe => {
            reject_json(json, "webrtc-probe")?;
            wan::webrtc_probe();
            Ok(())
        }
        Commands::Screen { cmd } => run_screen(&runner, &wait, &cfg, cmd, json),
        Commands::Mirror { args } => {
            reject_json(json, "mirror")?;
            transport::mirror(&runner, &cfg, &args)
        }
        Commands::Shell { args } => {
            reject_json(json, "shell")?;
            transport::shell_cmd(&runner, &cfg, &args)
        }
        Commands::Shot { out } => {
            control::shot(&runner, &cfg, out.as_deref(), json)
        }
        Commands::Ui => control::ui(&runner, &cfg, json),
        Commands::Tap { x, y } => control::tap(&runner, &cfg, x, y, json),
        Commands::Swipe { x1, y1, x2, y2, ms } => control::swipe(
            &runner,
            &cfg,
            control::SwipePts { x1, y1, x2, y2, ms },
            json,
        ),
        Commands::Type { text } => {
            control::type_text(&runner, &cfg, &text, json)
        }
        Commands::Key { name } => control::key(&runner, &cfg, &name, json),
        Commands::Launch { package } => {
            control::launch(&runner, &cfg, &package, json)
        }
        Commands::Current => control::current(&runner, &cfg, json),
    }
}

fn run_harden(
    runner: &RealRunner,
    cfg: &Config,
    show: bool,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    if show {
        harden::show(runner, &t, json)
    } else {
        reject_json(json, "harden")?;
        harden::apply(runner, &t)
    }
}

fn run_tailscale(runner: &RealRunner, cfg: &Config, json: bool) -> Result<()> {
    reject_json(json, "tailscale")?;
    let _ = wan::ensure_mac_tailscale(runner);
    wan::tailscale_setup(runner, cfg)?;
    wan::write_note(cfg)
}

fn run_screen(
    runner: &RealRunner,
    wait: &RealWait,
    cfg: &Config,
    cmd: ScreenCmd,
    json: bool,
) -> Result<()> {
    match cmd {
        ScreenCmd::Off => {
            reject_json(json, "screen off")?;
            screen::disable(runner, cfg)
        }
        ScreenCmd::On => {
            reject_json(json, "screen on")?;
            screen::enable(runner, cfg)
        }
        ScreenCmd::Status => screen::status(runner, cfg, json),
        ScreenCmd::Guard => {
            reject_json(json, "screen guard")?;
            screen::guard(runner, wait, cfg)
        }
    }
}

fn reject_json(json: bool, cmd: &str) -> Result<()> {
    if json {
        Err(AdbError::JsonUnsupported {
            cmd: cmd.to_string(),
        }
        .into())
    } else {
        Ok(())
    }
}
