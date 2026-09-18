# feat: slim the picker down to rows

- **Priority:** high
- **Branch:** feat/slim-the-picker
- **Touches:** internal/ui/list_picker.go, internal/ui/list_picker_test.go, cmd/root.go, docs/adr-01-bubbletea-over-promptui.md, docs/adr-04-*.md
- **Blocked by:** —

## Goal
The picker shows results and nothing else: no "Results" header, no row numbers,
no `>` cursor. The selected row is marked by reverse video. Help and pagination
stay.

## Why
The header names what the user already knows they asked for, the numbers aren't
addressable (you can't type `3` to pick row 3), and the cursor plus a pink
foreground are two signals doing one job. A highlight says "this one" without
spending a column or a color on it — and reverse video borrows the terminal's
own palette, so it's legible in any theme without a color being chosen.

This lands before `doc/record-demo-gifs`; recording first would mean recording
twice.

## Notes

### What goes

| What | Where |
| --- | --- |
| `l.Title` assignment | `internal/ui/list_picker.go:50` |
| `%*d. ` numbering in the row format | `:156` |
| `idxWidth` and its plumbing | `:70`, the `choiceDelegate` field at `:134`, the rebuild at `:215` |
| The `"> "` prefix and ANSI-170 foreground | `:163-167` |

Selected row becomes `lipgloss.NewStyle().Reverse(true)`. Unselected keeps its
`PaddingLeft`. The alignment trick at `:124-125` — unselected pads 4, selected
pads 2 and spends the other two cells on `"> "` — is no longer needed, so both
styles take the same padding.

### The dead theme plumbing goes with it

`newStyles(darkBG bool)` (`:121`) and `updateStyles(isDark bool)` (`:181`) thread
a parameter that is hardcoded `true` at `:72` and never re-derived — there is no
`tea.BackgroundColorMsg` handler anywhere. Once the only explicit color in the
package is gone, the remaining consumer is `list.DefaultStyles(darkBG)` at
`:126-127` for help and pagination. Either derive the value honestly from the
terminal or drop the parameter; do not leave it hardcoded.

### Width still matters

Reverse video paints the style's full rendered width, so a row shorter than the
terminal leaves a ragged bar. Decide deliberately whether the highlight spans
the full width (`Width(m.Width())` on the selected style) or hugs the text, and
make the choice visible in the code. The double truncation at `:149-161` exists
to protect the `Height() == 1` delegate contract — do not remove it; lipgloss
does not wrap, but the terminal does, and a wrapped row corrupts the list's
geometry.

### The ADR conflict — read this before starting

ADR-01 states the surface as `ui.Pick(title, []ui.Choice) (int, error)`. With no
header, `title` has no reader, and `cmd/root.go:86` passes a literal `"Results"`
that would go nowhere. Narrowing to `Pick([]Choice)` contradicts an accepted ADR,
so it needs a record rather than a quiet edit.

Recommended: `docs/adr-04-picker-shows-rows-only.md` with
`**Supersedes:** ADR-01`, plus a `**Superseded by:** ADR-04` line added to
ADR-01's status block — the only edit AGENTS.md permits on an accepted ADR. Say
plainly in ADR-04's Context that the Bubble Tea choice stands and only the
surface and the chrome change, so the record isn't misread as a return to
promptui. It rides on this branch as its own `doc:` commit.

The alternative is keeping the parameter and ignoring it. That needs no ADR, but
leaves exactly the dead plumbing the rest of this backlog removes.

Note also that ADR-01's Consequences cite "265 lines of picker" and "7 tests".
Both are still exact today and both go stale here; ADR-04 is where the current
numbers belong.

### Tests

No existing test asserts the header, the numbering or the cursor — the suite
covers geometry (`height <= h-2`, `width <= w`), the non-empty-frame-on-quit
invariant, and selection semantics. So nothing breaks, which also means nothing
catches a regression. Add assertions for what the new rendering guarantees:
no digit-dot prefix on a row, and the title string absent from `frame()`.

`TestChromeShedsBeforeResults` still applies — help and pagination stay, so
`resize()`'s shedding logic at `:201-202` is untouched.

### Cross-package coupling

`frame()`'s leading `"\n"` at `:255` is what lets `cmd/root.go:102-103` print
the copied-command line with no leading newline. Do not change the frame's top
row without following that through.

## Done when
- [ ] No header, no row numbers and no `>` cursor appear in the picker
- [ ] The selected row is reverse video; no explicit foreground color remains
- [ ] `idxWidth` is gone from the model and the delegate
- [ ] The `darkBG`/`isDark` parameter is either honestly derived or removed
- [ ] `cmd/root.go` no longer passes a title that nothing renders
- [ ] The ADR-01 conflict is resolved on the record, one way or the other
- [ ] Tests assert the absence of the numbering and the header
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
