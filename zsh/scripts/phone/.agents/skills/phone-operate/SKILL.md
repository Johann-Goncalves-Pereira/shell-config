---
name: phone-operate
description: >-
  Operate the dead-screen S23 Ultra lab phone via the phone CLI: JSON status,
  screenshot, UI dump, tap/type/key/launch. Use when controlling the lab phone,
  ADB UI automation, or phone shot/ui/tap.
---

# Phone operate (lab S23 Ultra)

## Loop

1. `phone --json status` — if `reachable` is false, stop (USB or `phone wan`).
2. `phone shot` (or `phone --json shot`) — Read the PNG path returned.
3. `phone --json ui` — pick a clickable node’s `tap` midpoint.
4. Act: `phone tap X Y` / `phone type "…"` / `phone key BACK` / `phone launch PKG`.
5. Repeat from step 2 until done.

## Prefer named commands

Use `phone shot|ui|tap|swipe|type|key|launch|current` over raw `adb`.
`phone shell …` is the escape hatch only.

## Broken panel

Expected. Do **not** run `phone screen on` unless the user asks.
Do **not** run `pm` / `phone mirror` (human GUI / scrcpy).

## Privacy

Do not dump SMS, contacts, or notifications unless the user explicitly asked.

## JSON

`--json` prints one object on stdout. Errors are JSON on stderr with
`ok: false`, stable `error` code, and `message`. Interactive commands
(`mirror`, empty `shell`, `screen guard`) reject `--json`.
