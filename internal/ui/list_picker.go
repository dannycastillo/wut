package ui

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

var ErrAborted = errors.New("selection aborted")

// Layout tuning, all in terminal rows.
const (
	maxListHeight = 14 // cap, so the picker stays a modest inline widget
	reservedRows  = 2  // the invoking command line, and the line cmd prints on exit
	minVisible    = 3  // keep a decoration only while this many choices fit under it

	// What each decoration costs in list chrome, measured: bubbles/list floors
	// at 7 rows with both, 5 with pagination only, 3 with neither.
	helpRows       = 6
	paginationRows = 4
)

// Choice is everything the picker needs to draw one row.
type Choice struct {
	Title string
	Desc  string
}

func (c Choice) FilterValue() string { return c.Title + " " + c.Desc }

// newModel builds the picker without running it, so its layout and key
// handling are testable as pure functions.
func newModel(title string, choices []Choice) model {
	items := make([]list.Item, len(choices))
	natural := 0
	for i, choice := range choices {
		items[i] = choice
		natural = max(natural, ansi.StringWidth(choice.Title))
	}

	l := list.New(items, choiceDelegate{}, 0, 0) // real size arrives via WindowSizeMsg
	l.Title = title
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)

	// The default keymap binds Quit to "v" and labels it "select", which is
	// both wrong and not what Update implements.
	l.KeyMap.Quit = key.NewBinding(
		key.WithKeys("q", "esc"),
		key.WithHelp("q/esc", "quit"),
	)
	l.AdditionalShortHelpKeys = func() []key.Binding {
		return []key.Binding{
			key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "copy")),
		}
	}

	m := model{
		list:         l,
		choice:       -1,
		naturalTitle: natural,
		idxWidth:     len(strconv.Itoa(len(choices))),
	}
	m.updateStyles(true)
	return m
}

func Pick(title string, choices []Choice) (int, error) {
	// Never open an empty picker: there is no index it could honestly return.
	if len(choices) == 0 {
		return -1, ErrAborted
	}

	m := newModel(title, choices)

	final, err := tea.NewProgram(m, tea.WithOutput(os.Stderr)).Run()
	if err != nil {
		return -1, fmt.Errorf("run picker: %w", err)
	}

	fm, ok := final.(model)
	if !ok {
		return -1, ErrAborted
	}

	// Bubble Tea leaves its final frame in the scrollback. Walk back up to the
	// first row it painted and erase from there down. CPL is relative, so it
	// stays correct even if the terminal scrolled while the picker was open.
	//
	// The leading \r is not cosmetic: rows are padded to the full list width,
	// so the last one can leave the cursor in the pending-wrap state — still on
	// row N, but the next glyph lands on N+1. Terminals disagree on whether CPL
	// then counts from N or N+1, which cost one row (the user's command line)
	// in Terminal.app. \r resolves the ambiguity before any vertical movement.
	if n := lipgloss.Height(fm.frame()) - 1; n > 0 {
		fmt.Fprintf(os.Stderr, "\r\x1b[%dF\x1b[0J", n)
	}

	if fm.choice < 0 {
		return -1, ErrAborted
	}
	return fm.choice, nil
}

type styles struct {
	title          lipgloss.Style
	choice         lipgloss.Style
	selectedChoice lipgloss.Style
	pagination     lipgloss.Style
	help           lipgloss.Style
}

func newStyles(darkBG bool) styles {
	var s styles
	s.title = lipgloss.NewStyle().MarginLeft(2)
	s.choice = lipgloss.NewStyle().PaddingLeft(4)
	s.selectedChoice = lipgloss.NewStyle().PaddingLeft(2).Foreground(lipgloss.Color("170"))
	s.pagination = list.DefaultStyles(darkBG).PaginationStyle.PaddingLeft(4)
	s.help = list.DefaultStyles(darkBG).HelpStyle.PaddingLeft(4)
	return s
}

type choiceDelegate struct {
	styles     styles // by value: no aliasing, no nil deref
	titleWidth int    // padded width of the title column, 0 = unaligned
	idxWidth   int    // digits in the largest row number
}

func (d choiceDelegate) Height() int                             { return 1 }
func (d choiceDelegate) Spacing() int                            { return 0 }
func (d choiceDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

// Render draws one Choice. item is the library's interface value; everything
// past the assertion is ours and named accordingly.
func (d choiceDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	choice, ok := item.(Choice)
	if !ok || m.Width() <= 0 {
		return // no size yet; first frame before WindowSizeMsg
	}

	// Truncate before padding: Width() wraps content that overflows.
	title := choice.Title
	if d.titleWidth > 0 {
		title = lipgloss.NewStyle().Width(d.titleWidth).
			Render(ansi.Truncate(title, d.titleWidth, "…"))
	}

	row := fmt.Sprintf("%*d. %s  %s", d.idxWidth, index+1, title, choice.Desc)

	// Clamp to the list width so the row can never wrap and break Height()==1.
	if avail := m.Width() - d.styles.choice.GetPaddingLeft() - d.styles.choice.GetPaddingRight(); avail > 0 {
		row = ansi.Truncate(row, avail, "…")
	}

	if index == m.Index() {
		row = d.styles.selectedChoice.Render("> " + row)
	} else {
		row = d.styles.choice.Render(row)
	}

	fmt.Fprint(w, row)
}

type model struct {
	list          list.Model
	choice        int
	styles        styles
	width, height int
	naturalTitle  int // widest Title across all choices, in display cells
	idxWidth      int
}

func (m *model) updateStyles(isDark bool) {
	m.styles = newStyles(isDark)
	m.list.Styles.Title = m.styles.title
	m.list.Styles.PaginationStyle = m.styles.pagination
	m.list.Styles.HelpStyle = m.styles.help
	m.resize()
}

// resize sizes the list from the terminal, never the other way around.
func (m *model) resize() {
	m.list.SetWidth(m.width)

	// Rows the picker paints around the list itself, measured so that
	// restyling frame() can never silently break this.
	chrome := lipgloss.Height(m.frame()) - lipgloss.Height(m.list.View())

	avail := m.height - chrome - reservedRows

	// Shed chrome rather than overflow: keep a decoration only while enough
	// choices still fit underneath it, or it crowds out what it decorates.
	m.list.SetShowHelp(avail-helpRows >= minVisible)
	m.list.SetShowPagination(avail-paginationRows >= minVisible)

	avail = min(avail, maxListHeight)
	avail = max(avail, 1)
	m.list.SetHeight(avail)

	// The title column gets at most half the width.
	titleWidth := 0
	if m.width > 0 {
		titleWidth = min(m.naturalTitle, m.width/2)
	}
	m.list.SetDelegate(choiceDelegate{
		styles:     m.styles,
		titleWidth: titleWidth,
		idxWidth:   m.idxWidth,
	})
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.resize()
		return m, nil

	case tea.KeyPressMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit

		case "enter":
			// SelectedItem is nil on an empty list, where GlobalIndex would
			// still report 0 and hand the caller an index into nothing.
			if m.list.SelectedItem() == nil {
				return m, nil
			}
			m.choice = m.list.GlobalIndex()
			return m, tea.Quit
		}
	}

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)
	return m, cmd
}

// frame is the exact string the picker paints; its line count equals the number
// of rows actually drawn.
func (m model) frame() string {
	return "\n" + m.list.View()
}

// View always paints the full frame, including after tea.Quit. An empty final
// view would zero the renderer's cell buffer, and its shutdown path then runs
// MoveTo(0, cellbuf.Height()-1) — MoveTo(0, -1) — leaving the cursor somewhere
// terminal-dependent. Keeping a real height means shutdown lands on the frame's
// true bottom row, which is what Pick's erase counts back from.
func (m model) View() tea.View {
	return tea.NewView(m.frame())
}
