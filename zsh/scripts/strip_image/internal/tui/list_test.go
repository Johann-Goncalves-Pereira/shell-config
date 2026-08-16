package tui

import (
	"testing"

	"strip_image/internal/meta"
)

func TestGroupDir(t *testing.T) {
	tests := []struct {
		rel  string
		dir  string
		leaf string
	}{
		{"pic.jpg", ".", "pic.jpg"},
		{"web/public/assets/profile/a.jpg", "web/public/assets/profile", "a.jpg"},
		{"mobile/assets/images/x.png", "mobile/assets/images", "x.png"},
		{"public//shi-logo.svg", "public", "shi-logo.svg"},
	}
	for _, tt := range tests {
		if got := groupDir(tt.rel); got != tt.dir {
			t.Errorf("groupDir(%q)=%q want %q", tt.rel, got, tt.dir)
		}
		if got := groupLeaf(tt.rel); got != tt.leaf {
			t.Errorf("groupLeaf(%q)=%q want %q", tt.rel, got, tt.leaf)
		}
	}
}

func TestBuildListRows(t *testing.T) {
	rows := buildListRows([]meta.Image{
		{RelPath: "web/public/a.png"},
		{RelPath: "web/public/b.jpg"},
		{RelPath: "mobile/x.gif"},
	})
	if len(rows) != 5 {
		t.Fatalf("len=%d want 5 %#v", len(rows), rows)
	}
	if rows[0].kind != listHeader || rows[0].dir != "web/public" {
		t.Fatalf("first header: %+v", rows[0])
	}
	if rows[1].imgIdx != 0 || rows[2].imgIdx != 1 {
		t.Fatalf("file idxs %+v %+v", rows[1], rows[2])
	}
	if rows[3].dir != "mobile" {
		t.Fatalf("second header %+v", rows[3])
	}
}

func TestVisualIndex(t *testing.T) {
	rows := buildListRows([]meta.Image{
		{RelPath: "a/one.png"},
		{RelPath: "a/two.png"},
	})
	if visualIndex(rows, 1) != 2 {
		t.Fatalf("visualIndex=%d want 2", visualIndex(rows, 1))
	}
}
