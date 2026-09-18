# feat: move the help line above the results

- **Priority:** medium
- **Branch:** feat/help-above-results
- **Touches:** internal/ui/list_picker.go, internal/ui/list_picker_test.go
- **Blocked by:** —

## Goal
The picker paints the key hints above the result rows. Pagination stays below.

## Why
The hints are instructions: you read them before you act, not after. Below the
list they sit where the eye lands last, and their distance from the top moves
with the number of results.

## Notes

### bubbles/list will not reorder for you

`list.Model.View` hardcodes the section order — title, status bar, content,
pagination, help — with no hook (`list.go:1041-1084`). Help has to come out of
the list and be rendered by `frame()`.

The seam is already exported, so this is not a fork:

```go
l.SetShowHelp(false)                 // stop the list drawing it
m.list.Help.View(m.list)             // draw it ourselves
```

`list.Model` satisfies `help.KeyMap` through its own `ShortHelp()` and
`FullHelp()` (`list.go:967`, `:1002`), and `Help` is an exported `help.Model`
field (`:184`). So the bindings, including `AdditionalShortHelpKeys`, keep
working untouched.

### The shedding arithmetic goes circular if you are not careful

`resize()` derives `chrome` by measuring:

```go
chrome := lipgloss.Height(m.frame()) - lipgloss.Height(m.list.View())
```

Today that is always 1 — the leading `"\n"`. Once `frame()` draws help, `chrome`
includes the help rows, and `avail` is computed from `chrome` while the decision
to *show* help is computed from `avail`. Break the cycle explicitly: measure
chrome without help, then decide, then render. Do not leave it depending on the
order the two happen to run in.

`helpRows` is currently the cost of help *inside the list*. It has to be
re-measured once help is outside it, the same way `ADR-04` re-measured it when
the title bar left. `paginationRows` is unaffected — pagination stays in the
list.

### Two details that will bite

- `HelpStyle` is `Padding(1, 0, 0, rowPad)` — a blank row *above* help, which
  separated it from the list below. Above the list you want the blank row
  underneath instead: `Padding(0, 0, 1, rowPad)`. The row count is the same, so
  the re-measured constant does not change again.
- `frame()` must still open with a blank row. `cmd/root.go:104-107` prints the
  copied-command line onto it, and `Pick`'s erase counts back from the frame's
  height to land there. Help goes *after* the leading `"\n"`, not before it.

### Verify, do not assume

`?` toggles `m.list.Help.ShowAll` through the list's own keymap. Check it still
toggles once the list is no longer the thing rendering help — the binding and
the renderer are separate, but that is worth seeing rather than reasoning about.
Full help is several rows tall, so confirm the frame still fits with it open.

### This re-blocks the demo gifs

`doc-record-demo-gifs` was waiting on `feat-slim-the-picker` for the same
reason: recording before a layout change means recording twice. Its
**Blocked by** now points here.

## Done when
- [ ] The key hints render above the result rows; pagination stays below
- [ ] `?` still toggles full help, and the frame still fits the terminal with it open
- [ ] Chrome still sheds as the terminal shrinks, with `helpRows` re-measured
      rather than carried over
- [ ] `frame()` still opens with a blank row and `cmd` still prints onto it
- [ ] Tests assert the new order and the re-measured shedding thresholds
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
