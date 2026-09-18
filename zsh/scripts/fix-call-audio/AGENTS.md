# AGENTS.md

Rulebook for AI working on the **fix-call-audio** lab CLI. Humans: see
[README.md](README.md).

## Skills (read before coding)

1. [`.agents/skills/rust-pro/SKILL.md`](.agents/skills/rust-pro/SKILL.md) —
   when editing this crate

## Layout

| Path | Role |
| --- | --- |
| `src/main.rs` | CLI parse + exit mapping |
| `src/error.rs` | `thiserror` domain errors |
| `src/json_out.rs` | `--json` success/error envelopes |
| `src/runner.rs` | injectable `CommandRunner` + `Wait` |
| `src/devices.rs` | SwitchAudioSource parse + device pick |
| `src/hfp.rs` | `system_profiler` HFP detect |
| `src/session.rs` | hide-session file for current BT UID |
| `src/hide.rs` | build/run Swift `hide-bt-input` |
| `src/enforce.rs` | reconnect + hide + set defaults |
| `src/agent.rs` | LaunchAgent + `guard` loop |
| `src/offender.rs` | best-effort mic offender report |
| `swift/hide-bt-input.swift` | CoreAudio hide BT input |
| `validate.sh` | fmt + clippy `-D warnings` + nextest |

## Strict rules

1. **Shell wrapper stays thin** —
   [`config/utils/audio.zsh`](../../config/utils/audio.zsh) only builds/execs.
2. **Inject `CommandRunner`** — domain code must not call
   `std::process::Command` directly; tests supply a fake.
3. **`thiserror` only** — no `anyhow` / `Box<dyn Error>` in modules.
4. **No `.unwrap()` / `.expect()` / `panic!` / `todo!`** in prod or tests —
   `#[test] fn … -> Result<(), Error>`.
5. **No `unsafe`** unless the human explicitly asks.
6. **Swift is the only CoreAudio surface** — Rust never links CoreAudio.
7. **Do not** weaken clippy/rustfmt.
8. **`--json`** — one object on stdout; errors JSON on stderr.

## Commands

```bash
./validate.sh
fix-call-audio
fix-call-audio --json status
fix-call-audio watch
fix-call-audio unwatch
fix-call-audio guard
```
