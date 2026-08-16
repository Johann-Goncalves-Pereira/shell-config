package tui

import (
	"errors"
	"fmt"
	"sort"
	"strings"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/progress"
	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"

	"strip_image/internal/meta"
	"strip_image/internal/scan"
	"strip_image/internal/strip"
)

type phase int

const (
	phaseLoad phase = iota
	phaseSelect
	phaseConfirm
	phaseStrip
	phaseDone
	phaseEmpty
	phaseErr
)

type keyMap struct {
	Up       key.Binding
	Down     key.Binding
	Toggle   key.Binding
	Continue key.Binding
	Back     key.Binding
	Quit     key.Binding
}

func (k keyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Up, k.Down, k.Toggle, k.Continue, k.Quit}
}

func (k keyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{k.ShortHelp()}
}

var keys = keyMap{
	Up:       key.NewBinding(key.WithKeys("up", "k"), key.WithHelp("↑/k", "up")),
	Down:     key.NewBinding(key.WithKeys("down", "j"), key.WithHelp("↓/j", "down")),
	Toggle:   key.NewBinding(key.WithKeys("space"), key.WithHelp("space", "toggle")),
	Continue: key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "continue")),
	Back:     key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "back")),
	Quit:     key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
}

type model struct {
	root     string
	phase    phase
	err      error
	images   []meta.Image
	scanErrs []error
	cursor   int
	offset   int
	width    int
	height   int
	spinner  spinner.Model
	progress progress.Model
	vp       viewport.Model
	help     help.Model
	stripped int
	skipped  int
	failed   int
	stripIdx int
	failMsgs []string
	skipMsgs []string
	isDark   bool
	styles   styles
}

type loadedMsg struct {
	images []meta.Image
	errs   []error
	err    error
}

type strippedMsg struct {
	err error
}

func New(root string) tea.Model {
	s := spinner.New()
	s.Spinner = spinner.Dot
	p := progress.New(progress.WithDefaultBlend())
	h := help.New()
	vp := viewport.New(viewport.WithWidth(80), viewport.WithHeight(10))
	return model{
		root:     root,
		phase:    phaseLoad,
		spinner:  s,
		progress: p,
		vp:       vp,
		help:     h,
		width:    80,
		height:   24,
		isDark:   true,
		styles:   newStyles(true),
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		func() tea.Msg { return m.spinner.Tick() },
		tea.RequestBackgroundColor,
		loadCmd(m.root),
	)
}

func loadCmd(root string) tea.Cmd {
	return func() tea.Msg {
		res := scan.Images(root)
		imgs, err := meta.Inspect(root, res.Paths)
		return loadedMsg{images: imgs, errs: res.Errors, err: err}
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.BackgroundColorMsg:
		m.isDark = msg.IsDark()
		m.styles = newStyles(m.isDark)
		m.help.Styles = help.DefaultStyles(m.isDark)
		m.refreshDetail()
		return m, nil
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.layout()
		m.refreshDetail()
		return m, nil
	case spinner.TickMsg:
		if m.phase == phaseLoad || m.phase == phaseStrip {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}
		return m, nil
	case loadedMsg:
		if msg.err != nil {
			m.phase = phaseErr
			m.err = msg.err
			return m, nil
		}
		m.images = msg.images
		m.scanErrs = msg.errs
		if len(m.images) == 0 {
			m.phase = phaseEmpty
			return m, nil
		}
		m.phase = phaseSelect
		m.layout()
		m.ensureVisible()
		m.refreshDetail()
		return m, nil
	case strippedMsg:
		if msg.err != nil {
			rel := m.images[m.stripIdx].RelPath
			if errors.Is(msg.err, strip.ErrWriteUnsupported) {
				m.skipped++
				m.skipMsgs = append(m.skipMsgs, fmt.Sprintf("%s: cannot rewrite this format", rel))
			} else {
				m.failed++
				m.failMsgs = append(m.failMsgs, fmt.Sprintf("%s: %v", rel, msg.err))
			}
		} else {
			m.stripped++
		}
		return m, m.nextStrip()
	case tea.KeyPressMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m model) handleKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	if key.Matches(msg, keys.Quit) {
		return m, tea.Quit
	}
	switch m.phase {
	case phaseSelect:
		switch {
		case key.Matches(msg, keys.Up):
			if m.cursor > 0 {
				m.cursor--
			}
			m.ensureVisible()
			m.refreshDetail()
		case key.Matches(msg, keys.Down):
			if m.cursor < len(m.images)-1 {
				m.cursor++
			}
			m.ensureVisible()
			m.refreshDetail()
		case key.Matches(msg, keys.Toggle):
			m.images[m.cursor].Selected = !m.images[m.cursor].Selected
		case key.Matches(msg, keys.Continue):
			if m.selectedCount() == 0 {
				return m, nil
			}
			m.phase = phaseConfirm
		}
	case phaseConfirm:
		switch {
		case key.Matches(msg, keys.Back):
			m.phase = phaseSelect
		case key.Matches(msg, keys.Continue):
			m.phase = phaseStrip
			m.stripIdx = -1
			m.skipped = len(m.images) - m.selectedCount()
			return m, tea.Batch(func() tea.Msg { return m.spinner.Tick() }, m.nextStrip())
		}
	case phaseDone, phaseEmpty, phaseErr:
		if key.Matches(msg, keys.Continue) {
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m *model) nextStrip() tea.Cmd {
	for i := m.stripIdx + 1; i < len(m.images); i++ {
		if !m.images[i].Selected {
			continue
		}
		m.stripIdx = i
		path := m.images[i].Path
		return func() tea.Msg {
			return strippedMsg{err: strip.All(path)}
		}
	}
	m.phase = phaseDone
	return nil
}

func (m model) selectedCount() int {
	n := 0
	for _, img := range m.images {
		if img.Selected {
			n++
		}
	}
	return n
}

const (
	framePadX       = 2
	framePadY       = 1
	minSidebarOuter = 108
	chromeLines     = 6
)

func (m model) innerWidth() int {
	w := m.width - framePadX*2
	if w < 20 {
		return 20
	}
	return w
}

func (m model) innerHeight() int {
	h := m.height - framePadY*2
	if h < 8 {
		return 8
	}
	return h
}

func (m model) useSidebar() bool {
	return m.innerWidth() >= minSidebarOuter
}

func (m model) sidebarWidth() int {
	iw := m.innerWidth()
	w := iw * 38 / 100
	if w < 36 {
		w = 36
	}
	if w > 52 {
		w = 52
	}
	if w > iw-32 {
		w = iw - 32
	}
	return w
}

func (m model) listColWidth() int {
	if !m.useSidebar() {
		return m.innerWidth()
	}
	return max(24, m.innerWidth()-m.sidebarWidth()-2)
}

func (m *model) layout() {
	iw := m.innerWidth()
	m.progress.SetWidth(max(20, iw-4))
	m.help.SetWidth(iw)
	bodyH := m.listHeight()
	if m.useSidebar() {
		sw := m.sidebarWidth()
		m.vp.SetWidth(max(18, sw-8))
		m.vp.SetHeight(max(6, bodyH-2))
		return
	}
	detailH := max(8, m.innerHeight()*40/100)
	m.vp.SetWidth(max(20, iw-4))
	m.vp.SetHeight(max(6, detailH-2))
}

func (m *model) listHeight() int {
	h := m.innerHeight() - chromeLines
	if m.useSidebar() {
		if h < 5 {
			return 5
		}
		return h
	}
	h -= m.vp.Height() + 2
	if h < 5 {
		h = 5
	}
	return h
}

func (m *model) ensureVisible() {
	rows := buildListRows(m.images)
	vi := visualIndex(rows, m.cursor)
	if vi > 0 && rows[vi-1].kind == listHeader {
		vi--
	}
	lh := m.visibleRows()
	if vi < m.offset {
		m.offset = vi
	}
	end := visualIndex(rows, m.cursor)
	if end >= m.offset+lh {
		m.offset = end - lh + 1
	}
	if m.offset < 0 {
		m.offset = 0
	}
}

func (m *model) visibleRows() int {
	h := m.listHeight()
	if h > 2 {
		return h - 2
	}
	if h < 1 {
		return 1
	}
	return h
}

func (m *model) refreshDetail() {
	if m.phase != phaseSelect || len(m.images) == 0 {
		return
	}
	m.vp.SetContent(renderDetail(m.images[m.cursor], m.styles, max(24, m.vp.Width())))
}

func (m model) View() tea.View {
	st := m.styles
	var body strings.Builder
	body.WriteString(st.title.Render("✦ strip_image"))
	body.WriteString("  ")
	body.WriteString(st.muted.Render(m.root))
	body.WriteString("\n\n")

	switch m.phase {
	case phaseLoad:
		body.WriteString(m.spinner.View())
		body.WriteString(st.accent.Render(" Scanning images and reading metadata…\n"))
	case phaseEmpty:
		body.WriteString(st.warn.Render("No images found in this directory.\n"))
	case phaseErr:
		body.WriteString(st.warn.Render(fmt.Sprintf("Error: %v\n", m.err)))
	case phaseSelect:
		body.WriteString(m.renderSelect())
	case phaseConfirm:
		n := m.selectedCount()
		body.WriteString(st.warn.Render(fmt.Sprintf("Strip ALL metadata from %d selected image(s)?\n\n", n)))
		body.WriteString(st.muted.Render("Enter to confirm · Esc to go back · q to quit\n"))
	case phaseStrip:
		total := m.selectedCount()
		done := m.stripped + m.failed + len(m.skipMsgs)
		frac := 0.0
		if total > 0 {
			frac = float64(done) / float64(total)
		}
		body.WriteString(m.spinner.View())
		body.WriteString(st.accent.Render(fmt.Sprintf(" Stripping %d/%d\n\n", done, total)))
		body.WriteString(m.progress.ViewAs(frac))
		body.WriteString("\n")
	case phaseDone:
		body.WriteString(st.ok.Render(fmt.Sprintf("Stripped: %d", m.stripped)))
		body.WriteString("  ")
		body.WriteString(st.muted.Render(fmt.Sprintf("Skipped: %d", m.skipped)))
		body.WriteString("  ")
		body.WriteString(st.warn.Render(fmt.Sprintf("Failed: %d\n", m.failed)))
		for _, msg := range m.skipMsgs {
			body.WriteString("  ")
			body.WriteString(st.muted.Render(msg))
			body.WriteString("\n")
		}
		for _, msg := range m.failMsgs {
			body.WriteString("  ")
			body.WriteString(st.warn.Render(msg))
			body.WriteString("\n")
		}
		body.WriteString(st.muted.Render("\nEnter or q to quit.\n"))
	}

	content := st.frame.Width(m.width).Height(m.height).Render(body.String())
	v := tea.NewView(content)
	v.AltScreen = true
	v.WindowTitle = "strip_image"
	return v
}

func (m model) renderSelect() string {
	st := m.styles
	list := m.renderList()
	help := st.help.Render(m.help.View(keys))
	if !m.useSidebar() {
		return list + "\n" + m.vp.View() + "\n" + help
	}
	sw := m.sidebarWidth()
	lw := m.listColWidth()
	h := m.listHeight()
	left := st.listPane.Width(lw).MaxHeight(h).Render(list)
	right := st.sidePane.Width(sw).Height(h).Render(m.vp.View())
	row := lipgloss.JoinHorizontal(lipgloss.Top, left, right)
	return row + "\n" + help
}

func (m model) renderList() string {
	st := m.styles
	var b strings.Builder
	b.WriteString(st.muted.Render(fmt.Sprintf("%d images", len(m.images))))
	b.WriteString(st.muted.Render("  ·  "))
	b.WriteString(st.ok.Render(fmt.Sprintf("%d selected", m.selectedCount())))
	b.WriteString("\n")
	rows := buildListRows(m.images)
	end := m.offset + m.visibleRows()
	if end > len(rows) {
		end = len(rows)
	}
	start := m.offset
	if start < 0 {
		start = 0
	}
	if start > len(rows) {
		start = len(rows)
	}
	colW := m.listColWidth()
	nameW := max(12, colW-14)
	for i := start; i < end; i++ {
		row := rows[i]
		if row.kind == listHeader {
			title := row.dir
			if title == "." {
				title = "this folder"
			}
			b.WriteString(st.heading.Width(min(colW, max(lipgloss.Width(title)+2, 16))).Render("▸ " + title))
			b.WriteString("\n")
			continue
		}
		img := m.images[row.imgIdx]
		gutter := "  "
		if row.imgIdx == m.cursor {
			gutter = st.accent.Render("❯ ")
		}
		mark := st.checkOff.Render("·")
		if img.Selected {
			mark = st.checkOn.Render("✓")
		}
		badge := formatBadge(img.RelPath, st)
		name := truncate(groupLeaf(img.RelPath), nameW)
		line := lipgloss.JoinHorizontal(lipgloss.Left, gutter, mark, " ", badge, " ", name)
		if row.imgIdx == m.cursor {
			line = st.cursor.Width(colW).MaxWidth(colW).Render(line)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func renderPills(cats []string, st styles, width int) string {
	if len(cats) == 0 {
		return st.muted.Render("none")
	}
	parts := make([]string, 0, len(cats))
	for _, c := range cats {
		sty := st.muted
		if p, ok := st.pill[c]; ok {
			sty = p
		}
		parts = append(parts, sty.Render(fieldIcon(c)+" "+c))
	}
	joined := strings.Join(parts, st.muted.Render(" · "))
	if width > 8 {
		return lipgloss.Wrap(joined, width, " ")
	}
	return joined
}

func renderDetail(img meta.Image, st styles, width int) string {
	inner := max(20, width)
	var b strings.Builder
	b.WriteString(formatBadge(img.RelPath, st))
	b.WriteString(" ")
	b.WriteString(st.path.Render(lipgloss.Wrap(img.RelPath, max(12, inner-6), "/")))
	b.WriteString("\n")
	b.WriteString(renderPills(img.PresentTags(), st, inner))
	b.WriteString("\n")
	summary := lipgloss.Wrap(meta.Summarize(img), max(16, inner-2), " ")
	b.WriteString(st.summary.Width(inner).Render(summary))
	b.WriteString("\n")
	b.WriteString(st.rawHead.Render("Raw tags"))
	b.WriteString("\n")
	if img.InspectErr != nil {
		b.WriteString(st.warn.Render(fmt.Sprintf("inspect warning: %v\n", img.InspectErr)))
	}
	order := []string{
		meta.CatCamera, meta.CatExposure, meta.CatGeo, meta.CatTime,
		meta.CatDesc, meta.CatCopyright, meta.CatSoftware, meta.CatAI,
		meta.CatFileSystem,
	}
	seen := map[string]struct{}{}
	for _, cat := range order {
		seen[cat] = struct{}{}
		writeCat(img.Categories[cat], cat, st, inner, &b)
	}
	var extra []string
	for cat := range img.Categories {
		if _, ok := seen[cat]; ok {
			continue
		}
		if cat == meta.CatOther {
			continue
		}
		extra = append(extra, cat)
	}
	sort.Strings(extra)
	for _, cat := range extra {
		writeCat(img.Categories[cat], cat, st, inner, &b)
	}
	if fields := img.Categories[meta.CatOther]; len(fields) > 0 {
		for _, f := range fields {
			line := "  " + fieldIcon(f.Name) + " " + f.Name + ": " + f.Value
			b.WriteString(st.rawVal.Render(lipgloss.Wrap(line, inner, " ")))
			b.WriteString("\n")
		}
	}
	return b.String()
}

func writeCat(fields []meta.Field, cat string, st styles, inner int, b *strings.Builder) {
	if len(fields) == 0 {
		return
	}
	b.WriteString(st.section.Render(catIcon(cat) + " " + cat))
	b.WriteString("\n")
	for _, f := range fields {
		line := "  " + fieldIcon(f.Name) + " " + f.Name + ": " + f.Value
		b.WriteString(st.rawVal.Render(lipgloss.Wrap(line, inner, " ")))
		b.WriteString("\n")
	}
}

func truncate(s string, w int) string {
	if w <= 1 || lipgloss.Width(s) <= w {
		return s
	}
	runes := []rune(s)
	if len(runes) <= 2 {
		return s
	}
	keep := w - 1
	if keep < 1 {
		keep = 1
	}
	if keep >= 2 {
		return "…" + string(runes[len(runes)-(keep-1):])
	}
	return string(runes[len(runes)-keep:])
}
