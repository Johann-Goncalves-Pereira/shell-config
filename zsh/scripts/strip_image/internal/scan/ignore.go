package scan

import (
	"os"
	"path/filepath"
	"strings"

	ignore "github.com/sabhiram/go-gitignore"
)

type matcher struct {
	base string
	gi   *ignore.GitIgnore
}

type ignorer struct {
	root     string
	matchers []matcher
}

func newIgnorer(root string) *ignorer {
	abs, err := filepath.Abs(root)
	if err != nil {
		abs = root
	}
	ig := &ignorer{root: abs}
	start := gitWorkTree(abs)
	if start == "" {
		start = abs
	}
	// Parent gitignores first (repo root → scan root), then nested ones during walk.
	for _, dir := range dirsFromTo(start, abs) {
		ig.addGitignore(dir)
	}
	return ig
}

func (ig *ignorer) addGitignore(dir string) {
	p := filepath.Join(dir, ".gitignore")
	if _, err := os.Stat(p); err != nil {
		return
	}
	gi, err := ignore.CompileIgnoreFile(p)
	if err != nil || gi == nil {
		return
	}
	ig.matchers = append(ig.matchers, matcher{base: dir, gi: gi})
}

func (ig *ignorer) ignored(path string, isDir bool) bool {
	base := filepath.Base(path)
	if base == ".git" && isDir {
		return true
	}
	if path == ig.root {
		return false
	}
	for _, m := range ig.matchers {
		rel, err := filepath.Rel(m.base, path)
		if err != nil || strings.HasPrefix(rel, "..") {
			continue
		}
		rel = filepath.ToSlash(rel)
		if rel == "." {
			continue
		}
		if m.gi.MatchesPath(rel) {
			return true
		}
		// Directory patterns like "node_modules/" also match the dir itself.
		if isDir && m.gi.MatchesPath(rel+"/") {
			return true
		}
	}
	return false
}

func gitWorkTree(abs string) string {
	d := abs
	for {
		info, err := os.Stat(filepath.Join(d, ".git"))
		if err == nil && info.IsDir() {
			return d
		}
		parent := filepath.Dir(d)
		if parent == d {
			return ""
		}
		d = parent
	}
}

func dirsFromTo(from, to string) []string {
	rel, err := filepath.Rel(from, to)
	if err != nil || strings.HasPrefix(rel, "..") {
		return []string{to}
	}
	parts := strings.Split(rel, string(filepath.Separator))
	out := []string{from}
	cur := from
	for _, p := range parts {
		if p == "." || p == "" {
			continue
		}
		cur = filepath.Join(cur, p)
		out = append(out, cur)
	}
	return out
}
