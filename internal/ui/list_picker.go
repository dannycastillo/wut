package ui

import (
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

var ErrAborted = errors.New("selection aborted")

// maxListHeight caps the picker so it stays a modest inline widget on a tall
// terminal.
const maxListHeight = 14

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
	for i, c := range choices {
		items[i] = c
		natural = max(natural, ansi.StringWidth(c.Title))
	}

	l := list.New(items, itemDelegate{}, 0, 0) // real size arrives via WindowSizeMsg
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
		list:       l,
		choice:     -1,
		naturalCmd: natural,
		idxWidth:   len(strconv.Itoa(len(choices))),
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
	title        lipgloss.Style
	item         lipgloss.Style
	selectedItem lipgloss.Style
	pagination   lipgloss.Style
	help         lipgloss.Style
}

func newStyles(darkBG bool) styles {
	var s styles
	s.title = lipgloss.NewStyle().MarginLeft(2)
	s.item = lipgloss.NewStyle().PaddingLeft(4)
	s.selectedItem = lipgloss.NewStyle().PaddingLeft(2).Foreground(lipgloss.Color("170"))
	s.pagination = list.DefaultStyles(darkBG).PaginationStyle.PaddingLeft(4)
	s.help = list.DefaultStyles(darkBG).HelpStyle.PaddingLeft(4)
	return s
}

type itemDelegate struct {
	styles   styles // by value: no aliasing, no nil deref
	cmdWidth int    // padded width of the command column, 0 = unaligned
	idxWidth int    // digits in the largest row number
}

func (d itemDelegate) Height() int                             { return 1 }
func (d itemDelegate) Spacing() int                            { return 0 }
func (d itemDelegate) Update(_ tea.Msg, _ *list.Model) tea.Cmd { return nil }

func (d itemDelegate) Render(w io.Writer, m list.Model, index int, listItem list.Item) {
	c, ok := listItem.(Choice)
	if !ok || m.Width() <= 0 {
		return // no size yet; first frame before WindowSizeMsg
	}

	// Truncate before padding: Width() wraps content that overflows.
	cmd := c.Title
	if d.cmdWidth > 0 {
		cmd = lipgloss.NewStyle().Width(d.cmdWidth).
			Render(ansi.Truncate(cmd, d.cmdWidth, "…"))
	}

	str := fmt.Sprintf("%*d. %s  %s", d.idxWidth, index+1, cmd, c.Desc)

	// Clamp to the list width so the row can never wrap and break Height()==1.
	if avail := m.Width() - d.styles.item.GetPaddingLeft() - d.styles.item.GetPaddingRight(); avail > 0 {
		str = ansi.Truncate(str, avail, "…")
	}

	fn := d.styles.item.Render
	if index == m.Index() {
		fn = func(s ...string) string {
			return d.styles.selectedItem.Render("> " + strings.Join(s, " "))
		}
	}

	fmt.Fprint(w, fn(str))
}

type model struct {
	list          list.Model
	choice        int
	styles        styles
	width, height int
	naturalCmd    int // widest Title across all choices, in display cells
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

	// Reserve the row we were invoked from and the row cmd prints on exit, so
	// the picker never scrolls the user's prompt off screen.
	const reserved = 2

	avail := m.height - chrome - reserved

	// Shed chrome rather than overflow. Help costs 6 rows of list chrome,
	// pagination 4, neither 2. Keep each only while at least minVisible
	// results still fit underneath it, otherwise the decoration crowds out
	// the thing it decorates.
	const minVisible = 3
	m.list.SetShowHelp(avail-6 >= minVisible)
	m.list.SetShowPagination(avail-4 >= minVisible)

	avail = min(avail, maxListHeight)
	avail = max(avail, 1)
	m.list.SetHeight(avail)

	// Command column gets at most half the width.
	cmdWidth := 0
	if m.width > 0 {
		cmdWidth = min(m.naturalCmd, m.width/2)
	}
	m.list.SetDelegate(itemDelegate{
		styles:   m.styles,
		cmdWidth: cmdWidth,
		idxWidth: m.idxWidth,
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
		switch keypress := msg.String(); keypress {
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
