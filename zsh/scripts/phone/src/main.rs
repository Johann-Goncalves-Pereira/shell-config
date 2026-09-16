//! `phone` — S23 Ultra lab control (ADB harden / always-on / WAN / scrcpy).
//! Logic lives in the library; zsh only installs and execs this binary.

use clap::{Parser, Subcommand};
use phone::config::{self, Config};
use phone::error::Result;
use phone::harden;
use phone::runner::{RealRunner, RealWait};
use phone::transport;
use phone::wan;

#[derive(Parser)]
#[command(
    name = "phone",
    about = "Dead-screen S23 Ultra lab phone via ADB",
    version
)]
struct Cli {
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
    /// Prefer Tailscale WAN, else LAN (skips custom WebRTC without TURN)
    Wan {
        #[arg(default_value_t = config::DEFAULT_ADB_PORT)]
        port: u16,
    },
    /// Install/open Tailscale on the phone (+ best-effort Mac cask)
    Tailscale,
    /// STUN/WebRTC feasibility note
    WebrtcProbe,
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
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let cfg = Config::load()?;
    let runner = RealRunner;
    let wait = RealWait;
    match cli.cmd {
        Commands::Status => transport::status(&runner, &cfg),
        Commands::Harden { show } => {
            let t = transport::transport(&runner, &cfg)?;
            if show {
                harden::show(&runner, &t)
            } else {
                harden::apply(&runner, &t)
            }
        }
        Commands::Prep => transport::prep(&runner, &wait, &cfg),
        Commands::Lock => transport::lock_trust(&runner, &cfg),
        Commands::Connect { host } => {
            transport::connect(&runner, &cfg, host.as_deref())
        }
        Commands::Tcpip { port } => {
            transport::tcpip(&runner, &wait, &cfg, port)
        }
        Commands::Wan { port } => wan::wan(&runner, &cfg, port),
        Commands::Tailscale => {
            let _ = wan::ensure_mac_tailscale(&runner);
            wan::tailscale_setup(&runner, &cfg)?;
            wan::write_note(&cfg)
        }
        Commands::WebrtcProbe => {
            wan::webrtc_probe();
            Ok(())
        }
        Commands::Mirror { args } => transport::mirror(&runner, &cfg, &args),
        Commands::Shell { args } => transport::shell_cmd(&runner, &cfg, &args),
    }
}
