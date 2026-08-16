package scan

import (
	"path/filepath"
	"strings"
)

// imageExts is the set of files we inspect and strip (plus image/* MIME sniff).
var imageExts = map[string]struct{}{
	// Raster
	".jpg": {}, ".jpeg": {}, ".jif": {}, ".jfif": {},
	".png": {}, ".gif": {}, ".webp": {},
	".tif": {}, ".tiff": {}, ".bmp": {},
	".heic": {}, ".heif": {}, ".avif": {},
	".ico": {}, ".tga": {},
	".jp2": {}, ".j2k": {}, ".jxl": {},
	".pbm": {}, ".pgm": {}, ".ppm": {}, ".pnm": {},
	".pcx": {}, ".dds": {}, ".bpg": {},
	// Vector
	".svg": {}, ".ai": {}, ".eps": {}, ".pdf": {},
	".cdr": {}, ".wmf": {}, ".emf": {}, ".dxf": {},
	// Camera RAW
	".cr2": {}, ".cr3": {}, ".crw": {},
	".nef": {}, ".nrw": {},
	".arw": {}, ".srf": {}, ".sr2": {},
	".dng": {}, ".orf": {}, ".rw2": {}, ".raf": {},
	".pef": {}, ".ptx": {},
	".3fr": {}, ".threefr": {}, ".fff": {},
	".mrw": {}, ".mef": {}, ".mos": {}, ".srw": {}, ".x3f": {},
	".raw": {},
	// Project / software
	".psd": {}, ".psb": {}, ".xcf": {}, ".afphoto": {},
	".clip": {}, ".lip": {}, ".kra": {}, ".cpt": {},
	".sketch": {}, ".fig": {},
}

func hasImageExt(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	_, ok := imageExts[ext]
	return ok
}
