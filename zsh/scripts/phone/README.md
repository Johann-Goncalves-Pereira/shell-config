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
pm                   # USB → Tailscale → LAN → mDNS wireless-debug
phone status
phone doctor         # why cable/ADB missing (USB mode, adbkey match, watch, ssh)
phone doctor --save  # once on trusted Mac: store expected-adbkey.pub
phone ssh            # out-of-band SSH into phone's Termux (port 8022)
phone backup         # rsync /sdcard/ (DCIM, Docs, Downloads) to Mac
pwatch / punwatch    # install or stop the phone-watch LaunchAgent
```

`phone watch` notices a Samsung cable even when `adb devices` is empty. If the
gadget is **RNDIS/tether** or otherwise not File transfer, it uses **wireless
ADB** (saved LAN/Tailscale host) to run `svc usb setFunctions mtp` so the cable
comes back as MTP+ADB — no screen. Keep Wi‑Fi/Tailscale up so that path works.
Log: `~/Library/Logs/phone-watch.log`.

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

## Out-of-band SSH (`phone ssh`)

When ADB is down, unresponsive, or dropped during network change, SSH runs
independently inside the phone's Termux environment:

```bash
phone ssh                      # Interactive shell in Termux on the phone
phone ssh "uptime"             # Run remote command non-interactively
phone ssh "adb devices"        # Use on-device ADB as uid=2000 (shell)
```

- **Port:** `8022`
- **Key:** `~/.config/phone-adb/id_phone_ed25519` (auto-authorized in Termux `~/.ssh/authorized_keys`)
- **Transport:** Resolves LAN host (`192.168.131.171`) first; fails over to Tailscale (`100.105.116.21`).
- **Autostart:** Termux:Boot launches `~/.termux/boot/start-ssh` on boot and acquires `termux-wake-lock`.

## Backups (`phone backup`)

Incremental, delta-synced storage backup from phone to Mac:

```bash
phone backup                      # Delta-syncs /sdcard/DCIM, Documents, and Download
phone backup /sdcard/DCIM         # Backup a specific directory
phone backup --dest ~/MyBackup    # Custom local destination
```

- **Mechanism:** High-speed `rsync -avz --delete` over the SSH tunnel (`port 8022`), with automatic fallback to `adb pull`.
- **Automated 24h Background Sync:** The Mac LaunchAgent (`phone watch`) checks every 15s. If the phone is reachable and the last backup is > 24 hours old, it silently spawns `phone backup` in the background.

## Termux on-device Self-Healing Guard

The phone runs an on-device watchdog (`~/bin/usb-lab-guard.sh`) started by
Termux:Boot and kept alive with `termux-wake-lock`:

```bash
phone termux-guard   # Pushes scripts, Termux:Boot entries, SSH keys, starts nohup loop
```

- **Dynamic Loopback Recovery:** If classic `:5555` drops on cold reboot, the guard scans local loopback ports for Android 11+ TLS Wireless Debugging (`35000-48000`), connects automatically, and re-arms `adb tcpip 5555`.
- **SSH Daemon Watchdog:** Checks `pidof sshd` every 20s and restarts `sshd -p 8022` if terminated.
- **USB Mode Lock:** Enforces `svc usb setFunctions mtp` so the phone always presents MTP+ADB to computers.
- **Battery & Thermal Protection:** Enforces `protect_battery = 1` (caps charge at 80% to protect the battery 24/7) and `stay_on_while_plugged_in = 7`.
- **Heartbeat Log:** `/sdcard/phone-lab/guard-heartbeat.txt`.

## Emergency Headless Controls

### 1. Headless Wi-Fi Network Connection
If you move the phone to a new location or Wi-Fi network:
```bash
# Via SSH (Wi-Fi or Tailscale):
phone ssh "cmd wifi connect-network <SSID_NAME> wpa2 <PASSWORD>"

# Or via USB cable:
adb -s RXCW102PVAP shell "cmd wifi connect-network <SSID_NAME> wpa2 <PASSWORD>"
```

### 2. Tailscale Key Expiry (Important)
Tailscale by default expires node authorization after 180 days.
To prevent being locked out remotely:
1. Go to [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines).
2. Locate `johanns-samsung-s23ultra`.
3. Click `...` and select **Disable key expiry**.

### 3. Hardware DisplayPort / Samsung DeX Fallback
The Galaxy S23 Ultra natively supports **DisplayPort Alt Mode over USB-C**.
If ADB, Wi-Fi, and network are completely lost:
- Connect a standard **USB-C multi-port hub with HDMI out and a USB mouse**.
- Connect HDMI to any TV or external monitor.
- Samsung DeX will immediately project a full desktop UI onto the monitor, allowing full navigation and setting recovery with the mouse.

### 4. System Update Freeze
Samsung OTA update engines have been frozen to prevent unexpected firmware reboots:
- `auto_update_system = 0`
- `com.sec.android.soagent` (disabled)
- `com.wssyncmldm` (disabled)

## Lock PIN from the Mac (no panel)

Stock Android will **not** unlock ADB for a random PC using only the phone
PIN. ADB trusts a **host RSA key** (separate from the lock screen). The lab
model is: **one shared ADB identity** on every machine you use + the phone PIN.

```bash
# On every computer that should control the phone (same files everywhere):
#   ~/.android/adbkey + adbkey.pub   ← already Allow'd once on the phone
#   ~/.config/phone-adb/pin          ← lock PIN (chmod 600)
#   ~/.config/phone-adb/serial       ← RXCW102PVAP

echo 'YOUR_PIN' > ~/.config/phone-adb/pin && chmod 600 ~/.config/phone-adb/pin
phone unlock    # cable in → types PIN over ADB (also runs before `pm`)
```

Flow you want: **plug cable → `phone unlock` / `pm` → control**. No new
“Allow USB debugging?” as long as that Mac uses the **same** `adbkey` pair.

After a **cold reboot**, Samsung may hide ADB until one unlock — keep lock
disabled for true headless reboot, or accept one OTG/keyboard unlock after
reboot; mid-session locks are fine with cable + `phone unlock`.

## Validate

```bash
./validate.sh
```

Config (gitignored, never commit):

- `~/.config/phone-adb/serial` — ADB serial (or `PHONE_ADB_SERIAL`)
- `host` / `wan-host` — LAN / Tailscale `ip:5555`
- `tailscale-peer` — MagicDNS name (or `PHONE_TAILSCALE_PEER`)

First-time: `adb devices` then write the serial into that file (or export
`PHONE_ADB_SERIAL`). If exactly one USB device is listed, the CLI auto-saves its
serial on first run.

Cursor agents run `cursor-auto-connect.sh` on session start (via
`~/.cursor/hooks.json`) to clear the Homebrew adb quarantine and warm wireless
ADB. After `./setup`, link that hook or copy from this repo’s
`zsh/scripts/phone/cursor-auto-connect.sh`.

## Any Mac (shared ADB identity — no RSA tap)

Do **not** let each Mac generate its own `~/.android/adbkey`. Copy the **same**
pair from a machine the phone already trusts (this M4’s keys):

```bash
# from a working Mac → any future Mac
scp ~/.android/adbkey ~/.android/adbkey.pub other:~/.android/
scp ~/.config/phone-adb/{serial,pin,host,wan-host} other:~/.config/phone-adb/
# on other:
chmod 600 ~/.android/adbkey ~/.config/phone-adb/pin
adb kill-server && adb devices   # should be `device`, not Allow dialog
phone unlock && pm
```

Store that `adbkey` + `pin` in your password manager so a future laptop is
just “install adb/phone CLI → restore two secrets → plug cable”.
