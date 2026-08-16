package tui

import (
	"path/filepath"
	"strings"

	"strip_image/internal/meta"
)

type listKind int

const (
	listHeader listKind = iota
	listFile
)

type listRow struct {
	kind   listKind
	dir    string
	imgIdx int
}

func groupDir(rel string) string {
	rel = filepath.ToSlash(filepath.Clean(strings.ReplaceAll(rel, "\\", "/")))
	d := filepath.ToSlash(filepath.Dir(rel))
	d = strings.Trim(d, "/")
	if d == "." || d == "" {
		return "."
	}
	return d
}

func groupLeaf(rel string) string {
	return filepath.ToSlash(filepath.Base(rel))
}

func buildListRows(images []meta.Image) []listRow {
	out := make([]listRow, 0, len(images)+8)
	prev := ""
	for i, img := range images {
		g := groupDir(img.RelPath)
		if g != prev {
			out = append(out, listRow{kind: listHeader, dir: g})
			prev = g
		}
		out = append(out, listRow{kind: listFile, imgIdx: i})
	}
	return out
}

func visualIndex(rows []listRow, imgIdx int) int {
	for i, r := range rows {
		if r.kind == listFile && r.imgIdx == imgIdx {
			return i
		}
	}
	return 0
}
