package strip

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// All removes every ExifTool-managed metadata tag from path in place.
// Category-selective stripping is intentionally not implemented yet.
func All(path string) error {
	return AllMany([]string{path})
}

func AllMany(paths []string) error {
	if len(paths) == 0 {
		return nil
	}
	args := []string{"-all=", "-overwrite_original", "--"}
	args = append(args, paths...)
	cmd := exec.Command("exiftool", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("exiftool strip: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return nil
}
