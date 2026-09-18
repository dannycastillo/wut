package ui

import (
	"errors"
	"fmt"
	"io"
	"os"

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

	// Measured, not derived: bubbles/list floors at 5 rows with both
	// decorations, 3 with pagination only, 1 with neither.
	helpRows       = 4
	paginationRows = 2
)

// One constant, so the string a row is joined with and the width resize
// measures cannot drift apart.
const (
	descSep = "  "
	descGap = len(descSep)
)

const rowPad = 1 // left margin, on every line the picker paints

// Choice is everything the picker needs to draw one row.
type Choice struct {
	Title string
	Desc  string
}

func (c Choice) FilterValue() string { return c.Title + " " + c.Desc }

// newModel builds the picker without running it, so layout and key handling are
// testable without a TTY.
func newModel(choices []Choice) model {
	items := make([]list.Item, len(choices))
	naturalTitle, naturalDesc := 0, 0
	for i, choice := range choices {
		items[i] = choice
		naturalTitle = max(naturalTitle, ansi.StringWidth(choice.Title))
		naturalDesc = max(naturalDesc, ansi.StringWidth(choice.Desc))
	}

	l := list.New(items, choiceDelegate{}, 0, 0) // real size arrives via WindowSizeMsg

	// Not redundant with assigning no Title: list.New defaults Title to "List".
	l.SetShowTitle(false)
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)

	// The default keymap binds Quit to "v" and labels it "select".
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
		naturalTitle: naturalTitle,
		naturalDesc:  naturalDesc,
	}
	m.styles = newStyles()
	m.resize()
	return m
}

// Pick runs the picker and returns the index of the chosen Choice, or
// ErrAborted if the user dismissed it without choosing.
func Pick(choices []Choice) (int, error) {
	if len(choices) == 0 {
		return -1, ErrAborted // no index it could honestly return
	}

	m := newModel(choices)

	final, err := tea.NewProgram(m, tea.WithOutput(os.Stderr)).Run()
	if err != nil {
		return -1, fmt.Errorf("run picker: %w", err)
	}

	fm, ok := final.(model)
	if !ok {
		return -1, ErrAborted
	}

	// Bubble Tea leaves its final frame in the scrollback, so walk back to the
	// first row it painted and erase from there down.
	//
	// The leading \r is not cosmetic: a row padded to the full list width can
	// leave the cursor in the pending-wrap state — still on row N, but the next
	// glyph lands on N+1. Terminals disagree on whether CPL then counts from N
	// or N+1, which cost one row in Terminal.app.
	if n := lipgloss.Height(fm.frame()) - 1; n > 0 {
		fmt.Fprintf(os.Stderr, "\r\x1b[%dF\x1b[0J", n)
	}

	if fm.choice < 0 {
		return -1, ErrAborted
	}
	return fm.choice, nil
}

type styles struct {
	choice         lipgloss.Style
	selectedChoice lipgloss.Style
	pagination     lipgloss.Style
	help           lipgloss.Style
}

func newStyles() styles {
	var s styles
	s.choice = lipgloss.NewStyle().PaddingLeft(rowPad)

	// Reverse borrows the terminal's own palette, so the hovered row stays
	// legible in a theme this package cannot see. Width is set per-resize.
	s.selectedChoice = lipgloss.NewStyle().PaddingLeft(rowPad).Reverse(true)

	// Written out rather than taken from list.DefaultStyles: helpRows counts the
	// top padding row, which a library default could stop providing.
	s.pagination = lipgloss.NewStyle().PaddingLeft(rowPad)
	s.help = lipgloss.NewStyle().Padding(1, 0, 0, rowPad)
	return s
}

type choiceDelegate struct {
	styles     styles // by value: no aliasing, no nil deref
	titleWidth int    // padded width of the title column, 0 = unaligned
}

func (d choiceDelegate) Height() int                             { return 1 }
func (d choiceDelegate) Spacing() int                            { return 0 }
func (d choiceDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

func (d choiceDelegate) Render(w io.Writer, m list.Model, index int, item list.Item) {
	choice, ok := item.(Choice)
	if !ok || m.Width() <= 0 {
		return // no size yet; first frame before WindowSizeMsg
	}

	title := choice.Title
	if d.titleWidth > 0 {
		// Truncate before padding: Width() wraps content that overflows.
		title = lipgloss.NewStyle().Width(d.titleWidth).
			Render(ansi.Truncate(title, d.titleWidth, "…"))
	}
	row := title + descSep + choice.Desc

	style := d.styles.choice
	if index == m.Index() {
		style = d.styles.selectedChoice
	}

	// Bound by the style that actually renders the row: lipgloss wraps at
	// width-padding, and a wrapped row breaks the Height()==1 delegate contract.
	bound := style.GetWidth()
	if bound == 0 {
		bound = m.Width()
	}
	if avail := bound - style.GetHorizontalPadding(); avail > 0 {
		row = ansi.Truncate(row, avail, "…")
	}

	fmt.Fprint(w, style.Render(row))
}

type model struct {
	list          list.Model
	choice        int
	styles        styles
	width, height int
	naturalTitle  int // widest Choice.Title across all choices, in display cells
	naturalDesc   int // widest Choice.Desc, same units
}

// resize sizes the list from the terminal, never the other way around.
func (m *model) resize() {
	m.list.SetWidth(m.width)

	// Measured rather than assumed, so restyling frame() cannot silently break
	// the arithmetic below.
	chrome := lipgloss.Height(m.frame()) - lipgloss.Height(m.list.View())
	avail := m.height - chrome - reservedRows

	// Shed chrome rather than overflow.
	m.list.SetShowHelp(avail-helpRows >= minVisible)
	m.list.SetShowPagination(avail-paginationRows >= minVisible)

	m.list.SetHeight(max(min(avail, maxListHeight), 1))

	titleWidth := 0
	if m.width > 0 {
		titleWidth = min(m.naturalTitle, m.width/2)
	}

	// Every title renders at exactly titleWidth, so the widest row is that
	// column plus the widest description — no need to render them to find out.
	delegateStyles := m.styles
	pad := delegateStyles.choice.GetHorizontalPadding()
	if content := min(titleWidth+descGap+m.naturalDesc, m.width-pad); content > 0 {
		delegateStyles.selectedChoice = delegateStyles.selectedChoice.Width(pad + content)
	}

	m.list.SetDelegate(choiceDelegate{
		styles:     delegateStyles,
		titleWidth: titleWidth,
	})

	// JoinVertical pads every section to the widest one, so a single over-wide
	// line makes every row that wide and the terminal wraps all of them. bubbles
	// sizes the help to the list width, unaware of the padding HelpStyle adds,
	// and keeps a binding when even its ellipsis will not fit — so MaxWidth is
	// the backstop, since lipgloss truncates the rendered line last of all.
	m.list.Help.SetWidth(max(m.width-pad, 0))
	m.list.Styles.HelpStyle = m.styles.help.MaxWidth(m.width)
	m.list.Styles.PaginationStyle = m.styles.pagination.MaxWidth(m.width)
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
			// GlobalIndex reports 0 on an empty list, which would hand the
			// caller an index into nothing.
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

// frame is the exact string the picker paints; its line count is what Pick's
// erase counts back from.
func (m model) frame() string {
	return "\n" + m.list.View()
}

// View always paints a frame with real height, including after tea.Quit. An
// empty final view zeroes the renderer's cell buffer, whose shutdown then runs
// MoveTo(0, -1) and leaves the cursor somewhere terminal-dependent.
func (m model) View() tea.View {
	return tea.NewView(m.frame())
}
