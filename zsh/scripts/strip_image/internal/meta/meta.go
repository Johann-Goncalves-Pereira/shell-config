package meta

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Field struct {
	Name  string
	Value string
}

type Image struct {
	Path       string
	RelPath    string
	Size       int64
	MIME       string
	Selected   bool
	Categories map[string][]Field
	InspectErr error
}

func (img Image) PresentCategories() []string {
	order := []string{CatCamera, CatExposure, CatGeo, CatTime, CatDesc, CatCopyright, CatSoftware, CatAI, CatFileSystem}
	var out []string
	seen := map[string]struct{}{}
	for _, c := range order {
		if len(img.Categories[c]) > 0 {
			out = append(out, shortCat(c))
			seen[c] = struct{}{}
		}
	}
	var extra []string
	for c, fields := range img.Categories {
		if len(fields) == 0 {
			continue
		}
		if _, ok := seen[c]; ok {
			continue
		}
		if c == CatOther {
			continue
		}
		extra = append(extra, c)
	}
	sort.Strings(extra)
	return append(out, extra...)
}

// PresentTags lists every present field's short tag name (no Other bucket).
func (img Image) PresentTags() []string {
	var names []string
	seen := map[string]struct{}{}
	for _, f := range img.allFields() {
		n := shortTag(f.Name)
		if n == "" {
			continue
		}
		if _, ok := seen[n]; ok {
			continue
		}
		seen[n] = struct{}{}
		names = append(names, n)
	}
	return names
}

func (img Image) allFields() []Field {
	order := []string{CatCamera, CatExposure, CatGeo, CatTime, CatDesc, CatCopyright, CatSoftware, CatAI, CatFileSystem}
	var out []Field
	seen := map[string]struct{}{}
	for _, c := range order {
		seen[c] = struct{}{}
		out = append(out, img.Categories[c]...)
	}
	var extra []string
	for c := range img.Categories {
		if _, ok := seen[c]; ok {
			continue
		}
		if c == CatOther {
			continue
		}
		extra = append(extra, c)
	}
	sort.Strings(extra)
	for _, c := range extra {
		out = append(out, img.Categories[c]...)
	}
	if fields := img.Categories[CatOther]; len(fields) > 0 {
		out = append(out, fields...)
	}
	return out
}

func shortTag(name string) string {
	if _, tag, ok := strings.Cut(name, ": "); ok {
		return tag
	}
	return name
}

func shortCat(c string) string {
	switch c {
	case CatCamera:
		return "Camera"
	case CatExposure:
		return "Exposure"
	case CatGeo:
		return "GPS"
	case CatTime:
		return "Time"
	case CatDesc:
		return "Description"
	case CatCopyright:
		return "Copyright"
	case CatSoftware:
		return "Software"
	case CatAI:
		return "AI/C2PA"
	case CatFileSystem:
		return "File"
	default:
		return c
	}
}

func RequireExifTool() error {
	if _, err := exec.LookPath("exiftool"); err != nil {
		return fmt.Errorf("exiftool is required on PATH: %w", err)
	}
	return nil
}

func Inspect(root string, paths []string) ([]Image, error) {
	byPath := make(map[string]map[string]any, len(paths))
	const batch = 32
	for i := 0; i < len(paths); i += batch {
		end := i + batch
		if end > len(paths) {
			end = len(paths)
		}
		chunk, err := exiftoolJSON(paths[i:end])
		if err != nil {
			return nil, err
		}
		for _, rec := range chunk {
			sf, _ := rec["SourceFile"].(string)
			byPath[sf] = rec
			if abs, err := filepath.Abs(sf); err == nil {
				byPath[abs] = rec
			}
		}
	}

	out := make([]Image, 0, len(paths))
	for _, p := range paths {
		img := inspectOne(root, p, byPath)
		out = append(out, img)
	}
	return out, nil
}

func inspectOne(root, path string, byPath map[string]map[string]any) Image {
	img := Image{Path: path, Selected: true, Categories: map[string][]Field{}}
	rel, err := filepath.Rel(root, path)
	if err != nil {
		rel = path
	}
	img.RelPath = rel

	fi, err := os.Stat(path)
	if err != nil {
		img.InspectErr = err
		return img
	}
	img.Size = fi.Size()
	img.MIME = sniffMIME(path)
	addFS(img.Categories, fi, path, img.MIME)

	rec := lookup(byPath, path)
	if rec == nil {
		return img
	}
	if em, ok := rec["Error"].(string); ok && em != "" {
		img.InspectErr = fmt.Errorf("%s", em)
	}
	for k, v := range rec {
		if k == "SourceFile" || k == "Error" {
			continue
		}
		group, tag := splitGroup(k)
		if _, skip := skipTags[strings.ToLower(tag)]; skip {
			continue
		}
		val := formatValue(v)
		if val == "" {
			continue
		}
		cat := categoryFor(group, tag)
		img.Categories[cat] = append(img.Categories[cat], Field{Name: displayName(group, tag), Value: val})
	}
	for cat, fields := range img.Categories {
		sort.Slice(fields, func(i, j int) bool { return fields[i].Name < fields[j].Name })
		img.Categories[cat] = fields
	}
	return img
}

func lookup(byPath map[string]map[string]any, path string) map[string]any {
	if rec, ok := byPath[path]; ok {
		return rec
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return nil
	}
	return byPath[abs]
}

func exiftoolJSON(paths []string) ([]map[string]any, error) {
	args := []string{"-json", "-G", "-n", "-struct", "--"}
	args = append(args, paths...)
	cmd := exec.Command("exiftool", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil && stdout.Len() == 0 {
		return nil, fmt.Errorf("exiftool: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	var recs []map[string]any
	if err := json.Unmarshal(stdout.Bytes(), &recs); err != nil {
		return nil, fmt.Errorf("exiftool json: %w", err)
	}
	return recs, nil
}

func splitGroup(key string) (group, tag string) {
	group, tag, ok := strings.Cut(key, ":")
	if !ok {
		return "", key
	}
	return group, tag
}

func displayName(group, tag string) string {
	if group == "" {
		return tag
	}
	return group + ": " + tag
}

func formatValue(v any) string {
	switch t := v.(type) {
	case nil:
		return ""
	case string:
		return strings.TrimSpace(t)
	case float64:
		return strconv.FormatFloat(t, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(t)
	default:
		b, err := json.Marshal(t)
		if err != nil {
			return fmt.Sprint(t)
		}
		s := string(b)
		if len(s) > 240 {
			s = s[:237] + "..."
		}
		return s
	}
}

func sniffMIME(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return "application/octet-stream"
	}
	defer f.Close()
	buf := make([]byte, 512)
	n, _ := f.Read(buf)
	return http.DetectContentType(buf[:n])
}

func addFS(cats map[string][]Field, fi os.FileInfo, path, mime string) {
	mode := fi.Mode().String()
	fields := []Field{
		{Name: "File Name", Value: filepath.Base(path)},
		{Name: "File Size", Value: strconv.FormatInt(fi.Size(), 10) + " bytes"},
		{Name: "MIME Type / File Format", Value: mime},
		{Name: "File Modified Date", Value: fi.ModTime().Format(time.RFC3339)},
		{Name: "File Access Permissions", Value: mode},
	}
	if b := birthTime(fi); !b.IsZero() {
		fields = append(fields, Field{Name: "File Creation Date", Value: b.Format(time.RFC3339)})
	}
	cats[CatFileSystem] = fields
}
