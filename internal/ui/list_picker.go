// Package ui is the picker: it draws the ranked results inline and returns the
// index of the row the user chose.
package ui

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"charm.land/bubbles/v2/help"
	"charm.land/bubbles/v2/key"
	"charm.land/bubbles/v2/list"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

// ErrAborted means the picker closed without a selection, whether the user
// dismissed it or a resize did.
var ErrAborted = errors.New("selection aborted")

// Layout tuning, all in terminal rows.
const (
	maxListHeight = 14 // cap, so the picker stays a modest inline widget
	reservedRows  = 2  // the invoking command line, and the line cmd prints on exit
	minVisible    = 3  // keep a decoration only while this many choices fit under it

	// Measured, not derived. helpRows gates only the show/hide decision in
	// resize — the actual row cost of a shown help block is read back from
	// what it rendered to, in helpHeight, since full help costs more than
	// short. paginationRows is bubbles/list's own floor with pagination shown
	// and nothing else.
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

	// list.New hardcodes list.DefaultStyles(true) for the pagination dots and
	// help.New hardcodes help.DefaultDarkStyles() for the help text — both
	// marked XXX upstream. Neither is corrected until a real
	// tea.BackgroundColorMsg names the terminal's background (applyTheme);
	// until then, or if one never arrives, these stay at the paginator's own
	// colorless defaults rather than assuming dark.
	l.Paginator.ActiveDot = "•"
	l.Paginator.InactiveDot = "○"
	l.Help.Styles = help.Styles{}

	// Not redundant with assigning no Title: list.New defaults Title to "List".
	l.SetShowTitle(false)
	l.SetShowStatusBar(false)
	l.SetFilteringEnabled(false)

	// The default keymap binds Quit to "v" and labels it "select".
	l.KeyMap.Quit = key.NewBinding(
		key.WithKeys("q", "esc"),
		key.WithHelp("q/esc", "quit"),
	)

	// list.Model.View hardcodes help below the content with no hook to move it.
	// frame() draws it above instead, so the list itself never shows it — the
	// bindings (ShortHelp, FullHelp, AdditionalShortHelpKeys, the "?" toggle)
	// stay untouched; only where the rendered block ends up changes.
	l.SetShowHelp(false)
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
	m.resize()
	return m
}

// Pick runs the picker and returns the index of the chosen Choice, or
// ErrAborted if it closed without one.
func Pick(choices []Choice) (int, error) {
	if len(choices) == 0 {
		return -1, ErrAborted // no index it could honestly return
	}

	p := tea.NewProgram(newModel(choices), tea.WithOutput(os.Stderr))

	stop := onResize(p.Quit)
	defer stop()

	final, err := p.Run()
	if err != nil {
		return -1, fmt.Errorf("run picker: %w", err)
	}

	fm, ok := final.(model)
	if !ok {
		return -1, ErrAborted
	}

	// Bubble Tea leaves its final frame in the scrollback: walk back to its first
	// row and erase down. The \r matters: a full-width row leaves the cursor
	// pending-wrap, and terminals disagree whether CPL then counts from N or N+1.
	if n := lipgloss.Height(fm.frame()) - 1; n > 0 {
		fmt.Fprintf(os.Stderr, "\r\x1b[%dF\x1b[0J", n)
	}

	if fm.choice < 0 {
		return -1, ErrAborted
	}
	return fm.choice, nil
}

// onResize calls f on every terminal resize until the returned stop is called.
//
// This exists to get ahead of Bubble Tea, which handles the same signal: its
// WindowSizeMsg costs two trips through the event loop and an ioctl in between,
// and it repaints the frame on that message before the model is given a say.
// The signal is the earliest the picker can know, and every repaint after the
// terminal has moved is one it cannot take back.
func onResize(f func()) (stop func()) {
	winch := make(chan os.Signal, 1)
	signal.Notify(winch, syscall.SIGWINCH)

	done := make(chan struct{})
	go func() {
		for {
			select {
			case <-winch:
				f()
			case <-done:
				return
			}
		}
	}()

	return func() {
		signal.Stop(winch)
		close(done)
	}
}

var (
	rowStyle = lipgloss.NewStyle().PaddingLeft(rowPad)

	// Reverse borrows the terminal's own palette, so the hovered row is legible in any theme.
	hoveredStyle = lipgloss.NewStyle().PaddingLeft(rowPad).Reverse(true)

	// Written out rather than taken from list.DefaultStyles: paginationRows
	// counts this exactly, which a library default isn't obliged to keep.
	paginationStyle = lipgloss.NewStyle().PaddingLeft(rowPad)

	// Padded below rather than above: help now sits above the results, so the
	// blank row that separates it from them belongs underneath. Written out
	// for the same reason as paginationStyle: helpHeight measures this padding.
	helpStyle = lipgloss.NewStyle().Padding(0, 0, 1, rowPad)
)

type choiceDelegate struct {
	hovered    lipgloss.Style // rowStyle plus reverse, carrying this size's bar width
	titleWidth int            // padded width of the title column, 0 = unaligned
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

	style := rowStyle
	if index == m.Index() {
		style = d.hovered
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

	_, _ = fmt.Fprint(w, style.Render(row))
}

type model struct {
	list          list.Model
	choice        int
	width, height int
	showHelp      bool // list itself never draws help; frame() does, above the results
	naturalTitle  int  // widest Choice.Title across all choices, in display cells
	naturalDesc   int  // widest Choice.Desc, same units
}

// resize sizes the list from the terminal, never the other way around.
func (m *model) resize() {
	m.list.SetWidth(m.width)

	pad := rowStyle.GetHorizontalPadding()

	// JoinVertical pads every section to the widest, so one over-wide line wraps
	// every row. bubbles sizes the help unaware of HelpStyle's padding and keeps
	// a binding even when its ellipsis will not fit; MaxWidth is the backstop.
	// Set before layout() below, which measures the help block at this width.
	m.list.Styles.HelpStyle = helpStyle.MaxWidth(m.width)
	m.list.Styles.PaginationStyle = paginationStyle.MaxWidth(m.width)

	avail := m.avail()

	// Shed chrome rather than overflow. helpRows is short help's measured cost;
	// it only has to gate this decision, taken once here with Help.ShowAll at
	// its zero value, never at the "?" keypress that can make help taller.
	m.showHelp = avail-helpRows >= minVisible
	m.list.SetShowPagination(avail-paginationRows >= minVisible)

	m.layout(avail)

	titleWidth := 0
	if m.width > 0 {
		titleWidth = min(m.naturalTitle, m.width/2)
	}

	// Every title renders at exactly titleWidth, so the widest row is that
	// column plus the widest description — no need to render them to find out.
	hovered := hoveredStyle
	if content := min(titleWidth+descGap+m.naturalDesc, m.width-pad); content > 0 {
		hovered = hovered.Width(pad + content)
	}

	m.list.SetDelegate(choiceDelegate{
		hovered:    hovered,
		titleWidth: titleWidth,
	})
}

// avail is the rows left for the list once the leading blank row and the
// caller's own chrome (reservedRows) are spoken for. Measured with help
// forced off rather than assumed, so restyling frame() cannot silently break
// this arithmetic, and so the decision resize() makes from it cannot feed
// back into the budget that decides it.
func (m model) avail() int {
	m.showHelp = false
	chrome := lipgloss.Height(m.frame()) - lipgloss.Height(m.list.View())
	return m.height - chrome - reservedRows
}

// layout gives the list its share of avail, net of whatever help is actually
// costing right now. It is called from resize, and again whenever "?"
// changes Help.ShowAll: full help is taller than short, and nothing else
// re-lays out the list mid-session (ADR-06 closes the picker on a real
// resize instead).
func (m *model) layout(avail int) {
	pad := rowStyle.GetHorizontalPadding()
	m.list.Help.SetWidth(max(m.width-pad, 0))

	listBudget := avail
	if m.showHelp {
		listBudget -= m.helpHeight()
	}
	m.list.SetHeight(max(min(listBudget, maxListHeight), 1))

	// SetHeight resets Help's width to the full list width, via bubbles' own
	// SetSize; reassert the pad-adjusted width it does not know about.
	m.list.Help.SetWidth(max(m.width-pad, 0))
}

// helpHeight is the actual rendered cost of the help block frame() draws,
// including the newline that joins it to the list below — not the helpRows
// constant, which only pins the show/hide decision at short help's size.
func (m model) helpHeight() int {
	if !m.showHelp {
		return 0
	}
	return lipgloss.Height(m.list.Styles.HelpStyle.Render(m.list.Help.View(m.list))) + 1
}

func (m model) Init() tea.Cmd {
	return tea.RequestBackgroundColor
}

// applyTheme colors the pagination dots and help text once a real
// tea.BackgroundColorMsg has named the terminal's background. list.New and
// help.New assume dark; this is what makes that assumption honest instead of
// silently deleted.
func (m *model) applyTheme(isDark bool) {
	dots := list.DefaultStyles(isDark)
	m.list.Paginator.ActiveDot = dots.ActivePaginationDot.String()
	m.list.Paginator.InactiveDot = dots.InactivePaginationDot.String()
	m.list.Help.Styles = help.DefaultStyles(isDark)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.BackgroundColorMsg:
		m.applyTheme(msg.IsDark())
		return m, nil

	case tea.WindowSizeMsg:
		switch {
		case m.width == 0 && m.height == 0:
			m.width, m.height = msg.Width, msg.Height
			m.resize()
			return m, nil

		case msg.Width == m.width && msg.Height == m.height:
			return m, nil // Bubble Tea re-sends the current size in some situations
		}

		// Rows the terminal has scrolled or re-wrapped are beyond the erase, and
		// a repaint adds a second copy. No resize(): Pick counts back from frame().
		return m, tea.Quit

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

	prevShowAll := m.list.Help.ShowAll

	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)

	// "?" toggled full help through the list's own keymap: re-lay-out, since
	// full help costs more rows than the short help resize() sized around.
	if m.list.Help.ShowAll != prevShowAll {
		m.layout(m.avail())
	}
	return m, cmd
}

// frame is the exact string the picker paints; its line count is what Pick's
// erase counts back from. The leading blank row comes first, then help, then
// the list itself — cmd/root.go prints the copied-command line onto the blank
// row, so nothing may be drawn above it.
func (m model) frame() string {
	if !m.showHelp {
		return "\n" + m.list.View()
	}
	// HelpStyle's own padding renders its blank separator row without a
	// trailing newline, so the "+" here needs one explicitly or that row
	// fuses onto the list's first line instead of standing on its own.
	help := m.list.Styles.HelpStyle.Render(m.list.Help.View(m.list))
	return "\n" + help + "\n" + m.list.View()
}

// View always paints a frame with real height, including after tea.Quit. An
// empty final view zeroes the renderer's cell buffer, whose shutdown then runs
// MoveTo(0, -1) and leaves the cursor somewhere terminal-dependent.
func (m model) View() tea.View {
	return tea.NewView(m.frame())
}
