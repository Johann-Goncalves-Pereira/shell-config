package tui

import (
	"image/color"
	"path/filepath"
	"strings"

	"charm.land/lipgloss/v2"

	"strip_image/internal/meta"
)

func catIcon(cat string) string {
	switch cat {
	case meta.CatCamera, "Camera":
		return "📷"
	case meta.CatExposure, "Exposure":
		return "☼"
	case meta.CatGeo, "GPS":
		return "📍"
	case meta.CatTime, "Time":
		return "◷"
	case meta.CatDesc, "Description":
		return "✎"
	case meta.CatCopyright, "Copyright":
		return "©"
	case meta.CatSoftware, "Software":
		return "⌘"
	case meta.CatAI, "AI/C2PA":
		return "✦"
	case meta.CatFileSystem, "File":
		return "📁"
	default:
		return "⋯"
	}
}

func formatLabel(path string) string {
	ext := strings.ToUpper(strings.TrimPrefix(filepath.Ext(path), "."))
	switch ext {
	case "JPEG":
		return "JPG"
	case "THREFR":
		return "3FR"
	case "":
		return "IMG"
	}
	if len(ext) > 4 {
		return ext[:4]
	}
	return ext
}

func formatBadge(path string, st styles) string {
	label := formatLabel(path)
	return st.badge.Foreground(badgeColor(label)).Render(label)
}

func badgeColor(label string) color.Color {
	switch label {
	case "JPG", "JIF", "JFIF":
		return lipgloss.Color("#e0af68")
	case "PNG":
		return lipgloss.Color("#9ece6a")
	case "GIF":
		return lipgloss.Color("#bb9af7")
	case "SVG":
		return lipgloss.Color("#7dcfff")
	case "WEBP", "AVIF", "JXL":
		return lipgloss.Color("#7aa2f7")
	case "PDF", "AI", "EPS":
		return lipgloss.Color("#f7768e")
	case "PSD", "PSB", "XCF":
		return lipgloss.Color("#ff9e64")
	case "HEIC", "HEIF":
		return lipgloss.Color("#73daca")
	default:
		return lipgloss.Color("#c0caf5")
	}
}

func fieldIcon(name string) string {
	k := strings.ToLower(strings.ReplaceAll(name, " ", ""))
	switch {
	case strings.Contains(k, "gps"), strings.Contains(k, "latitude"), strings.Contains(k, "longitude"), strings.Contains(k, "city"), strings.Contains(k, "country"):
		return "📍"
	case strings.Contains(k, "date"), strings.Contains(k, "time"):
		return "◷"
	case strings.Contains(k, "iso"), strings.Contains(k, "exposure"), strings.Contains(k, "aperture"), strings.Contains(k, "fnumber"), strings.Contains(k, "shutter"), strings.Contains(k, "focal"):
		return "☼"
	case strings.Contains(k, "make"), strings.Contains(k, "model"), strings.Contains(k, "lens"), strings.Contains(k, "camera"):
		return "📷"
	case strings.Contains(k, "copyright"), strings.Contains(k, "license"), strings.Contains(k, "artist"), strings.Contains(k, "creator"):
		return "©"
	case strings.Contains(k, "software"), strings.Contains(k, "history"), strings.Contains(k, "profile"):
		return "⌘"
	case strings.Contains(k, "prompt"), strings.Contains(k, "c2pa"), strings.Contains(k, "ai"):
		return "✦"
	case strings.Contains(k, "width"), strings.Contains(k, "height"), strings.Contains(k, "imagesize"):
		return "▭"
	case strings.Contains(k, "filesize"), strings.Contains(k, "size"):
		return "⚖"
	case strings.Contains(k, "mime"), strings.Contains(k, "format"):
		return "🏷"
	case strings.Contains(k, "permission"), strings.Contains(k, "filename"):
		return "📁"
	case strings.Contains(k, "comment"), strings.Contains(k, "title"), strings.Contains(k, "headline"), strings.Contains(k, "keyword"), strings.Contains(k, "description"):
		return "✎"
	default:
		return "•"
	}
}
