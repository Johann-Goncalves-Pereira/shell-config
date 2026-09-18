# AGENTS.md

Rulebook for AI working on the **phone** lab CLI. Humans: see [README.md](README.md).

## Skills (read before coding)

1. [`.agents/skills/rust-pro/SKILL.md`](.agents/skills/rust-pro/SKILL.md) — when editing this crate
2. [`.agents/skills/phone-operate/SKILL.md`](.agents/skills/phone-operate/SKILL.md) — when **operating** the lab phone

## Layout

| Path | Role |
| --- | --- |
| `src/main.rs` | CLI parse + exit mapping (shell) |
| `src/error.rs` | `thiserror` domain errors |
| `src/json_out.rs` | `--json` success/error envelopes |
| `src/config.rs` | serial/host paths |
| `src/runner.rs` | injectable `CommandRunner` + `Wait` |
| `src/adb.rs` | ADB device/settings helpers over runner |
| `src/harden.rs` | curated developer-option table |
| `src/screen.rs` | Soft-disable / re-enable physical panel + power-wake guard |
| `src/control.rs` | Agent control: shot / ui / tap / type / key / launch |
| `src/transport.rs` | connect / tcpip / mirror / prep / status (+ mDNS) |
| `src/persist.rs` | always-on: tcpip + persist props + Tailscale whitelist |
| `src/agent.rs` | LaunchAgent watch / unwatch / guard |
| `src/wan.rs` | WebRTC probe + Tailscale WAN |
| `tests/` | integration with fake `adb` on `PATH` |
| `validate.sh` | fmt + clippy `-D warnings` + nextest |

## Strict rules

1. **Shell wrapper stays thin** — [`config/utils/phone.zsh`](../../config/utils/phone.zsh) only installs/execs. Never put `settings put` or ADB logic in zsh.
2. **Inject `CommandRunner`** — domain tables and ADB helpers must not call `std::process::Command` directly; tests supply a fake.
3. **`thiserror` only** — no `anyhow` / `Box<dyn Error>` in modules.
4. **No `.unwrap()` / `.expect()` / `panic!` / `todo!`** in prod or tests — `#[test] fn … -> Result<(), Error>`.
5. **No `unsafe`** unless the human explicitly asks.
6. **Never fake network success** — honest errors when Tailscale/APK download fails.
7. **Do not** commit secrets, APKs, or weaken clippy/rustfmt.
8. **`--json`** — one object on stdout; errors JSON on stderr. Interactive cmds reject it.

## Commands

```bash
./validate.sh
phone --json status
phone shot
phone --json ui
phone tap 100 200
phone persist      # USB always-on arm
phone watch        # LaunchAgent re-arm / reconnect
phone prep         # persist on USB, else soft prep
pm                 # USB → Tailscale → LAN → mDNS
phone screen off   # dim + sleep broken panel
phone screen guard # re-sleep if power button wakes it
phone screen on    # restore later
```
