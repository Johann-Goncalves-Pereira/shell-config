# AGENTS.md

The rulebook for AI. Its purpose is to tell autonomous coding agents exactly how the codebase is structured and what strict rules they must follow when writing or modifying code.

Humans should read [README.md](README.md). Follow this file when changing this module.

## Skills (read before coding)

Load and obey, in this order:

1. [`.agents/skills/strip-image/SKILL.md`](.agents/skills/strip-image/SKILL.md) — product behavior
2. [`.agents/skills/charm-stack/SKILL.md`](.agents/skills/charm-stack/SKILL.md) — Charm **v2** only
3. [`.agents/skills/golang-pro/SKILL.md`](.agents/skills/golang-pro/SKILL.md) — Go layout and quality
4. [`.agents/skills/golang-testing/SKILL.md`](.agents/skills/golang-testing/SKILL.md) — table-driven tests

Do not invent Charm v1 APIs or `github.com/charmbracelet/...` import paths.

## Layout

| Path | Role |
| --- | --- |
| `cmd/strip_image` | `main`: require ExifTool, `os.Getwd()`, run TUI |
| `internal/scan` | Recursive image discovery + gitignore |
| `internal/meta` | ExifTool JSON inspect + category mapping + OS file fields |
| `internal/strip` | In-place strip via ExifTool |
| `internal/tui` | Bubble Tea model |
| `testdata/` | Tiny fixtures |
| `skills-lock.json` | Locked skills; keep `strip-image` local entry |

Module path is `strip_image`. Do not add unused `pkg/`. Do not relocate `main` out of `cmd/strip_image`.

## Strict rules

1. **Scan root is process CWD** (`os.Getwd()`). Never default the walk to this module’s directory. Do not `chdir` to the module in the running binary.
2. **Respect ignore rules**: skip `.git` and paths matching `.gitignore` from the git work tree root through nested files. Do not walk `node_modules`, `.pnpm-store`, or other ignored dirs.
3. **ExifTool is required** for inspect and strip of writable formats. If it is missing, fail clearly and exit; do not silently no-op. Inspect with `-json -G -n`. Strip with `-all= -overwrite_original --`. **SVG** is stripped in Go (ExifTool cannot write SVG). Formats ExifTool cannot write are skipped, not treated as a hard strip failure.
4. **Strip-all only**: `internal/strip` must expose a full-strip API (`All` / `AllMany`). Do not add per-category strip UI or flags until that feature is explicitly requested. Keep the API easy to extend later.
5. **Charm v2 only**: `charm.land/bubbletea/v2`, `charm.land/bubbles/v2`, `charm.land/lipgloss/v2`. `View()` returns `tea.View` (not `string`). Keys are `tea.KeyPressMsg`. Space is `"space"`. Set `AltScreen` on the view, not via v1 commands.
6. **Selection UX**: all discovered images start selected; arrows/`j`/`k` move; space toggles; enter continues; `q` / `ctrl+c` quit without stripping if still on the list.
7. **Metadata display**: only **present** fields. Map known tags into the existing category constants; remaining tags use their ExifTool group name (never a catch-all Other). Filesystem properties stay in Go (`os.Stat`), not duplicated from skip-listed File: tags.
8. **Shell wrapper** lives in `zsh/config/utils.zsh` (parent config). If you change how the binary is built or named, update that function. Install with `go -C <module> install ./cmd/strip_image` and run from **GOBIN** (fallback `GOPATH/bin`) so asdf Go still works. The wrapper must not `cd` the user’s shell.
9. **Tests**: table-driven tests for scan filters (including gitignore), category mapping, and strip invocation (fake `exiftool` on `PATH`). Run `go test ./...` from this module. Do not require a real ExifTool in unit tests.
10. **Do not** commit secrets, rewrite git history, or skip hooks unless the human asked.

## Commands

```bash
go test ./...
go -C . install ./cmd/strip_image
```
