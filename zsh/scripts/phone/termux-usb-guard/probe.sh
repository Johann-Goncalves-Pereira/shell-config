#!/data/data/com.termux/files/usr/bin/bash
ls -la "$HOME/.termux/boot" "$HOME/bin" "$HOME/.phone-lab" > /sdcard/phone-lab/listing.txt 2>&1
pgrep -af usb-lab >> /sdcard/phone-lab/listing.txt 2>&1 || true
tail -5 "$HOME/.phone-lab/usb-lab-guard.log" >> /sdcard/phone-lab/listing.txt 2>&1 || true
