package strip

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ErrWriteUnsupported means the file can be inspected but ExifTool cannot rewrite it.
var ErrWriteUnsupported = fmt.Errorf("exiftool cannot write this format")

// All removes every ExifTool-managed metadata tag from path in place.
// SVG is stripped in-process: ExifTool cannot write SVG.
// Category-selective stripping is intentionally not implemented yet.
func All(path string) error {
	return AllMany([]string{path})
}

func AllMany(paths []string) error {
	var rest []string
	for _, p := range paths {
		if isSVG(p) {
			if err := svgFile(p); err != nil {
				return err
			}
			continue
		}
		rest = append(rest, p)
	}
	if len(rest) == 0 {
		return nil
	}
	return exiftoolStrip(rest)
}

func isSVG(path string) bool {
	return strings.EqualFold(filepath.Ext(path), ".svg")
}

func exiftoolStrip(paths []string) error {
	args := []string{"-all=", "-overwrite_original", "--"}
	args = append(args, paths...)
	cmd := exec.Command("exiftool", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Run()
	msg := strings.TrimSpace(stderr.String())
	if err != nil {
		if strings.Contains(msg, "does not yet support writing") {
			return fmt.Errorf("%w: %s", ErrWriteUnsupported, msg)
		}
		return fmt.Errorf("exiftool strip: %w: %s", err, msg)
	}
	return nil
}

func svgFile(path string) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("svg strip: %w", err)
	}
	out := stripSVG(b)
	if bytes.Equal(out, b) {
		return nil
	}
	mode := os.FileMode(0o644)
	if fi, err := os.Stat(path); err == nil {
		mode = fi.Mode().Perm()
	}
	if err := os.WriteFile(path, out, mode); err != nil {
		return fmt.Errorf("svg strip: %w", err)
	}
	return nil
}
