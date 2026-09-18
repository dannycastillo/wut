# fix: stop the help line overflowing narrow terminals

- **Priority:** medium
- **Branch:** fix/help-overflows-narrow-terminals
- **Touches:** internal/ui/list_picker.go, internal/ui/list_picker_test.go
- **Blocked by:** —

## Goal
The frame never renders wider than the terminal, at any width.

## Why
Below roughly 40 columns the help line is wider than the terminal. The terminal
wraps it, the frame grows rows nobody budgeted for, and the rows it pushes off
the top are the user's command line and the line `cmd` prints on exit — the
exact loss `reservedRows` exists to prevent.

Measured on `main` at `80ace1e`, 8 choices, height 24:

| terminal width | widest line |
| --- | --- |
| 16 | 16 |
| 20 | 23 |
| 30 | 56 |
| 40 | 40 |

Not a regression — it predates `feat/slim-the-picker` and was measured
identical on both sides of it.

## Notes

### Why the row tests do not catch it

`TestRowsNeverExceedTerminalWidth` samples 40, 80 and 120 — all clean. It is
also aimed at rows, and rows are fine: `choiceDelegate.Render` clamps them.
Nothing clamps the help.

`TestFrameFitsTerminal` measures `lipgloss.Height`, which counts the rows
lipgloss emits, not the rows the terminal displays after wrapping. Both tests
pass while the picker overflows.

### The fix

`list.Model.Help` is an exported `help.Model` with `SetWidth(int)`
(`help/help.go:115`), and `shouldAddItem` drops bindings that do not fit and
appends a tail. `list.New` never sets it, so it defaults to 0 — unlimited.

Setting it in `resize()` alongside the other width-derived values is the
natural place. Account for `HelpStyle`'s `PaddingLeft(4)`: the budget is the
terminal width minus that padding, not the terminal width.

Check whether the pagination row needs the same treatment at these widths.

### Test it where it actually breaks

Extend `TestRowsNeverExceedTerminalWidth`'s width table down through 16, 20 and
30, or add a frame-level case. Both fail today; the row loop already asserts
the right thing, it is just never run narrow enough.

## Done when
- [ ] No frame line exceeds the terminal width at widths 16, 20, 30, 40, 80, 120
- [ ] The help line degrades by dropping bindings rather than wrapping
- [ ] A test covers a width below 40
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
