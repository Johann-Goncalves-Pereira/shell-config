#!/usr/bin/env bash
# Example recovery helper — copy ideas only; do not commit real serials/IPs.
# Usage after setting PHONE_ADB_SERIAL or writing config/serial:
#   phone prep
#   phone tcpip
set -euo pipefail
echo "Use: phone status | phone prep | phone tcpip | phone wan | pm"
echo "Config (gitignored): ~/.config/phone-adb/ or \$PHONE_ADB_DIR"
echo "Required files: serial, optional host / wan-host / tailscale-peer"
