package strip

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAllManyInvokesExiftool(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "exiftool")
	log := filepath.Join(dir, "args.log")
	script := "#!/bin/sh\necho \"$@\" > " + log + "\n"
	if err := os.WriteFile(stub, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)

	img := filepath.Join(dir, "a.jpg")
	if err := AllMany([]string{img}); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	got := strings.TrimSpace(string(b))
	if !strings.Contains(got, "-all=") || !strings.Contains(got, "-overwrite_original") || !strings.Contains(got, img) {
		t.Fatalf("unexpected args: %q", got)
	}
}

func TestAllManyEmpty(t *testing.T) {
	if err := AllMany(nil); err != nil {
		t.Fatal(err)
	}
}
