package main

import (
	"fmt"
	"os"

	tea "charm.land/bubbletea/v2"

	"strip_image/internal/meta"
	"strip_image/internal/tui"
)

func main() {
	if err := meta.RequireExifTool(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	root, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	p := tea.NewProgram(tui.New(root))
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}
