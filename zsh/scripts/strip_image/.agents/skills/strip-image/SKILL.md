---
name: strip-image
description: Charm v2 Bubble Tea CLI that recursively scans the current working directory for images, lists metadata via ExifTool, and strips all tags from selected files. Use when changing strip_image, image metadata stripping, or this TUI.
---

# strip_image

## Behavior

- Scan starts at process CWD (`os.Getwd()`), recursive, all depths.
- Skip `.git` and paths matching `.gitignore` (repo-root and nested), including `node_modules` and `.pnpm-store`.
- Images: raster/RAW extensions plus `image/*` MIME sniff. Skip SVG unless sniffed as `image/*`.
- **ExifTool is required** for inspect (`-json -G -n`) and strip (`-all= -overwrite_original`).
- Filesystem fields (name, size, MIME, dates, mode) come from Go `os.Stat`.
- All images start selected. Arrows/`j`/`k` move, **space** toggles, **enter** confirms then strips **all** metadata.
- Category-selective strip is not implemented; keep `strip.All` as the only strip API until then.
- Charm **v2** only (`charm.land/...`): `View() tea.View`, `tea.KeyPressMsg`, `v.AltScreen = true`.

## Layout

- `cmd/strip_image` — entry
- `internal/scan` — walk
- `internal/meta` — ExifTool JSON → category groups
- `internal/strip` — in-place strip
- `internal/tui` — Bubble Tea
