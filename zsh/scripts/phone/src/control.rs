//! Device control for agents: screenshot, UI dump, tap/type/key, launch.

use std::fs;
use std::path::{Path, PathBuf};

use serde::Serialize;

use crate::adb;
use crate::config::Config;
use crate::error::{ControlError, Result};
use crate::json_out;
use crate::runner::CommandRunner;
use crate::transport;

const UI_DUMP_PATH: &str = "/data/local/tmp/phone-ui.xml";

#[derive(Debug, Serialize)]
pub struct ShotResult {
    pub ok: bool,
    pub path: String,
    pub bytes: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct UiNode {
    pub text: String,
    pub content_desc: String,
    pub class: String,
    pub clickable: bool,
    pub bounds: [i32; 4],
    pub tap: [i32; 2],
}

#[derive(Debug, Serialize)]
pub struct UiResult {
    pub ok: bool,
    pub nodes: Vec<UiNode>,
}

#[derive(Debug, Serialize)]
pub struct OkMsg {
    pub ok: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct CurrentApp {
    pub ok: bool,
    pub package: String,
    pub activity: String,
}

pub fn shot(
    runner: &dyn CommandRunner,
    cfg: &Config,
    out: Option<&Path>,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    let path = resolve_shot_path(cfg, out);
    let png = adb::exec_out(runner, &t, &["screencap", "-p"])?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|source| {
            ControlError::ShotWrite {
                path: path.clone(),
                source,
            }
        })?;
    }
    fs::write(&path, &png).map_err(|source| ControlError::ShotWrite {
        path: path.clone(),
        source,
    })?;
    let result = ShotResult {
        ok: true,
        path: path.display().to_string(),
        bytes: png.len(),
    };
    if json {
        json_out::print_ok(&result)
    } else {
        println!("Screenshot: {} ({} bytes)", result.path, result.bytes);
        Ok(())
    }
}

fn resolve_shot_path(cfg: &Config, out: Option<&Path>) -> PathBuf {
    out.map(Path::to_path_buf)
        .unwrap_or_else(|| cfg.dir().join("last-shot.png"))
}

pub fn ui(runner: &dyn CommandRunner, cfg: &Config, json: bool) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    let _ =
        adb::shell(runner, &t, &format!("uiautomator dump {UI_DUMP_PATH}"))?;
    let xml = adb::shell(runner, &t, &format!("cat {UI_DUMP_PATH}"))?;
    let nodes = parse_ui_nodes(&xml);
    let result = UiResult {
        ok: true,
        nodes: nodes.clone(),
    };
    if json {
        return json_out::print_ok(&result);
    }
    println!("UI nodes ({}):", nodes.len());
    for n in &nodes {
        let label = node_label(n);
        println!(
            "  tap=({},{}) clickable={} {}",
            n.tap[0], n.tap[1], n.clickable, label
        );
    }
    Ok(())
}

fn node_label(n: &UiNode) -> String {
    if !n.text.is_empty() {
        format!("text={:?}", n.text)
    } else if !n.content_desc.is_empty() {
        format!("desc={:?}", n.content_desc)
    } else {
        format!("class={}", n.class)
    }
}

pub fn tap(
    runner: &dyn CommandRunner,
    cfg: &Config,
    x: i32,
    y: i32,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    adb::adb_status(
        runner,
        &[
            "-s",
            &t,
            "shell",
            "input",
            "tap",
            &x.to_string(),
            &y.to_string(),
        ],
    )?;
    emit_ok(json, &format!("tapped ({x},{y})"))
}

pub fn swipe(
    runner: &dyn CommandRunner,
    cfg: &Config,
    pts: SwipePts,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    adb::adb_status(
        runner,
        &[
            "-s",
            &t,
            "shell",
            "input",
            "swipe",
            &pts.x1.to_string(),
            &pts.y1.to_string(),
            &pts.x2.to_string(),
            &pts.y2.to_string(),
            &pts.ms.to_string(),
        ],
    )?;
    emit_ok(
        json,
        &format!(
            "swiped ({},{})->({},{}) {}ms",
            pts.x1, pts.y1, pts.x2, pts.y2, pts.ms
        ),
    )
}

/// Coordinates for [`swipe`].
pub struct SwipePts {
    pub x1: i32,
    pub y1: i32,
    pub x2: i32,
    pub y2: i32,
    pub ms: u32,
}

pub fn type_text(
    runner: &dyn CommandRunner,
    cfg: &Config,
    text: &str,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    let encoded = encode_input_text(text);
    adb::adb_status(runner, &["-s", &t, "shell", "input", "text", &encoded])?;
    emit_ok(json, &format!("typed {text:?}"))
}

/// ADB `input text` uses `%s` for spaces.
pub fn encode_input_text(text: &str) -> String {
    text.replace(' ', "%s")
}

pub fn key(
    runner: &dyn CommandRunner,
    cfg: &Config,
    name: &str,
    json: bool,
) -> Result<()> {
    let code = resolve_key(name)?;
    let t = transport::transport(runner, cfg)?;
    adb::adb_status(runner, &["-s", &t, "shell", "input", "keyevent", &code])?;
    emit_ok(json, &format!("keyevent {name} ({code})"))
}

fn resolve_key(name: &str) -> Result<String> {
    let upper = name.to_ascii_uppercase();
    let code = match upper.as_str() {
        "BACK" => "4",
        "HOME" => "3",
        "ENTER" => "66",
        "SLEEP" => "223",
        "WAKEUP" | "WAKE" => "224",
        "POWER" => "26",
        "TAB" => "61",
        "DEL" | "DELETE" | "BACKSPACE" => "67",
        other if other.chars().all(|c| c.is_ascii_digit()) => other,
        _ => {
            return Err(ControlError::UnknownKey {
                name: name.to_string(),
            }
            .into());
        }
    };
    Ok(code.to_string())
}

pub fn launch(
    runner: &dyn CommandRunner,
    cfg: &Config,
    pkg: &str,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    adb::adb_status(
        runner,
        &[
            "-s",
            &t,
            "shell",
            "monkey",
            "-p",
            pkg,
            "-c",
            "android.intent.category.LAUNCHER",
            "1",
        ],
    )?;
    emit_ok(json, &format!("launched {pkg}"))
}

pub fn current(
    runner: &dyn CommandRunner,
    cfg: &Config,
    json: bool,
) -> Result<()> {
    let t = transport::transport(runner, cfg)?;
    let raw = adb::shell(runner, &t, "dumpsys window")?;
    let (package, activity) = parse_focused_app(&raw);
    let result = CurrentApp {
        ok: true,
        package,
        activity,
    };
    if json {
        return json_out::print_ok(&result);
    }
    println!("package:  {}", result.package);
    println!("activity: {}", result.activity);
    Ok(())
}

fn emit_ok(json: bool, message: &str) -> Result<()> {
    if json {
        json_out::print_ok(&OkMsg {
            ok: true,
            message: message.to_string(),
        })
    } else {
        println!("{message}");
        Ok(())
    }
}

/// Parse compact node list from uiautomator dump XML.
pub fn parse_ui_nodes(xml: &str) -> Vec<UiNode> {
    let mut nodes = Vec::new();
    for tag in xml.split("<node").skip(1) {
        let Some(attrs) = tag.split('>').next() else {
            continue;
        };
        if let Some(n) = parse_node_attrs(attrs) {
            nodes.push(n);
        }
    }
    nodes
}

fn parse_node_attrs(attrs: &str) -> Option<UiNode> {
    let text = attr(attrs, "text").unwrap_or_default();
    let content_desc = attr(attrs, "content-desc").unwrap_or_default();
    let class = attr(attrs, "class").unwrap_or_default();
    let clickable = attr(attrs, "clickable").as_deref() == Some("true");
    let bounds_raw = attr(attrs, "bounds")?;
    let bounds = parse_bounds(&bounds_raw)?;
    let tap = [(bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2];
    Some(UiNode {
        text,
        content_desc,
        class,
        clickable,
        bounds,
        tap,
    })
}

fn attr(attrs: &str, key: &str) -> Option<String> {
    let needle = format!("{key}=\"");
    let start = attrs.find(&needle)? + needle.len();
    let rest = &attrs[start..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

/// Bounds format: `[x1,y1][x2,y2]`.
pub fn parse_bounds(raw: &str) -> Option<[i32; 4]> {
    let cleaned = raw.replace(['[', ']', ','], " ");
    let nums: Vec<i32> = cleaned
        .split_whitespace()
        .filter_map(|s| s.parse().ok())
        .collect();
    if nums.len() != 4 {
        return None;
    }
    Some([nums[0], nums[1], nums[2], nums[3]])
}

pub fn parse_focused_app(raw: &str) -> (String, String) {
    for line in raw.lines() {
        if let Some(pair) = extract_mcurrentfocus(line) {
            return pair;
        }
    }
    for line in raw.lines() {
        if let Some(pair) = extract_focused_app(line) {
            return pair;
        }
    }
    (String::new(), String::new())
}

fn extract_mcurrentfocus(line: &str) -> Option<(String, String)> {
    let line = line.trim();
    if !line.contains("mCurrentFocus") && !line.contains("mFocusedApp") {
        return None;
    }
    // … u0 com.pkg/com.pkg.Activity}
    let after = line.rsplit(' ').next()?;
    let after = after.trim_end_matches('}');
    split_component(after)
}

fn extract_focused_app(line: &str) -> Option<(String, String)> {
    let line = line.trim();
    let rest = line.strip_prefix("mFocusedApp=")?;
    for token in rest.split_whitespace() {
        if token.contains('/') {
            return split_component(token.trim_end_matches('}'));
        }
    }
    None
}

fn split_component(comp: &str) -> Option<(String, String)> {
    let (pkg, act) = comp.split_once('/')?;
    if pkg.is_empty() {
        return None;
    }
    Some((pkg.to_string(), act.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encode_spaces_as_percent_s() -> Result<()> {
        assert_eq!(encode_input_text("hello world"), "hello%sworld");
        assert_eq!(encode_input_text("a  b"), "a%s%sb");
        Ok(())
    }

    #[test]
    fn parse_bounds_rect() -> Result<()> {
        assert_eq!(
            parse_bounds("[10,20][110,220]").as_ref(),
            Some(&[10, 20, 110, 220])
        );
        Ok(())
    }

    #[test]
    fn parse_ui_extracts_clickable_midpoint() -> Result<()> {
        let xml = r#"<?xml version='1.0'?>
<hierarchy>
  <node text="OK" content-desc="" class="android.widget.Button"
    clickable="true" bounds="[100,200][300,400]" />
  <node text="" content-desc="Close" class="android.view.View"
    clickable="false" bounds="[0,0][50,50]" />
</hierarchy>"#;
        let nodes = parse_ui_nodes(xml);
        assert_eq!(nodes.len(), 2);
        assert_eq!(nodes[0].text, "OK");
        assert!(nodes[0].clickable);
        assert_eq!(nodes[0].tap, [200, 300]);
        assert_eq!(nodes[1].content_desc, "Close");
        assert_eq!(nodes[1].tap, [25, 25]);
        Ok(())
    }

    #[test]
    fn parse_focused_from_dumpsys() -> Result<()> {
        let raw = "  mCurrentFocus=Window{abc u0 com.example/.MainActivity}\n";
        let (pkg, act) = parse_focused_app(raw);
        assert_eq!(pkg, "com.example");
        assert_eq!(act, ".MainActivity");
        Ok(())
    }

    #[test]
    fn resolve_named_keys() -> Result<()> {
        assert_eq!(resolve_key("BACK")?, "4");
        assert_eq!(resolve_key("home")?, "3");
        assert_eq!(resolve_key("66")?, "66");
        assert!(resolve_key("NOPE").is_err());
        Ok(())
    }

    #[test]
    fn shot_writes_exec_out_bytes() -> Result<()> {
        use crate::runner::ScriptedRunner;
        use std::cell::RefCell;
        use std::collections::HashMap;
        use std::time::{SystemTime, UNIX_EPOCH};

        let png = b"\x89PNG\r\nfake".to_vec();
        let runner = ScriptedRunner {
            which_adb: true,
            devices: "List of devices attached\nTESTSERIAL\tdevice\n".into(),
            shell_replies: RefCell::new(HashMap::new()),
            puts: RefCell::new(Vec::new()),
            exec_out: RefCell::new(Some(png.clone())),
            mdns: RefCell::new(None),
            shells: RefCell::new(Vec::new()),
        };
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| std::io::Error::other(e.to_string()))?
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("phone-shot-{stamp}"));
        let cfg = Config::with_dir("TESTSERIAL".into(), dir)?;
        let out = cfg.dir().join("agent.png");
        shot(&runner, &cfg, Some(&out), false)?;
        let got = std::fs::read(&out)?;
        assert_eq!(got, png);
        Ok(())
    }
}
