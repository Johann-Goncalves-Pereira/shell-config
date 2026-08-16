# strip_image

The welcome manual for humans. Its purpose is to explain what the project is, why it exists, and how a person can install and use it.

## What it is

A terminal UI that walks the **directory you are in**, finds images at every nested level, shows which metadata they have, and can strip **all** of that metadata from the files you keep selected.

It exists so you can inspect and remove camera, GPS, IPTC, XMP, software history, AI/C2PA, and similar tags before sharing photos — without opening a desktop editor, and without descending into ignored trees like `node_modules` or `.pnpm-store`.

## Requirements

- [Go](https://go.dev/) (module uses Go 1.26)
- [ExifTool](https://exiftool.org/) on your `PATH` (read and strip)
- A terminal that can run a full-screen TUI

## Install and run

From this repo’s zsh config, `strip_image` is a shell function. It installs the CLI and runs it **in your current folder** (that folder is the scan root):

```zsh
cd /path/with/photos
strip_image
```

If you are not using that function, from this directory:

```bash
go install ./cmd/strip_image
# then, in the folder you want to scan:
strip_image
```

Or without installing:

```bash
# still scans the directory you are in, not this module folder
go -C /path/to/scripts/strip_image install ./cmd/strip_image
```

Do not `cd` into this module and then run the binary if you meant to scan another tree: the app uses the process working directory.

## How to use

1. Wait for the scan (spinner).
2. Every image starts **checked**. Move with **↑/↓** or **j/k**. **space** toggles. The lower pane lists metadata that is actually present, grouped by category.
3. **enter** asks you to confirm, then strips all ExifTool-managed tags in place (`-overwrite_original`).
4. **q** or **ctrl+c** quits. If you have not confirmed strip, nothing is written.

Category-by-category strip is not available yet: selected files lose **everything** ExifTool can clear.

## Scan rules (for operators)

- Recursive, all depths, from the current working directory
- Skips `.git` and paths matching `.gitignore` (including parent/nested gitignores)
- Treats raster, vector, RAW, and project/document extensions as images, plus files sniffed as `image/*`
- Filesystem fields (name, size, MIME, dates, permissions) come from the OS, not only ExifTool
