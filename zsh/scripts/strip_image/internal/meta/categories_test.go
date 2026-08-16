package meta

import (
	"strings"
	"testing"
)

func TestCategoryFor(t *testing.T) {
	tests := []struct {
		group, tag, want string
	}{
		{"EXIF", "Make", CatCamera},
		{"EXIF", "FNumber", CatExposure},
		{"GPS", "GPSLatitude", CatGeo},
		{"EXIF", "DateTimeOriginal", CatTime},
		{"IPTC", "Headline", CatDesc},
		{"XMP", "Creator", CatCopyright},
		{"EXIF", "Software", CatSoftware},
		{"XMP", "AIPrompt", CatAI},
		{"C2PA", "Claim_generator", CatAI},
		{"EXIF", "UnknownWidget", "EXIF"},
		{"PNG", "BitDepth", CatTime},
		{"Composite", "Megapixels", CatTime},
	}
	for _, tt := range tests {
		t.Run(tt.group+":"+tt.tag, func(t *testing.T) {
			got := categoryFor(tt.group, tt.tag)
			if got != tt.want {
				t.Errorf("categoryFor(%q,%q)=%q want %q", tt.group, tt.tag, got, tt.want)
			}
		})
	}
}

func TestPresentTags(t *testing.T) {
	img := Image{
		Categories: map[string][]Field{
			CatTime: {
				{Name: "PNG: ImageWidth", Value: "1"},
				{Name: "PNG: BitDepth", Value: "8"},
			},
			CatFileSystem: {
				{Name: "File Name", Value: "a.png"},
			},
		},
	}
	got := strings.Join(img.PresentTags(), ",")
	if !strings.Contains(got, "ImageWidth") || !strings.Contains(got, "BitDepth") || !strings.Contains(got, "File Name") {
		t.Fatalf("PresentTags=%q", got)
	}
	for _, c := range img.PresentCategories() {
		if c == "Other" {
			t.Fatal("PresentCategories should not include Other")
		}
	}
}

func TestFormatValue(t *testing.T) {
	if formatValue("") != "" {
		t.Fatal("empty string should skip")
	}
	if formatValue(1.5) != "1.5" {
		t.Fatalf("got %q", formatValue(1.5))
	}
}
