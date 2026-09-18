# fix-call-audio

Rust + Swift lab CLI that keeps Bluetooth headphones in high-quality A2DP
stereo. When Hands-Free Profile (HFP) kicks in — or you run the tool — it
reconnects the headset if needed and temporarily hides the Bluetooth
microphone for **this connection only**. Disconnect + reconnect restores the
mic.

Shell only provides a thin wrapper (`fix_call_audio` / `hqaudio`) that builds
and execs this binary — logic lives here, not in zsh.

## Daily

```bash
fix_call_audio          # enforce + hide BT mic
hqaudio                  # alias
fix_call_audio status
fix_call_audio watch    # LaunchAgent guard
fix_call_audio unwatch
```

## How it works

1. Detect HFP via Bluetooth **output** sample rate / channel count.
2. Optionally reconnect with `blueutil` to restore A2DP.
3. Run Swift `hide-bt-input`: deactivate BT input streams, set **HQ Call Mic**
   (Mac-mic-only aggregate) as default input.
4. Guard loop re-hides only after HFP; fresh BT connects leave the mic alone.

## Validate

```bash
./validate.sh
```

Requires: `SwitchAudioSource` (`brew install switchaudio-osx`), `blueutil`,
Xcode CLT (`swiftc`).
