# AGENTS.md

Rulebook for AI working on the **phone** lab CLI. Humans: see [README.md](README.md).

## Skills (read before coding)

1. [`.agents/skills/rust-pro/SKILL.md`](.agents/skills/rust-pro/SKILL.md)

## Layout

| Path | Role |
| --- | --- |
| `src/main.rs` | CLI parse + exit mapping (shell) |
| `src/error.rs` | `thiserror` domain errors |
| `src/config.rs` | serial/host paths |
| `src/runner.rs` | injectable `CommandRunner` + `Wait` |
| `src/adb.rs` | ADB device/settings helpers over runner |
| `src/harden.rs` | curated developer-option table |
| `src/transport.rs` | connect / tcpip / mirror / prep / status |
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

## Commands

```bash
./validate.sh
phone status
phone prep
pm                 # USB if present, else Tailscale/LAN (no phone wan needed)
```
