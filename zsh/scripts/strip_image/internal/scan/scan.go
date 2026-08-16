package scan

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var imageExts = map[string]struct{}{
	".jpg": {}, ".jpeg": {}, ".png": {}, ".gif": {}, ".webp": {},
	".tif": {}, ".tiff": {}, ".bmp": {}, ".heic": {}, ".heif": {},
	".avif": {}, ".jxl": {}, ".dng": {}, ".cr2": {}, ".cr3": {},
	".nef": {}, ".arw": {}, ".orf": {}, ".rw2": {}, ".raf": {},
	".srw": {}, ".raw": {}, ".ico": {},
}

type Result struct {
	Paths  []string
	Errors []error
}

func Images(root string) Result {
	var r Result
	ig := newIgnorer(root)
	_ = filepath.WalkDir(ig.root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			r.Errors = append(r.Errors, err)
			return nil
		}
		if d.IsDir() {
			if ig.ignored(path, true) {
				return filepath.SkipDir
			}
			if path != ig.root {
				ig.addGitignore(path)
			}
			return nil
		}
		if ig.ignored(path, false) {
			return nil
		}
		ok, err := isImage(path)
		if err != nil {
			r.Errors = append(r.Errors, err)
			return nil
		}
		if ok {
			r.Paths = append(r.Paths, path)
		}
		return nil
	})
	return r
}

func isImage(path string) (bool, error) {
	ext := strings.ToLower(filepath.Ext(path))
	if _, ok := imageExts[ext]; ok {
		return true, nil
	}
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	buf := make([]byte, 512)
	n, err := io.ReadFull(f, buf)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false, err
	}
	ct := http.DetectContentType(buf[:n])
	return strings.HasPrefix(ct, "image/"), nil
}
