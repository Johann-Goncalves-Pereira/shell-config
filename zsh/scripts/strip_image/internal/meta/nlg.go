package meta

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
)

// Summarize builds a short rule-based (template) description of an image
// from present metadata. It is deterministic: no ML, no randomness.
func Summarize(img Image) string {
	fields := indexFields(img)
	var sentences []string

	sentences = append(sentences, openSentence(img, fields))
	if s := rasterSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := captureSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := exposureSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := whenSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := geoSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := peopleSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := softwareSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if s := aiSentence(fields); s != "" {
		sentences = append(sentences, s)
	}
	if img.InspectErr != nil {
		sentences = append(sentences, fmt.Sprintf("Inspect reported: %v.", img.InspectErr))
	} else {
		sentences = append(sentences, stripHint(img))
	}
	return strings.Join(sentences, " ")
}

func indexFields(img Image) map[string]string {
	out := make(map[string]string)
	for _, fields := range img.Categories {
		for _, f := range fields {
			key := normalizeTag(f.Name)
			if key == "" || f.Value == "" {
				continue
			}
			if _, ok := out[key]; !ok {
				out[key] = f.Value
			}
			if _, tag, cut := strings.Cut(f.Name, ": "); cut {
				t := normalizeTag(tag)
				if _, ok := out[t]; !ok {
					out[t] = f.Value
				}
			}
		}
	}
	return out
}

func normalizeTag(name string) string {
	s := strings.ToLower(strings.TrimSpace(name))
	s = strings.ReplaceAll(s, " ", "")
	s = strings.ReplaceAll(s, "-", "")
	s = strings.ReplaceAll(s, "_", "")
	s = strings.ReplaceAll(s, "/", "")
	return s
}

func field(m map[string]string, keys ...string) string {
	for _, k := range keys {
		if v := m[normalizeTag(k)]; v != "" {
			return v
		}
	}
	return ""
}

func openSentence(img Image, fields map[string]string) string {
	name := filepath.Base(img.RelPath)
	if name == "" || name == "." {
		name = filepath.Base(img.Path)
	}
	kind := formatKind(img.MIME, name)
	w := firstNumber(fields, "imagewidth", "exifimagewidth")
	h := firstNumber(fields, "imageheight", "exifimageheight")
	size := HumanSize(img.Size)
	mp := prettyMegapixels(fields)
	var extras []string
	if size != "" {
		extras = append(extras, size)
	}
	if mp != "" {
		extras = append(extras, mp)
	}
	extra := ""
	if len(extras) > 0 {
		extra = " (" + strings.Join(extras, ", ") + ")"
	}
	switch {
	case w > 0 && h > 0:
		return fmt.Sprintf("%s is a %s %dx%d picture%s.", name, kind, w, h, extra)
	case extra != "":
		return fmt.Sprintf("%s is a %s file occupying %s.", name, kind, strings.Join(extras, ", "))
	default:
		return fmt.Sprintf("%s is a %s file.", name, kind)
	}
}

func prettyMegapixels(fields map[string]string) string {
	v := field(fields, "megapixels")
	if v == "" {
		return ""
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil || f <= 0 {
		return ""
	}
	switch {
	case f < 0.01:
		return ""
	case f < 10:
		return fmt.Sprintf("%.2f MP", f)
	default:
		return fmt.Sprintf("%.1f MP", f)
	}
}

func rasterSentence(fields map[string]string) string {
	var bits []string
	if bd := field(fields, "bitdepth", "bitspersample", "bitsperpixel"); bd != "" {
		bits = append(bits, bd+"-bit")
	}
	if ct := prettyColorType(field(fields, "colortype", "photometricinterpretation")); ct != "" {
		bits = append(bits, ct)
	}
	interlace := field(fields, "interlace")
	switch {
	case len(bits) > 0 && (interlace == "0" || strings.EqualFold(interlace, "noninterlaced")):
		return "Color is " + joinAnd(bits) + ", not interlaced."
	case len(bits) > 0 && (interlace == "1" || strings.Contains(strings.ToLower(interlace), "adam")):
		return "Color is " + joinAnd(bits) + ", with Adam7 interlacing."
	case len(bits) > 0:
		return "Color is " + joinAnd(bits) + "."
	default:
		return ""
	}
}

func prettyColorType(v string) string {
	switch strings.TrimSpace(v) {
	case "":
		return ""
	case "0":
		return "grayscale"
	case "2":
		return "RGB"
	case "3":
		return "indexed color"
	case "4":
		return "grayscale with alpha"
	case "6":
		return "RGBA"
	default:
		if strings.Contains(strings.ToLower(v), "rgb") {
			return v
		}
		return ""
	}
}

func captureSentence(fields map[string]string) string {
	make := field(fields, "make", "manufacturer")
	model := field(fields, "model")
	lens := field(fields, "lensmodel", "lensmake", "lensid")
	switch {
	case make != "" && model != "" && lens != "":
		return fmt.Sprintf("It was captured with a %s %s using a %s lens.", make, model, lens)
	case make != "" && model != "":
		return fmt.Sprintf("It was captured with a %s %s.", make, model)
	case model != "":
		return fmt.Sprintf("It was captured with a %s.", model)
	case make != "":
		return fmt.Sprintf("The camera make is recorded as %s.", make)
	default:
		return ""
	}
}

func exposureSentence(fields map[string]string) string {
	var bits []string
	if iso := field(fields, "iso", "isospeedratings"); iso != "" {
		bits = append(bits, "ISO "+iso)
	}
	if sh := field(fields, "exposuretime", "shutterspeed", "shutterspeedvalue"); sh != "" {
		bits = append(bits, "shutter "+prettyShutter(sh))
	}
	if f := field(fields, "fnumber", "aperture", "aperturevalue"); f != "" {
		bits = append(bits, "aperture f/"+strings.TrimPrefix(f, "f/"))
	}
	if fl := field(fields, "focallength"); fl != "" {
		bits = append(bits, "focal length "+prettyFocal(fl))
	}
	if len(bits) == 0 {
		return ""
	}
	return "Exposure is recorded as " + joinAnd(bits) + "."
}

func whenSentence(fields map[string]string) string {
	when := field(fields, "datetimeoriginal", "createdate")
	if when == "" {
		return ""
	}
	return "The original capture time is " + when + "."
}

func geoSentence(fields map[string]string) string {
	lat := field(fields, "gpslatitude")
	lon := field(fields, "gpslongitude")
	city := field(fields, "city", "locationcreatedcity")
	country := field(fields, "country", "locationcreatedcountryname")
	switch {
	case lat != "" && lon != "" && city != "" && country != "":
		return fmt.Sprintf("A location is embedded: %s, %s (GPS %s, %s).", city, country, lat, lon)
	case lat != "" && lon != "":
		return fmt.Sprintf("GPS coordinates are embedded (%s, %s).", lat, lon)
	case city != "" && country != "":
		return fmt.Sprintf("A place name is embedded: %s, %s.", city, country)
	case city != "":
		return fmt.Sprintf("A place name is embedded: %s.", city)
	default:
		if field(fields, "gpsaltitude", "gpsposition") != "" {
			return "Geolocation tags are present."
		}
		return ""
	}
}

func peopleSentence(fields map[string]string) string {
	creator := field(fields, "creator", "artist", "byline")
	copy := field(fields, "copyright", "copyrightnotice", "specialinstructions")
	switch {
	case creator != "" && copy != "":
		return fmt.Sprintf("Credit goes to %s; copyright reads %s.", creator, copy)
	case creator != "":
		return fmt.Sprintf("The credited creator is %s.", creator)
	case copy != "":
		return fmt.Sprintf("A copyright notice is present: %s.", copy)
	default:
		return ""
	}
}

func softwareSentence(fields map[string]string) string {
	sw := field(fields, "software")
	if sw == "" {
		return ""
	}
	return "It was last processed with " + sw + "."
}

func aiSentence(fields map[string]string) string {
	prompt := field(fields, "aiprompt", "prompt")
	model := field(fields, "aimodel")
	switch {
	case prompt != "" && model != "":
		return fmt.Sprintf("Generative metadata is present (model %s).", model)
	case prompt != "":
		return "A generative prompt is embedded in the file."
	case model != "":
		return fmt.Sprintf("An AI model tag is present (%s).", model)
	default:
		if len(fields) == 0 {
			return ""
		}
		return ""
	}
}

func stripHint(img Image) string {
	cats := img.PresentCategories()
	var extra []string
	for _, c := range cats {
		if c != "File" && c != "Time" {
			extra = append(extra, strings.ToLower(c))
		}
	}
	if len(extra) == 0 {
		return "Embedded tags here are mostly technical; stripping clears them while the file name stays."
	}
	return "Stripping removes embedded " + joinAnd(extra) + " tags; the file name and bytes on disk remain."
}

func formatKind(mime, name string) string {
	switch {
	case strings.Contains(mime, "jpeg"), strings.HasSuffix(strings.ToLower(name), ".jpg"), strings.HasSuffix(strings.ToLower(name), ".jpeg"):
		return "JPEG"
	case strings.Contains(mime, "png"), strings.HasSuffix(strings.ToLower(name), ".png"):
		return "PNG"
	case strings.Contains(mime, "webp"):
		return "WebP"
	case strings.Contains(mime, "gif"):
		return "GIF"
	case strings.Contains(mime, "tiff"):
		return "TIFF"
	case strings.Contains(mime, "svg"), strings.HasSuffix(strings.ToLower(name), ".svg"):
		return "SVG"
	case strings.Contains(mime, "pdf"), strings.HasSuffix(strings.ToLower(name), ".pdf"):
		return "PDF"
	case strings.Contains(mime, "heic"), strings.Contains(mime, "heif"):
		return "HEIC"
	case strings.HasPrefix(mime, "image/"):
		return strings.TrimPrefix(mime, "image/")
	default:
		return "image"
	}
}

func firstNumber(fields map[string]string, keys ...string) int {
	for _, k := range keys {
		v := field(fields, k)
		if v == "" {
			continue
		}
		n, err := strconv.Atoi(strings.TrimSpace(strings.Split(v, ".")[0]))
		if err == nil && n > 0 {
			return n
		}
	}
	return 0
}

func prettyShutter(v string) string {
	if strings.Contains(v, "/") {
		return v + "s"
	}
	return v + "s"
}

func prettyFocal(v string) string {
	if strings.Contains(strings.ToLower(v), "mm") {
		return v
	}
	return v + "mm"
}

func joinAnd(parts []string) string {
	switch len(parts) {
	case 0:
		return ""
	case 1:
		return parts[0]
	case 2:
		return parts[0] + " and " + parts[1]
	default:
		return strings.Join(parts[:len(parts)-1], ", ") + ", and " + parts[len(parts)-1]
	}
}

// HumanSize formats a byte count for display.
func HumanSize(n int64) string {
	if n <= 0 {
		return ""
	}
	const kb = 1024
	const mb = kb * 1024
	switch {
	case n >= mb:
		return fmt.Sprintf("%.1f MB", float64(n)/float64(mb))
	case n >= kb:
		return fmt.Sprintf("%.0f KB", float64(n)/float64(kb))
	default:
		return fmt.Sprintf("%d bytes", n)
	}
}
