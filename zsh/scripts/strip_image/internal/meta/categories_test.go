package meta

import "testing"

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
		{"EXIF", "UnknownWidget", CatOther},
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

func TestFormatValue(t *testing.T) {
	if formatValue("") != "" {
		t.Fatal("empty string should skip")
	}
	if formatValue(1.5) != "1.5" {
		t.Fatalf("got %q", formatValue(1.5))
	}
}
