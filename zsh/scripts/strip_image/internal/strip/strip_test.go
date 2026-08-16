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

func TestStripSVGRemovesMetadata(t *testing.T) {
	in := []byte(`<?xml version="1.0"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <!-- Generator: Adobe Illustrator -->
  <metadata>
    <rdf:RDF><rdf:Description><dc:title>secret</dc:title></rdf:Description></rdf:RDF>
  </metadata>
  <path d="M0 0h10v10H0z"/>
</svg>
`)
	got := string(stripSVG(in))
	if strings.Contains(got, "<metadata") || strings.Contains(got, "rdf:RDF") || strings.Contains(got, "Generator:") {
		t.Fatalf("metadata remained:\n%s", got)
	}
	if !strings.Contains(got, `<path d="M0 0h10v10H0z"/>`) {
		t.Fatalf("graphic missing:\n%s", got)
	}
}

func TestAllSVGDoesNotCallExiftool(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "exiftool")
	if err := os.WriteFile(stub, []byte("#!/bin/sh\necho called > "+filepath.Join(dir, "called")+"\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	svg := filepath.Join(dir, "logo.svg")
	src := []byte(`<svg xmlns="http://www.w3.org/2000/svg"><metadata>x</metadata><circle r="1"/></svg>`)
	if err := os.WriteFile(svg, src, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := All(svg); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "called")); err == nil {
		t.Fatal("exiftool should not run for svg")
	}
	out, err := os.ReadFile(svg)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(out), "<metadata") {
		t.Fatalf("still has metadata: %s", out)
	}
}

func TestExiftoolUnsupportedWrite(t *testing.T) {
	dir := t.TempDir()
	stub := filepath.Join(dir, "exiftool")
	script := "#!/bin/sh\necho 'Error: ExifTool does not yet support writing of FIG images -' >&2\nexit 1\n"
	if err := os.WriteFile(stub, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
	err := All(filepath.Join(dir, "a.fig"))
	if err == nil || !strings.Contains(err.Error(), "cannot write") {
		t.Fatalf("got %v, want write-unsupported", err)
	}
}
