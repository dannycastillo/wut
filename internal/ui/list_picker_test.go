package ui

import (
	"errors"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
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

// The picker must always leave room for the prompt it was invoked from and the
// line cmd prints on exit. Overflowing scrolls those off screen permanently.
func TestFrameFitsTerminal(t *testing.T) {
	for _, h := range []int{6, 8, 12, 24, 60} {
		m := size(t, newModel("Results", sample(30)), 80, h)

		if got, budget := lipgloss.Height(m.frame()), h-2; got > budget {
			t.Errorf("height %d: frame is %d rows, budget %d", h, got, budget)
		}
	}
}

// choiceDelegate.Height reports 1, which is a contract with bubbles/list: it
// allocates exactly one row per item and derives pagination and cursor
// position from that. A row wider than the terminal makes the *terminal* wrap
// it to two lines, breaking the contract at display time.
//
// Width is the assertion that matters here, not height: lipgloss never wraps,
// so an over-wide row shows up as an over-wide frame, never as a taller one.
func TestRowsNeverExceedTerminalWidth(t *testing.T) {
	long := strings.Repeat("du -sh * | sort -rh | head -n 10 ", 8)

	wide := make([]Choice, 8)
	for i := range wide {
		wide[i] = Choice{Title: long, Desc: long}
	}

	for _, w := range []int{40, 80, 120} {
		m := size(t, newModel("Results", wide), w, 24)

		if got := lipgloss.Width(m.frame()); got > w {
			t.Errorf("width %d: frame rendered %d columns wide", w, got)
		}
		for i, line := range strings.Split(m.frame(), "\n") {
			if got := lipgloss.Width(line); got > w {
				t.Errorf("width %d: line %d is %d columns", w, i, got)
			}
		}
	}
}

// Chrome is shed as the terminal shrinks rather than overflowing, and results
// stay visible at every size.
func TestChromeShedsBeforeResults(t *testing.T) {
	for _, h := range []int{6, 8, 12, 24} {
		m := size(t, newModel("Results", sample(30)), 80, h)

		if !strings.Contains(m.frame(), "tofu init") {
			t.Errorf("height %d: no result visible:\n%s", h, m.frame())
		}
	}
}

func TestEnterSelectsHoveredRow(t *testing.T) {
	m := size(t, newModel("Results", sample(5)), 80, 24)

	next, _ := m.Update(tea.KeyPressMsg{Code: tea.KeyDown})
	m = next.(model)
	next, _ = m.Update(tea.KeyPressMsg{Code: tea.KeyEnter})
	m = next.(model)

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
		m := size(t, newModel("Results", sample(5)), 80, 24)

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
	m := size(t, newModel("Results", nil), 80, 24)

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
	idx, err := Pick("Results", nil)

	if !errors.Is(err, ErrAborted) {
		t.Errorf("err = %v, want ErrAborted", err)
	}
	if idx != -1 {
		t.Errorf("idx = %d, want -1", idx)
	}
}
