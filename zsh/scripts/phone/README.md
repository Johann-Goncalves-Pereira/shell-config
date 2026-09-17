# Phone lab CLI (S23 Ultra)

Rust tool for the dead-screen Galaxy S23 Ultra: ADB harden, always-on prep,
Tailscale WAN, scrcpy, plus agent-friendly screenshot / UI / input. Xin-ji
rustfmt/clippy/nextest bar.

Shell only provides a thin wrapper (`phone` / `pm`) that builds and execs this
binary — logic lives here, not in zsh.

## First-time setup

```bash
phone prep          # harden developer options + wireless ADB
phone harden --show # verify
phone tailscale     # install/open Tailscale on the phone
phone mirror        # scrcpy: sign in to Tailscale (same account as Mac)
phone wan           # connect via Tailscale IP, else LAN
```

## Daily

```bash
pm                 # USB if cabled, else Tailscale/LAN automatically
phone status
```

Prefer a USB cable for `pm` — Tailscale adds ~100–300ms. If the cable is
plugged but `pm` still says Tailscale, run `phone usb` then `pm`.

Over Tailscale/LAN only, `pm` uses a light stream (`-m800 -b2M` 20fps, no
audio). Override: `pm -- -m 1024 -b 4M`.

## Agents

Machine-readable status and device control (works with the panel soft-disabled):

```bash
phone --json status
phone shot                    # PNG → ~/.config/phone-adb/last-shot.png
phone --json ui               # compact uiautomator nodes + tap midpoints
phone tap 540 1200
phone type "hello world"
phone key BACK
phone launch com.android.settings
phone --json current
```

See [`.agents/skills/phone-operate/SKILL.md`](.agents/skills/phone-operate/SKILL.md).

## Broken panel (soft-disable)

```bash
phone screen off      # brightness 0 + sleep; saves prior settings
phone screen guard    # keep forcing sleep if power button wakes it (Ctrl+C stop)
phone screen on       # restore brightness / stay-on
phone screen status
```

Aliases: `pscreenoff`, `pscreenguard`, `pscreenon`.

Without root, Android cannot permanently ignore the power button. `screen off`
dims and sleeps the panel; `screen guard` re-sleeps it whenever it wakes.

## Validate

```bash
./validate.sh
```

Config (gitignored, never commit):

- `~/.config/phone-adb/serial` — ADB serial (or `PHONE_ADB_SERIAL`)
- `host` / `wan-host` — LAN / Tailscale `ip:5555`
- `tailscale-peer` — MagicDNS name (or `PHONE_TAILSCALE_PEER`)

First-time: `adb devices` then write the serial into that file (or export
`PHONE_ADB_SERIAL`).
