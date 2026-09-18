# ADR-04: The picker shows rows only

- **Status:** Accepted
- **Supersedes:** ADR-01
- **Date:** 2026-09-18

## Context
The Bubble Tea decision in ADR-01 stands. What changes here is the picker's
surface and what it paints — not the library under it.

The picker drew a `Results` header, `N. ` row numbers, a `> ` cursor and an
ANSI-170 foreground. The header named what the user had just typed. The numbers
were not addressable: there is no key handler that selects row 3 when you press
`3`. The cursor and the color were two signals for one job.

ADR-01 fixed the surface as `ui.Pick(title, []ui.Choice)`. With no header the
`title` argument has no reader, and `cmd/root.go` was passing a literal
`"Results"` that would go nowhere.

## Decision
`ui.Pick([]ui.Choice) (int, error)`. The picker paints result rows, pagination
and help, and nothing else.

The hovered row is `lipgloss.Reverse(true)`, spanning the widest rendered row.
No explicit color remains in `internal/ui`.

## Alternatives considered
- **Keep `title` and ignore it** — needs no record, and leaves exactly the dead
  plumbing the rest of the backlog is removing.
- **A full-terminal-width bar** — inverts half a 200-column window to mark one
  row.
- **A bar that hugs each row's text** — the right edge moves as the cursor does.
- **Keep the numbering** — costs a column to display something you cannot type.
- **An explicit selected color** — has to be chosen against a background this
  tool cannot see. Reverse borrows the terminal's own.

## Consequences
- The picker reads in any terminal theme, because it now names no color.
- `newStyles()` takes no theme parameter. The one it had could not affect a
  cell: the fields it fed carry padding only, and the chrome that is colored —
  pagination dots, help text — comes from `list.New`'s own hardcoded
  `DefaultStyles(true)`, which bubbles marks `XXX`. ADR-01's "Styles are
  theme-aware" was never true. Making it true is `todo/feat-theme-aware-list-chrome.md`.
- There is no `tea.BackgroundColorMsg` handler, and adding one would change
  nothing until that todo is done.
- The title bar's 2 rows return as results: `helpRows` 6 → 4 and
  `paginationRows` 4 → 2. An 8-row terminal shows 3 results where it showed 1.
- `l.SetShowTitle(false)` is load-bearing. bubbles/list defaults `Title` to
  `"List"`, so assigning nothing renders that instead of nothing.
- Refreshing the counts ADR-01 cites: 304 lines of picker, 11 tests. The file
  grew while losing features — the rendering rules it now depends on
  (`Width` includes padding, reverse paints whitespace, lipgloss wraps at
  `width - padding`) are recorded in comments rather than rediscovered.
- Four of those tests assert what is *absent* from the frame. That is the only
  way this stays true: the previous suite covered geometry and selection and
  would not have noticed any of the chrome coming back.
