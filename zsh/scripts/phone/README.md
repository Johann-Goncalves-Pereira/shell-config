# Phone lab CLI (S23 Ultra)

Rust tool for the dead-screen Galaxy S23 Ultra: ADB harden, always-on prep,
Tailscale WAN, scrcpy. Xin-ji rustfmt/clippy/nextest bar.

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

`phone wan` is optional (explicit Tailscale connect / refresh).

## Commands

```bash
phone status
phone harden [--show]
phone prep
phone lock
phone connect [host]
phone tcpip [port]
phone wan
phone webrtc-probe
phone tailscale
phone mirror
phone shell …
```

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
