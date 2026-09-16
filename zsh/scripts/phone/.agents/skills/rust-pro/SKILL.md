---
name: rust-pro
description: >-
  Idiomatic Rust for the phone lab CLI: thiserror, injectable CommandRunner,
  table-driven tests with fake adb on PATH, clippy -D warnings, rustfmt 80.
  Use when editing scripts/phone.
---

# Rust Pro (phone lab)

## Stack

- Edition **2024**, `rustfmt` max_width **80**
- Errors: **`thiserror`** domain enums (no `anyhow` in libs)
- CLI: `clap` derive in `main` only
- I/O: inject `CommandRunner` + `Wait`; never call `Command` from harden tables
- Tests: table-driven; fake `adb` script on `PATH`; `#[test] fn -> Result<(), E>`

## Do

- Run `./validate.sh` after changes
- Prefer free functions when nesting approaches clippy threshold 3
- Honest failures for missing adb / Tailscale / download

## Don't

- `.unwrap()` / `.expect()` / `todo!` / `panic!` in prod or tests
- Grow `config/utils/phone.zsh` beyond install+exec
- Fake WebRTC success without TURN
- Weaken `[lints.clippy]` or skip fmt
