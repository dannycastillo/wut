package ui

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

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

// "?" toggles full help through the list's own keymap. The block it draws is
// taller than short help, so resize()'s budget is not enough on its own —
// layout() has to run again on the toggle, or full help pushes the frame
// past what the terminal has.
func TestFullHelpStillFitsAndToggleWorks(t *testing.T) {
	for _, h := range []int{24, 40, 60} {
		m := size(t, newModel(sample(30)), 80, h)

		full := press(t, m, tea.KeyPressMsg{Code: '?', Text: "?"})
		if !full.list.Help.ShowAll {
			t.Fatalf("height %d: %q did not toggle full help", h, "?")
		}
		if got, budget := lipgloss.Height(full.frame()), h-2; got > budget {
			t.Errorf("height %d: full help frame is %d rows, budget %d:\n%s",
				h, got, budget, ansi.Strip(full.frame()))
		}

		short := press(t, full, tea.KeyPressMsg{Code: '?', Text: "?"})
		if short.list.Help.ShowAll {
			t.Errorf("height %d: a second %q did not close full help", h, "?")
		}
		if got, want := short.frame(), m.frame(); got != want {
			t.Errorf("height %d: toggling full help and back left the frame different:\ngot  %q\nwant %q",
				h, got, want)
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

		// HelpStyle's bottom padding is one of the two rows helpRows pays for:
		// help now sits above the results, so the blank row that separates them
		// trails it rather than leading it.
		if tc.wantHelp {
			lines := strings.Split(frame, "\n")
			for i, line := range lines {
				if !strings.Contains(line, "copy") {
					continue
				}
				if i+1 >= len(lines) || strings.TrimSpace(lines[i+1]) != "" {
					t.Errorf("height %d: help is not followed by a blank row:\n%s", tc.height, frame)
				}
				break
			}
		}
	}
}

// The hints are instructions: they belong above the rows they explain, not
// after them, and pagination stays with the results it paginates.
func TestHelpRendersAboveResultsPaginationBelow(t *testing.T) {
	m := size(t, newModel(sample(30)), 80, 24)
	frame := ansi.Strip(m.frame())

	if !m.showHelp || !m.list.ShowPagination() {
		t.Fatalf("fixture must show both help and pagination at 80x24:\n%s", frame)
	}

	helpIdx := strings.Index(frame, "copy")
	resultIdx := strings.Index(frame, "tofu init")
	// LastIndex: help's own short-help entries are "•"-separated too, so the
	// first "•" in the frame is inside help, not the pagination dots below.
	dotsIdx := strings.LastIndex(frame, "•")

	if helpIdx < 0 || resultIdx < 0 || dotsIdx < 0 {
		t.Fatalf("expected help, a result and pagination dots all in the frame:\n%s", frame)
	}
	if helpIdx >= resultIdx || resultIdx >= dotsIdx {
		t.Errorf("want order help(%d) < result(%d) < pagination(%d):\n%s", helpIdx, resultIdx, dotsIdx, frame)
	}
}

// Without SetShowTitle(false) the header comes back reading "List", which is
// bubbles' default rather than anything this package set.
func TestFrameOpensOnABlankRow(t *testing.T) {
	m := size(t, newModel(sample(5)), 80, 24)
	lines := strings.Split(m.frame(), "\n")

	// cmd/root.go prints the copied-command line onto this row, which is why
	// frame() leads with "\n" and why nothing — help included — may be drawn
	// above it.
	if lines[0] != "" {
		t.Errorf("frame opens with %q, want an empty row", lines[0])
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
	pad := rowStyle.GetHorizontalPadding()
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

// Which resizes move rows the picker has already emitted depends on the rest of
// the screen and the terminal's reflow, so every real change closes it.
func TestAnyResizeClosesThePicker(t *testing.T) {
	m := size(t, newModel(sample(30)), 80, 24)

	for _, tc := range []struct {
		name string
		w, h int
	}{
		{"one row shorter", 80, 23},
		{"one column narrower", 79, 24},
		{"one row taller", 80, 25},
		{"one column wider", 81, 24},
		{"much smaller", 20, 6},
		{"much larger", 200, 60},
		{"both at once", 60, 40},
	} {
		next, cmd := m.Update(tea.WindowSizeMsg{Width: tc.w, Height: tc.h})
		got := next.(model)

		if cmd == nil {
			t.Errorf("%s (%dx%d): kept running, want close", tc.name, tc.w, tc.h)
			continue
		}
		if _, ok := cmd().(tea.QuitMsg); !ok {
			t.Errorf("%s (%dx%d): returned %T, want QuitMsg", tc.name, tc.w, tc.h, cmd())
		}
		if got.choice != -1 {
			t.Errorf("%s (%dx%d): closed with choice %d, want none selected",
				tc.name, tc.w, tc.h, got.choice)
		}
	}
}

// Bubble Tea re-sends the current size in some situations. Without this guard
// the picker would close the moment it finished drawing.
func TestResendingTheSameSizeIsNotAResize(t *testing.T) {
	m := size(t, newModel(sample(30)), 80, 24)

	next, cmd := m.Update(tea.WindowSizeMsg{Width: 80, Height: 24})

	if cmd != nil {
		t.Errorf("the same size returned %T, want no command", cmd())
	}
	if !strings.Contains(next.(model).frame(), "tofu init") {
		t.Error("the same size tore the list down")
	}
}

func TestFirstSizeOpensThePicker(t *testing.T) {
	next, cmd := newModel(sample(30)).Update(tea.WindowSizeMsg{Width: 80, Height: 24})
	m := next.(model)

	if cmd != nil {
		t.Errorf("opening returned %T, want no command", cmd())
	}
	if !strings.Contains(m.frame(), "tofu init") {
		t.Error("opening did not lay the list out")
	}
}

// Pick erases by counting back from the frame, so a frame it is about to
// abandon has to keep matching what is on screen.
func TestClosingLeavesTheFrameAlone(t *testing.T) {
	m := size(t, newModel(sample(30)), 80, 24)
	before := m.frame()

	next, cmd := m.Update(tea.WindowSizeMsg{Width: 20, Height: 6})
	got := next.(model)

	if cmd == nil {
		t.Fatal("expected that resize to close the picker")
	}
	if after := got.frame(); after != before {
		t.Errorf("the frame was re-laid-out on the way out:\n%q\nwant unchanged:\n%q",
			after, before)
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
		// An empty final view zeroes the renderer's cell buffer, and its shutdown
		// then runs MoveTo(0, -1), which cost a row of the user's scrollback.
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

// Drives the built binary under tmux, because what it guards is what the
// terminal does with rows already emitted — nothing a model can observe.
//
//	WUT_TERMINAL_TESTS=1 go test ./internal/ui/ -run TestResizeLeavesNothingBehind
func TestResizeLeavesNothingBehind(t *testing.T) {
	if os.Getenv("WUT_TERMINAL_TESTS") == "" {
		t.Skip("set WUT_TERMINAL_TESTS=1 to run (needs tmux, takes ~8s)")
	}
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux is not installed")
	}

	dir := t.TempDir()

	// Its own HOME, so the fixture is not whatever is in the developer's ~/.wut.
	snippets := filepath.Join(dir, "home", ".wut")
	if err := os.MkdirAll(snippets, 0o755); err != nil {
		t.Fatal(err)
	}
	var b strings.Builder
	for i := range 12 {
		fmt.Fprintf(&b, "# row %02d of the resize fixture\nzzfixture-%02d --flag\n\n", i, i)
	}
	if err := os.WriteFile(filepath.Join(snippets, "fixture.txt"), []byte(b.String()), 0o644); err != nil {
		t.Fatal(err)
	}

	bin := filepath.Join(dir, "wut")
	if out, err := exec.Command("go", "build", "-o", bin, "wut").CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}

	session := fmt.Sprintf("wut-resize-test-%d", os.Getpid())
	tmux := func(args ...string) string {
		out, err := exec.Command("tmux", args...).Output()
		if err != nil {
			t.Fatalf("tmux %s: %v", strings.Join(args, " "), err)
		}
		return string(out)
	}
	t.Cleanup(func() { _ = exec.Command("tmux", "kill-session", "-t", session).Run() })

	tmux("new-session", "-d", "-s", session, "-x", "80", "-y", "24")
	// 1.8s, not 1.5s: at 1.5s this went intermittent, roughly one run in eight.
	settle := func() { time.Sleep(1800 * time.Millisecond) }

	tmux("send-keys", "-t", session,
		fmt.Sprintf("HOME=%s PS1='> ' %s zzfixture", filepath.Join(dir, "home"), bin), "Enter")
	settle()

	count := func() int {
		return strings.Count(tmux("capture-pane", "-p", "-t", session), "zzfixture-00")
	}
	if got := count(); got != 1 {
		t.Fatalf("picker did not open cleanly: %d copies of the first row, want 1", got)
	}

	tmux("resize-window", "-t", session, "-x", "80", "-y", "8")
	settle()

	// The picker should have closed itself rather than repaint through a resize
	// it cannot reason about, and taken its rows with it.
	if got := count(); got != 0 {
		t.Errorf("after a resize: %d picker rows still on screen, want 0", got)
	}

}
