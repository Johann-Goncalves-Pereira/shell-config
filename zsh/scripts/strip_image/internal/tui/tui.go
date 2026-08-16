package tui

import (
	"fmt"
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
	isDark   bool
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
		m.help.Styles = help.DefaultStyles(m.isDark)
		return m, nil
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.progress.SetWidth(max(20, msg.Width-8))
		m.vp.SetWidth(msg.Width - 4)
		detailH := max(6, msg.Height/2-4)
		m.vp.SetHeight(detailH)
		m.help.SetWidth(msg.Width)
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
		m.refreshDetail()
		return m, nil
	case strippedMsg:
		if msg.err != nil {
			m.failed++
			m.failMsgs = append(m.failMsgs, fmt.Sprintf("%s: %v", m.images[m.stripIdx].RelPath, msg.err))
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

func (m *model) listHeight() int {
	h := m.height - m.vp.Height() - 8
	if h < 5 {
		h = 5
	}
	return h
}

func (m *model) ensureVisible() {
	lh := m.listHeight()
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+lh {
		m.offset = m.cursor - lh + 1
	}
}

func (m *model) refreshDetail() {
	if m.phase != phaseSelect || len(m.images) == 0 {
		return
	}
	m.vp.SetContent(renderDetail(m.images[m.cursor]))
}

func (m model) View() tea.View {
	var b strings.Builder
	title := lipgloss.NewStyle().Bold(true).Render("strip_image")
	b.WriteString(title)
	b.WriteString("  ")
	b.WriteString(m.root)
	b.WriteString("\n\n")

	switch m.phase {
	case phaseLoad:
		b.WriteString(m.spinner.View())
		b.WriteString(" Scanning images and reading metadata…\n")
	case phaseEmpty:
		b.WriteString("No images found in this directory.\n")
	case phaseErr:
		b.WriteString(fmt.Sprintf("Error: %v\n", m.err))
	case phaseSelect:
		b.WriteString(m.renderList())
		b.WriteString("\n")
		b.WriteString(m.vp.View())
		b.WriteString("\n")
		b.WriteString(m.help.View(keys))
	case phaseConfirm:
		n := m.selectedCount()
		b.WriteString(fmt.Sprintf("Strip ALL metadata from %d selected image(s)?\n\n", n))
		b.WriteString("Enter to confirm · Esc to go back · q to quit\n")
	case phaseStrip:
		total := m.selectedCount()
		done := m.stripped + m.failed
		frac := 0.0
		if total > 0 {
			frac = float64(done) / float64(total)
		}
		b.WriteString(m.spinner.View())
		b.WriteString(fmt.Sprintf(" Stripping %d/%d\n\n", done, total))
		b.WriteString(m.progress.ViewAs(frac))
		b.WriteString("\n")
	case phaseDone:
		b.WriteString(fmt.Sprintf("Stripped: %d  Skipped: %d  Failed: %d\n", m.stripped, m.skipped, m.failed))
		for _, msg := range m.failMsgs {
			b.WriteString("  ")
			b.WriteString(msg)
			b.WriteString("\n")
		}
		b.WriteString("\nEnter or q to quit.\n")
	}

	v := tea.NewView(b.String())
	v.AltScreen = true
	v.WindowTitle = "strip_image"
	return v
}

func (m model) renderList() string {
	var b strings.Builder
	b.WriteString(fmt.Sprintf("%d images · %d selected\n\n", len(m.images), m.selectedCount()))
	lh := m.listHeight()
	end := m.offset + lh
	if end > len(m.images) {
		end = len(m.images)
	}
	for i := m.offset; i < end; i++ {
		img := m.images[i]
		cur := "  "
		if i == m.cursor {
			cur = "> "
		}
		mark := "[ ]"
		if img.Selected {
			mark = "[x]"
		}
		cats := strings.Join(img.PresentCategories(), ", ")
		if cats == "" {
			cats = "none"
		}
		line := fmt.Sprintf("%s%s %s  %s", cur, mark, img.RelPath, cats)
		if i == m.cursor {
			line = lipgloss.NewStyle().Bold(true).Render(line)
		}
		b.WriteString(line)
		b.WriteString("\n")
	}
	return b.String()
}

func renderDetail(img meta.Image) string {
	var b strings.Builder
	b.WriteString(lipgloss.NewStyle().Underline(true).Render(img.RelPath))
	b.WriteString("\n")
	if img.InspectErr != nil {
		b.WriteString(fmt.Sprintf("inspect warning: %v\n", img.InspectErr))
	}
	order := []string{
		meta.CatCamera, meta.CatExposure, meta.CatGeo, meta.CatTime,
		meta.CatDesc, meta.CatCopyright, meta.CatSoftware, meta.CatAI,
		meta.CatFileSystem, meta.CatOther,
	}
	for _, cat := range order {
		fields := img.Categories[cat]
		if len(fields) == 0 {
			continue
		}
		b.WriteString("\n")
		b.WriteString(lipgloss.NewStyle().Bold(true).Render(cat))
		b.WriteString("\n")
		for _, f := range fields {
			b.WriteString(fmt.Sprintf("  %s: %s\n", f.Name, f.Value))
		}
	}
	return b.String()
}
