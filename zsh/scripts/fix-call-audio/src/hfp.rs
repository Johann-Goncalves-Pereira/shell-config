//! Detect Hands-Free Profile from system_profiler SPAudioDataType text.

#[derive(Default)]
struct Block {
    in_bt: bool,
    has_out: bool,
    out_ch: u32,
    rate: u32,
}

impl Block {
    fn is_hfp(&self) -> bool {
        self.in_bt
            && self.has_out
            && (self.out_ch == 1 || (self.rate > 0 && self.rate <= 24_000))
    }

    fn reset(&mut self) {
        *self = Self::default();
    }
}

/// True when a Bluetooth *output* block is mono or ≤24 kHz.
pub fn hfp_from_profiler(text: &str) -> bool {
    let mut block = Block::default();
    for line in text.lines() {
        if flush_if_header(&mut block, line) {
            return true;
        }
        apply_line(&mut block, line);
    }
    block.is_hfp()
}

fn flush_if_header(block: &mut Block, line: &str) -> bool {
    if !is_device_header(line) {
        return false;
    }
    let hit = block.is_hfp();
    block.reset();
    hit
}

fn apply_line(block: &mut Block, line: &str) {
    if line.contains("Transport: Bluetooth") {
        block.in_bt = true;
    }
    if let Some(n) = trailing_number(line, "Output Channels:") {
        block.has_out = true;
        block.out_ch = n;
    }
    if let Some(n) = trailing_number(line, "Current SampleRate:") {
        block.rate = n;
    }
}

fn is_device_header(line: &str) -> bool {
    let trimmed = line.trim_end();
    trimmed.starts_with("        ")
        && !trimmed.starts_with("         ")
        && trimmed.ends_with(':')
        && !trimmed.contains("Transport:")
}

fn trailing_number(line: &str, label: &str) -> Option<u32> {
    let rest = line.split(label).nth(1)?;
    rest.split_whitespace()
        .find_map(|tok| tok.parse::<u32>().ok())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_hfp_mono_16k() {
        let text = r#"
        WH-1000XM5 - Johann:

          Input Channels: 1
          Current SampleRate: 16000
          Transport: Bluetooth

        WH-1000XM5 - Johann:

          Default Output Device: Yes
          Output Channels: 1
          Current SampleRate: 16000
          Transport: Bluetooth
          Output Source: Default

        MacBook Pro Speakers:

          Output Channels: 2
          Current SampleRate: 48000
          Transport: Built-in
"#;
        assert!(hfp_from_profiler(text));
    }

    #[test]
    fn ignores_a2dp_stereo() {
        let text = r#"
        WH-1000XM5 - Johann:

          Input Channels: 1
          Current SampleRate: 16000
          Transport: Bluetooth

        WH-1000XM5 - Johann:

          Output Channels: 2
          Current SampleRate: 44100
          Transport: Bluetooth
"#;
        assert!(!hfp_from_profiler(text));
    }

    #[test]
    fn ignores_input_only_bt_block() {
        let text = r#"
        Pretinho:

          Input Channels: 1
          Current SampleRate: 16000
          Transport: Bluetooth
"#;
        assert!(!hfp_from_profiler(text));
    }
}
