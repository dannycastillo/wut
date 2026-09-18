# feat: make the list chrome theme-aware

- **Priority:** low
- **Branch:** feat/theme-aware-list-chrome
- **Touches:** internal/ui/list_picker.go, internal/ui/list_picker_test.go
- **Blocked by:** —

## Goal
The picker's pagination dots and help text pick their colors from the
terminal's background rather than assuming a dark one.

## Why
They are hardcoded dark today, and not by us. `ADR-04` removed a `darkBG`
parameter that looked like theme support and could not do anything; this is the
real thing it was standing in front of.

Low priority because the hardcoded values are subdued grays (`#5C5C5C`,
`#3C3C3C`, `#979797`) that stay readable on a light background. It looks
slightly wrong, not broken.

## Notes

### Where the colors actually come from

Not from `newStyles()`. `list.New` builds its own table (`list.go:207-210`):

```go
// XXX: Let the user choose between light and dark colors. We've
// temporarily hardcoded the dark colors here.
styles := DefaultStyles(true)
```

We overwrite exactly two fields of it — `PaginationStyle` and `HelpStyle` — and
both carry padding and no color. The colored fields are
`ActivePaginationDot`, `InactivePaginationDot` and the `help.Model`'s own
styles, which we never touch. So there is no parameter to thread: the fix is to
build the whole `list.Styles` value and assign it.

Note `list.New` also copies the dot styles into the paginator at construction
(`p.ActiveDot = styles.ActivePaginationDot.String()`), so assigning
`m.list.Styles` after the fact is not enough on its own — the paginator's own
`ActiveDot`/`InactiveDot` strings need setting too.

### Deriving the background honestly

`tea.BackgroundColorMsg` with `IsDark()` (`bubbletea/color.go:67-77`). It
arrives as a message, so `updateStyles` regains a parameter and `Update` grows
a case. That is the honest version of what ADR-04 deleted — do not reintroduce
the hardcoded `true`.

If the terminal never answers, there is no message and no default: decide what
the picker does in that case and make it visible in the code.

### Scope

Only the chrome. The hovered row stays `Reverse(true)` per ADR-04 — it already
borrows the terminal's palette and needs nothing from this.

## Done when
- [ ] Pagination dots and help text derive their colors from a real
      `tea.BackgroundColorMsg`, with the no-answer case handled explicitly
- [ ] No hardcoded `DefaultStyles(true)` reaches the picker's rendered chrome
- [ ] The hovered row is unchanged
- [ ] A test covers both branches without a TTY
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
