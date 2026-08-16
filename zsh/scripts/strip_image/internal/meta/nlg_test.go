package meta

import (
	"strings"
	"testing"
)

func TestSummarize(t *testing.T) {
	tests := []struct {
		name string
		img  Image
		want []string
	}{
		{
			name: "jpeg dimensions size",
			img: Image{
				RelPath: "web/public/Anne-waterpaint.jpg",
				Size:    183603,
				MIME:    "image/jpeg",
				Categories: map[string][]Field{
					CatTime: {
						{Name: "EXIF: ImageWidth", Value: "765"},
						{Name: "EXIF: ImageHeight", Value: "1024"},
					},
					CatFileSystem: {
						{Name: "File Name", Value: "Anne-waterpaint.jpg"},
						{Name: "File Size", Value: "183603 bytes"},
					},
					CatOther: {
						{Name: "Composite: Megapixels", Value: "0.78336"},
					},
				},
			},
			want: []string{
				"Anne-waterpaint.jpg is a JPEG 765x1024 picture (179 KB, 0.78 MP).",
				"Embedded tags here are mostly technical",
			},
		},
		{
			name: "png color bits",
			img: Image{
				RelPath: "splash-icon.png",
				Size:    3317,
				MIME:    "image/png",
				Categories: map[string][]Field{
					CatTime: {
						{Name: "PNG: ImageWidth", Value: "228"},
						{Name: "PNG: ImageHeight", Value: "213"},
					},
					CatOther: {
						{Name: "PNG: BitDepth", Value: "8"},
						{Name: "PNG: ColorType", Value: "6"},
						{Name: "PNG: Interlace", Value: "0"},
					},
				},
			},
			want: []string{
				"splash-icon.png is a PNG 228x213 picture (3 KB).",
				"Color is 8-bit and RGBA, not interlaced.",
			},
		},
		{
			name: "camera gps copyright",
			img: Image{
				RelPath: "shot.nef",
				Size:    2 * 1024 * 1024,
				MIME:    "image/tiff",
				Categories: map[string][]Field{
					CatCamera: {
						{Name: "EXIF: Make", Value: "Nikon"},
						{Name: "EXIF: Model", Value: "Z6"},
					},
					CatExposure: {
						{Name: "EXIF: ISO", Value: "200"},
						{Name: "EXIF: FNumber", Value: "2.8"},
					},
					CatGeo: {
						{Name: "GPS: GPSLatitude", Value: "37.7"},
						{Name: "GPS: GPSLongitude", Value: "-122.4"},
					},
					CatCopyright: {
						{Name: "EXIF: Artist", Value: "Ada"},
					},
					CatTime: {
						{Name: "EXIF: DateTimeOriginal", Value: "2024:01:02 15:04:05"},
					},
				},
			},
			want: []string{
				"shot.nef is a TIFF",
				"captured with a Nikon Z6",
				"ISO 200",
				"aperture f/2.8",
				"original capture time is 2024:01:02 15:04:05",
				"GPS coordinates are embedded",
				"credited creator is Ada",
				"camera, exposure, gps, and copyright",
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Summarize(tt.img)
			for _, frag := range tt.want {
				if !strings.Contains(got, frag) {
					t.Errorf("Summarize missing %q\ngot: %s", frag, got)
				}
			}
		})
	}
}

func TestHumanSize(t *testing.T) {
	tests := []struct {
		n    int64
		want string
	}{
		{0, ""},
		{500, "500 bytes"},
		{183603, "179 KB"},
		{2 * 1024 * 1024, "2.0 MB"},
	}
	for _, tt := range tests {
		if got := HumanSize(tt.n); got != tt.want {
			t.Errorf("HumanSize(%d)=%q want %q", tt.n, got, tt.want)
		}
	}
}

func TestJoinAnd(t *testing.T) {
	tests := []struct {
		in   []string
		want string
	}{
		{nil, ""},
		{[]string{"a"}, "a"},
		{[]string{"a", "b"}, "a and b"},
		{[]string{"a", "b", "c"}, "a, b, and c"},
	}
	for _, tt := range tests {
		if got := joinAnd(tt.in); got != tt.want {
			t.Errorf("joinAnd(%v)=%q want %q", tt.in, got, tt.want)
		}
	}
}
