package scan

import "testing"

func TestHasImageExt(t *testing.T) {
	tests := []struct {
		path string
		want bool
	}{
		{"shot.JPG", true},
		{"a.svg", true},
		{"doc.pdf", true},
		{"x.psd", true},
		{"n.nef", true},
		{"h.3fr", true},
		{"notes.txt", false},
		{"app.go", false},
	}
	for _, tt := range tests {
		if got := hasImageExt(tt.path); got != tt.want {
			t.Errorf("hasImageExt(%q)=%v want %v", tt.path, got, tt.want)
		}
	}
}
