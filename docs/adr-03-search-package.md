# ADR-03: Finding and ranking snippets live in `internal/search`

- **Status:** Accepted
- **Date:** 2026-09-18

## Context
`cmd/root.go` had grown to 394 lines doing four unrelated jobs: Cobra wiring,
file discovery, text scanning and scoring, and result presentation. 208 of
those lines never touch the terminal. `searchCoordinator` straddled the seam —
85 lines that fanned out a scan, applied an error policy, ranked the results,
then printed warnings, opened the picker, and wrote the clipboard.

## Decision
`internal/search` owns finding and ranking. Its surface is four names:

```go
type Query  // a normalised search
type Result // one ranked match
func NewQuery(args []string) Query
func Find(q Query) (results []Result, warnings []error, err error)
```

`Find` returns partial failures as warnings and prints nothing. A file it could
not read is a fact; whether that fact deserves a line on stderr is the caller's
policy. An error means nothing could be read at all.

`cmd` keeps the Cobra command and the presentation of results: warnings, the
empty case, the `[]ui.Choice` build, the picker, the clipboard.

## Alternatives considered
- **Split `cmd/root.go` into several files in package `cmd`** — file boundaries
  are not enforced by anything, so the next function to reach for a terminal
  would.
- **Separate `search` and `rank` packages** — ranking operates on search results
  and shares `Result`; `rank`'s only consumer would be `search`.
- **`Find` printing its own warnings** — keeps the call site shorter, at the
  cost of putting a policy about terminals inside a function that reads files,
  and makes it untestable without capturing stderr.

## Consequences
- Search is testable without Cobra, a terminal, or a TTY. The existing tests
  moved unchanged.
- `Find` returns three values, which is unusual. It is the honest shape: a
  warning is not an error, and collapsing them loses the difference between
  "one file was unreadable" and "nothing was readable".
- `internal/seed` is now imported by `internal/search` rather than `cmd`.
  Dependencies run one way: `cmd → internal/search → internal/seed`.
- A second front-end — a `--json` flag, a different picker — no longer means
  touching scanning or scoring code.
- `Query` and `Result` are exported for `cmd` to read. They were already
  exported in `cmd` with no consumers; now the export means something.
