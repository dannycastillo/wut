# chore: extract search and ranking into internal/search

- **Priority:** high
- **Branch:** chore/extract-search-package
- **Touches:** cmd/root.go, cmd/root_test.go, internal/search, AGENTS.md, docs
- **Blocked by:** —

## Goal
`cmd/root.go` holds the Cobra command and the presentation of its results.
Finding and ranking snippets lives in `internal/search`.

## Why
`cmd/root.go` is 394 lines doing four unrelated jobs: Cobra wiring, file
discovery, text scanning and scoring, and result presentation. Length is the
symptom — the file is hard to change because a reader has to hold all four in
mind at once.

`searchCoordinator` is where it hurts: 85 lines that fan out a scan, apply an
error policy, rank, print warnings, open a picker, and write the clipboard.

## Notes
- The seam is clean. Only two declarations in the file touch stdout, stderr, or
  the clipboard — `Execute` and `searchCoordinator`. Everything else is pure or
  filesystem-only.
- `Result` and `Query` are exported today with zero consumers outside `cmd`, so
  moving them breaks nothing.
- Search and ranking stay **one** package. Ranking operates on search results
  and shares the `Result` type; two packages would leave one whose only
  consumer is the other.
- Warnings must be returned, not printed. The `fmt.Fprintln(os.Stderr,
  "warning:", e)` inside the scan is a policy about a terminal living in a
  function that reads files.
- This is a move, not a rewrite. Bodies transfer verbatim so the diff can be
  checked by eye. The exception is `chunkNumber` — assigned, incremented, read
  never; don't carry dead code into a new package.
- Leave `countMatches`'s `slice1, slice2` parameter names and `scanChunk`'s
  always-0-or-1 `[]Result` alone. Both are real, both would make the move
  unreviewable by inspection. File them separately.
- ADR-01 fixes `ui.Pick(title, []ui.Choice)`; building the choices stays in
  `cmd`. ADR-02 fixes where snippets live; `internal/seed` gets imported by
  `internal/search` instead of `cmd`, which is a move, not a change.

## Done when
- [ ] `internal/search` exposes `NewQuery`, `Find`, `Query`, `Result` and
      nothing else
- [ ] `Find` returns partial failures as warnings and prints nothing
- [ ] `cmd/root.go` is under 150 lines with no `bufio`, `bytes`, `fs`, `sort`,
      `sync` or `seed` import
- [ ] Every moved function body is byte-identical to its old one, except the
      two deleted `chunkNumber` lines
- [ ] `wut --help`, a no-match query, and an unreadable snippet file all behave
      exactly as they do on `main`
- [ ] `go build ./...`, `go vet ./...` and `go test ./...` pass
