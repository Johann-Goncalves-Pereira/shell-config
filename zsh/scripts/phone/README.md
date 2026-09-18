# Phone lab CLI (S23 Ultra)

Rust tool for the dead-screen Galaxy S23 Ultra: ADB harden, always-on prep,
Tailscale WAN, scrcpy, plus agent-friendly screenshot / UI / input. Xin-ji
rustfmt/clippy/nextest bar.

Shell only provides a thin wrapper (`phone` / `pm`) that builds and execs this
binary — logic lives here, not in zsh.

## First-time setup (always-on)

```bash
phone persist       # USB: harden + tcpip + try persist.adb.tcp.port + Tailscale whitelist
phone watch         # Mac LaunchAgent: re-arm tcpip on USB, reconnect WAN/LAN/mDNS
phone harden --show # verify
phone tailscale     # install/open Tailscale on the phone
phone mirror        # scrcpy: sign in to Tailscale (same account as Mac)
phone wan           # connect via Tailscale IP, else LAN
```

`phone prep` calls full `persist` when USB is present; soft prep otherwise.
`adb tcpip 5555` does **not** survive reboot on stock Samsung — use `phone watch`
so this Mac re-arms on cable, and/or wireless debugging (mDNS) after reboot.

`phone persist` also **forces Wi‑Fi never off**: sleep policy NEVER, kills Samsung
Auto/Intelligent Wi‑Fi, disables adaptive battery / low-power radio cuts, disables
Samsung Wi‑Fi AI packages, and the Mac watcher re-applies that profile every 15s
while USB is connected.

Lab USB default is **This device + MTP** (Transferring files): `svc usb setFunctions
mtp` + `setScreenUnlockedFunctions mtp`, re-forced by `phone persist` / `pwatch`
while cabled. Do not switch to “Connected device” (that is OTG host).

## Daily

```bash
pm                 # USB → Tailscale → LAN → mDNS wireless-debug
phone status
pwatch / punwatch  # install or stop the phone-watch LaunchAgent
```

Prefer a USB cable for `pm` — Tailscale adds ~100–300ms. If the cable is
plugged but `pm` still says Tailscale, run `phone usb` then `pm`.

Over Tailscale/LAN only, `pm` uses a light stream (`-m800 -b2M` 20fps, no
audio). Override: `pm -- -m 1024 -b 4M`.

After a phone reboot, wait until Wi‑Fi + Tailscale are up (often 30–90s), then
`pm`. Classic `:5555` returns only if persist props stuck or the watcher saw USB.

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
