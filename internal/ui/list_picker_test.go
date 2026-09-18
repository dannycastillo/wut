package ui

import (
	"errors"
	"regexp"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/x/ansi"
)

func sample(n int) []Choice {
	out := make([]Choice, n)
	for i := range out {
		out[i] = Choice{Title: "tofu init", Desc: "# initialize working directory"}
	}
	return out
}

// size feeds a WindowSizeMsg the way Bubble Tea does at startup.
func size(t *testing.T, m model, w, h int) model {
	t.Helper()
	next, _ := m.Update(tea.WindowSizeMsg{Width: w, Height: h})
	got, ok := next.(model)
	if !ok {
		t.Fatalf("Update returned %T, want model", next)
	}
	return got
}

// press feeds one key the way the runtime does.
func press(t *testing.T, m model, k tea.KeyPressMsg) model {
	t.Helper()
	next, _ := m.Update(k)
	got, ok := next.(model)
	if !ok {
		t.Fatalf("Update returned %T, want model", next)
	}
	return got
}

// reversed returns the frame line indices painted in reverse video.
func reversed(frame string) []int {
	var out []int
	for i, line := range strings.Split(frame, "\n") {
		if strings.Contains(line, "\x1b[7m") {
			out = append(out, i)
		}
	}
	return out
}

// reverseWidth returns the bar's width, which is not the line's: JoinVertical
// pads every section out to the widest with ordinary spaces.
func reverseWidth(line string) int {
	const (
		on  = "\x1b[7m"
		off = "\x1b[m"
	)

	width := 0
	for {
		i := strings.Index(line, on)
		if i < 0 {
			return width
		}
		line = line[i+len(on):]

		j := strings.Index(line, off)
		if j < 0 {
			return width + ansi.StringWidth(line)
		}
		width += ansi.StringWidth(line[:j])
		line = line[j+len(off):]
	}
}

// The picker must always leave room for the prompt it was invoked from and the
// line cmd prints on exit. Overflowing scrolls those off screen permanently.
func TestFrameFitsTerminal(t *testing.T) {
	for _, h := range []int{6, 8, 12, 24, 60} {
		m := size(t, newModel(sample(30)), 80, h)

		if got, budget := lipgloss.Height(m.frame()), h-2; got > budget {
			t.Errorf("height %d: frame is %d rows, budget %d", h, got, budget)
		}
	}
}

// Every width, not a sample: the help overflows only in a band, and three
// sampled widths walked straight past it.
func TestRowsNeverExceedTerminalWidth(t *testing.T) {
	long := strings.Repeat("du -sh * | sort -rh | head -n 10 ", 8)

	// The bar is sized from the widest description, so mixed lengths exercise
	// padding that a uniform fixture never reaches.
	fixtures := map[string][]Choice{
		"uniform long": {{Title: long, Desc: long}, {Title: long, Desc: long}},
		"realistic": {
			{Title: "docker exec -it CONTAINER bash", Desc: "# open a shell in a running container"},
			{Title: "docker logs -f CONTAINER", Desc: "# follow container logs"},
			{Title: "docker run -it --rm IMAGE bash", Desc: "# run a container interactively and remove it on exit"},
			{Title: "ls", Desc: "# short"},
		},
		"identical": sample(20),
	}

	for name, choices := range fixtures {
		for w := 10; w <= 120; w++ {
			m := size(t, newModel(choices), w, 24)

			for i, line := range strings.Split(m.frame(), "\n") {
				if got := lipgloss.Width(line); got > w {
					t.Errorf("%s at width %d: line %d is %d columns:\n%q",
						name, w, i, got, ansi.Strip(line))
				}
			}
		}
	}
}

// MaxWidth alone would fit the line by chopping it. Sizing the help to the room
// it has lets bubbles drop a binding cleanly instead.
func TestHelpIsSizedToTheRoomItHas(t *testing.T) {
	for _, w := range []int{40, 60, 80} {
		m := size(t, newModel(sample(20)), w, 24)

		if got, want := m.list.Help.Width(), w-rowPad; got != want {
			t.Errorf("width %d: help sized to %d, want %d — the terminal less the padding HelpStyle adds",
				w, got, want)
		}
	}
}

// Overstating helpRows or paginationRows sheds silently, so the heights here
// are the two that pin them: 8, where pagination is the last thing that fits,
// and 10, where help is.
func TestChromeShedsBeforeResults(t *testing.T) {
	for _, tc := range []struct {
		height                 int
		wantHelp, wantPageDots bool
	}{
		{6, false, false},
		{8, false, true},
		{10, true, true},
		{24, true, true},
	} {
		m := size(t, newModel(sample(30)), 80, tc.height)
		frame := ansi.Strip(m.frame())

		if !strings.Contains(frame, "tofu init") {
			t.Errorf("height %d: no result visible:\n%s", tc.height, frame)
		}
		// "copy" is this picker's own help entry, from AdditionalShortHelpKeys.
		if got := strings.Contains(frame, "copy"); got != tc.wantHelp {
			t.Errorf("height %d: help shown = %v, want %v:\n%s", tc.height, got, tc.wantHelp, frame)
		}
		if got := strings.Contains(frame, "•"); got != tc.wantPageDots {
			t.Errorf("height %d: pagination shown = %v, want %v:\n%s", tc.height, got, tc.wantPageDots, frame)
		}

		// HelpStyle's top padding is one of the two rows helpRows pays for.
		if tc.wantHelp {
			lines := strings.Split(frame, "\n")
			for i, line := range lines {
				if !strings.Contains(line, "copy") {
					continue
				}
				if i == 0 || strings.TrimSpace(lines[i-1]) != "" {
					t.Errorf("height %d: help is not preceded by a blank row:\n%s", tc.height, frame)
				}
				break
			}
		}
	}
}

// Without SetShowTitle(false) the header comes back reading "List", which is
// bubbles' default rather than anything this package set.
func TestFrameOpensOnAResult(t *testing.T) {
	m := size(t, newModel(sample(5)), 80, 24)
	lines := strings.Split(m.frame(), "\n")

	// cmd/root.go prints the copied-command line onto this row, which is why
	// frame() leads with "\n" and why nothing may be drawn above the results.
	if lines[0] != "" {
		t.Errorf("frame opens with %q, want an empty row", lines[0])
	}
	if got := ansi.Strip(lines[1]); !strings.Contains(got, "tofu init") {
		t.Errorf("row 1 is %q, want the first result", got)
	}
	if strings.Contains(ansi.Strip(m.frame()), "List") {
		t.Errorf("bubbles' default title leaked into the frame:\n%s", m.frame())
	}
}

// Neither the numbering nor the cursor is addressable — you cannot type "3" to
// pick row 3 — so both are gone and the highlight carries the whole job.
func TestRowsCarryNoNumberOrCursor(t *testing.T) {
	numbered := regexp.MustCompile(`^\s*\d+\.\s`)

	m := size(t, newModel(sample(5)), 80, 24)

	for i, line := range strings.Split(m.frame(), "\n") {
		plain := ansi.Strip(line)
		if numbered.MatchString(plain) {
			t.Errorf("line %d is numbered: %q", i, plain)
		}
		if strings.HasPrefix(strings.TrimLeft(plain, " "), "> ") {
			t.Errorf("line %d carries a cursor: %q", i, plain)
		}
	}
}

// The hovered row is marked by reverse video alone: it borrows the terminal's
// own palette, so it stays legible in a theme this package cannot see.
func TestHoveredRowIsAReverseBar(t *testing.T) {
	m := size(t, newModel(sample(5)), 80, 24)
	frame := m.frame()

	lit := reversed(frame)
	if len(lit) != 1 {
		t.Fatalf("%d rows painted in reverse, want exactly 1:\n%s", len(lit), frame)
	}

	// The one signal left. An explicit foreground would be the second.
	if strings.Contains(frame, "\x1b[38;5;170m") {
		t.Error("the ANSI-170 foreground is still being painted")
	}

	// Equality, not a bound: a bound would also pass for a bar that hugs each
	// row's own text.
	c := sample(1)[0]
	pad := newStyles().choice.GetHorizontalPadding()
	want := pad + ansi.StringWidth(c.Title) + descGap + ansi.StringWidth(c.Desc)

	if got := reverseWidth(strings.Split(frame, "\n")[lit[0]]); got != want {
		t.Errorf("bar is %d cells, want %d", got, want)
	}

	// The bar is the cursor: it is the only thing that says which row enter
	// will copy.
	down := press(t, m, tea.KeyPressMsg{Code: tea.KeyDown})
	if next := reversed(down.frame()); len(next) != 1 || next[0] != lit[0]+1 {
		t.Errorf("after down, reversed rows = %v, want [%d]", next, lit[0]+1)
	}
}

// Every row is padded to the same width, so the bar's right edge is straight
// even when the hovered row's own text is far shorter than the widest one.
func TestBarSpansTheWidestRowNotItsOwn(t *testing.T) {
	m := size(t, newModel([]Choice{
		{Title: "ls", Desc: "# short"},
		{Title: "du -sh *", Desc: "# a considerably longer description than the first"},
	}), 100, 24)

	first := reverseWidth(strings.Split(m.frame(), "\n")[reversed(m.frame())[0]])

	down := press(t, m, tea.KeyPressMsg{Code: tea.KeyDown})
	second := reverseWidth(strings.Split(down.frame(), "\n")[reversed(down.frame())[0]])

	if first != second {
		t.Errorf("bar is %d cells on the short row and %d on the long one; the edge should not move", first, second)
	}
}

func TestEnterSelectsHoveredRow(t *testing.T) {
	m := size(t, newModel(sample(5)), 80, 24)

	m = press(t, m, tea.KeyPressMsg{Code: tea.KeyDown})
	m = press(t, m, tea.KeyPressMsg{Code: tea.KeyEnter})

	if want := 1; m.choice != want {
		t.Errorf("choice = %d, want %d", m.choice, want)
	}
}

// Aborting must be distinguishable from selecting row 0, which is why choice
// starts at -1 rather than the zero value.
func TestAbortKeysLeaveNoChoice(t *testing.T) {
	for _, k := range []tea.KeyPressMsg{
		{Code: 'q', Text: "q"},
		{Code: tea.KeyEscape},
	} {
		m := size(t, newModel(sample(5)), 80, 24)

		next, cmd := m.Update(k)
		m = next.(model)

		if cmd == nil {
			t.Fatalf("key %q: no command returned, want tea.Quit", k.String())
		}
		if _, ok := cmd().(tea.QuitMsg); !ok {
			t.Errorf("key %q: returned %T, want tea.QuitMsg", k.String(), cmd())
		}
		if m.choice != -1 {
			t.Errorf("key %q: choice = %d, want -1", k.String(), m.choice)
		}
		// The frame must keep a real height through quit. An empty final view
		// zeroes the renderer's cell buffer, and its shutdown then runs
		// MoveTo(0, -1), leaving the cursor terminal-dependent — which cost a
		// row of the user's scrollback.
		if got := lipgloss.Height(m.View().Content); got < 2 {
			t.Errorf("key %q: frame collapsed to %d rows on quit; shutdown needs a real height", k.String(), got)
		}
	}
}

// The panic this guards against was in cmd: an empty list still reports
// GlobalIndex() == 0, so enter handed the caller an index into an empty slice.
func TestEmptyChoicesNeverSelects(t *testing.T) {
	m := size(t, newModel(nil), 80, 24)

	next, cmd := m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m = next.(model)

	if m.choice != -1 {
		t.Errorf("choice = %d on an empty list, want -1", m.choice)
	}
	if cmd != nil {
		if _, quit := cmd().(tea.QuitMsg); quit {
			t.Error("enter quit the picker with nothing selected")
		}
	}
}

func TestPickRefusesEmpty(t *testing.T) {
	idx, err := Pick(nil)

	if !errors.Is(err, ErrAborted) {
		t.Errorf("err = %v, want ErrAborted", err)
	}
	if idx != -1 {
		t.Errorf("idx = %d, want -1", idx)
	}
}
