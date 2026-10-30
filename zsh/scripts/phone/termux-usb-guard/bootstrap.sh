#!/data/data/com.termux/files/usr/bin/bash
# One-shot: install usb-lab-guard + sshd into Termux home + Termux:Boot.
set -euo pipefail
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_T="${HOME:-/data/data/com.termux/files/home}"
export HOME="$HOME_T"
export PATH="$PREFIX/bin:$PATH"
SRC=/sdcard/phone-lab
MARK="$HOME_T/.phone-lab/bootstrapped"
mkdir -p "$HOME_T/.termux/boot" "$HOME_T/.phone-lab" "$HOME_T/.android" "$HOME_T/bin" "$HOME_T/.ssh"

# Allow Termux:Boot / RUN_COMMAND helpers.
props="$HOME_T/.termux/termux.properties"
touch "$props"
if ! grep -q '^allow-external-apps' "$props" 2>/dev/null; then
  printf '\nallow-external-apps = true\n' >>"$props"
fi

cp "$SRC/usb-lab-guard.sh" "$HOME_T/bin/usb-lab-guard.sh"
chmod 755 "$HOME_T/bin/usb-lab-guard.sh"

# Termux:Boot entry — runs at every boot (after unlock / boot completed).
cat >"$HOME_T/.termux/boot/usb-lab-guard" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
sleep 8
nohup /data/data/com.termux/files/home/bin/usb-lab-guard.sh >/dev/null 2>&1 &
EOF
chmod 755 "$HOME_T/.termux/boot/usb-lab-guard"

# SSH keys setup
if [[ -f "$SRC/id_phone_ed25519.pub" ]]; then
  cat "$SRC/id_phone_ed25519.pub" >> "$HOME_T/.ssh/authorized_keys"
  sort -u "$HOME_T/.ssh/authorized_keys" -o "$HOME_T/.ssh/authorized_keys"
  chmod 700 "$HOME_T/.ssh"
  chmod 600 "$HOME_T/.ssh/authorized_keys"
fi

# Termux:Boot SSH entry
cat >"$HOME_T/.termux/boot/start-ssh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
/data/data/com.termux/files/usr/bin/sshd -p 8022
EOF
chmod 755 "$HOME_T/.termux/boot/start-ssh"

if [[ -f "$SRC/adbkey" ]]; then
  cp "$SRC/adbkey" "$HOME_T/.android/adbkey"
  cp "$SRC/adbkey.pub" "$HOME_T/.android/adbkey.pub" 2>/dev/null || true
  chmod 600 "$HOME_T/.android/adbkey"
fi

# Best-effort packages (needs network).
if command -v pkg >/dev/null 2>&1; then
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y libc++ android-tools termux-api openssh python >/dev/null 2>&1 || true
fi

# Ensure sshd is running
if command -v sshd >/dev/null 2>&1; then
  pkill -x sshd 2>/dev/null || true
  termux-wake-lock 2>/dev/null || true
  sshd -p 8022 >/dev/null 2>&1 || true
fi

# Start guard now.
pkill -f 'usb-lab-guard.sh' 2>/dev/null || true
nohup "$HOME_T/bin/usb-lab-guard.sh" >/dev/null 2>&1 &
echo "ok pid=$!" >"$MARK"
echo "ok pid=$! $(date)" >/sdcard/phone-lab/bootstrap-result.txt
echo "bootstrap ok"
