package strip

import (
	"bytes"
	"regexp"
)

var (
	reSVGMetadata   = regexp.MustCompile(`(?is)\s*<metadata\b[^>]*>.*?</metadata\s*>`)
	reSVGRDF        = regexp.MustCompile(`(?is)\s*<(?:[\w.-]+:)?RDF\b[^>]*>.*?</(?:[\w.-]+:)?RDF\s*>`)
	reSVGXPacket    = regexp.MustCompile(`(?is)\s*<\?xpacket\b[^>]*\?>`)
	reSVGGenComment = regexp.MustCompile(`(?is)\s*<!--\s*(?:Generator|Created with|Inkscape)[^>]*-->`)
)

func stripSVG(b []byte) []byte {
	out := reSVGMetadata.ReplaceAll(b, nil)
	out = reSVGRDF.ReplaceAll(out, nil)
	out = reSVGXPacket.ReplaceAll(out, nil)
	out = reSVGGenComment.ReplaceAll(out, nil)
	out = bytes.ReplaceAll(out, []byte("\r\n\r\n\r\n"), []byte("\r\n\r\n"))
	out = bytes.ReplaceAll(out, []byte("\n\n\n"), []byte("\n\n"))
	return out
}
