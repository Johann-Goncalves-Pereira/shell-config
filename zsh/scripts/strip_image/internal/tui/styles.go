package tui

import (
	"charm.land/lipgloss/v2"
)

type styles struct {
	title    lipgloss.Style
	muted    lipgloss.Style
	accent   lipgloss.Style
	ok       lipgloss.Style
	warn     lipgloss.Style
	cursor   lipgloss.Style
	row      lipgloss.Style
	path     lipgloss.Style
	summary  lipgloss.Style
	rawKey   lipgloss.Style
	rawVal   lipgloss.Style
	section  lipgloss.Style
	frame    lipgloss.Style
	listPane lipgloss.Style
	sidePane lipgloss.Style
	help     lipgloss.Style
	heading  lipgloss.Style
	checkOn  lipgloss.Style
	checkOff lipgloss.Style
	badge    lipgloss.Style
	rawHead  lipgloss.Style
	pill     map[string]lipgloss.Style
}

func newStyles(isDark bool) styles {
	ld := lipgloss.LightDark(isDark)
	fg := ld(lipgloss.Color("#1a1b26"), lipgloss.Color("#c0caf5"))
	muted := ld(lipgloss.Color("#61708b"), lipgloss.Color("#565f89"))
	accent := ld(lipgloss.Color("#0066aa"), lipgloss.Color("#7dcfff"))
	ok := ld(lipgloss.Color("#1a7f4c"), lipgloss.Color("#9ece6a"))
	warn := ld(lipgloss.Color("#b15c00"), lipgloss.Color("#e0af68"))
	selBg := ld(lipgloss.Color("#d4e5ff"), lipgloss.Color("#3d59a1"))
	border := ld(lipgloss.Color("#9aa5ce"), lipgloss.Color("#414868"))
	sumBg := ld(lipgloss.Color("#eef3ff"), lipgloss.Color("#24283b"))

	s := styles{
		title:  lipgloss.NewStyle().Bold(true).Foreground(accent),
		muted:  lipgloss.NewStyle().Foreground(muted),
		accent: lipgloss.NewStyle().Foreground(accent),
		ok:     lipgloss.NewStyle().Foreground(ok),
		warn:   lipgloss.NewStyle().Foreground(warn),
		cursor: lipgloss.NewStyle().Bold(true).Foreground(fg).Background(selBg),
		row:    lipgloss.NewStyle().Foreground(fg),
		path:   lipgloss.NewStyle().Bold(true).Foreground(accent),
		summary: lipgloss.NewStyle().
			Foreground(fg).
			Background(sumBg).
			Padding(1, 1).
			MarginBottom(1),
		rawKey:  lipgloss.NewStyle().Foreground(muted),
		rawVal:  lipgloss.NewStyle().Foreground(fg),
		section: lipgloss.NewStyle().Bold(true).Foreground(accent).MarginTop(1),
		frame:   lipgloss.NewStyle().Padding(1, 2),
		listPane: lipgloss.NewStyle().
			PaddingRight(2),
		sidePane: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(border).
			Padding(1, 2),
		help: lipgloss.NewStyle().Foreground(muted).MarginTop(1),
		heading: lipgloss.NewStyle().
			Bold(true).
			Foreground(accent).
			BorderBottom(true).
			BorderForeground(border).
			MarginTop(1),
		checkOn: lipgloss.NewStyle().
			Bold(true).
			Foreground(ld(lipgloss.Color("#f7f9ff"), lipgloss.Color("#1a1b26"))).
			Background(ok).
			Width(3).
			Align(lipgloss.Center),
		checkOff: lipgloss.NewStyle().
			Bold(true).
			Foreground(muted).
			Width(3).
			Align(lipgloss.Center),
		badge:   lipgloss.NewStyle().Bold(true).Width(4).Align(lipgloss.Left),
		rawHead: lipgloss.NewStyle().Bold(true).Foreground(fg).Underline(true).MarginTop(1).MarginBottom(1),
		pill:    map[string]lipgloss.Style{},
	}
	catColors := map[string]string{
		"Camera":      "#bb9af7",
		"Exposure":    "#e0af68",
		"GPS":         "#7aa2f7",
		"Time":        "#7dcfff",
		"Description": "#9ece6a",
		"Copyright":   "#f7768e",
		"Software":    "#73daca",
		"AI/C2PA":     "#ff9e64",
		"File":        "#c0caf5",
		"Other":       "#a9b1d6",
	}
	for name, hex := range catColors {
		s.pill[name] = lipgloss.NewStyle().Foreground(lipgloss.Color(hex))
	}
	return s
}
