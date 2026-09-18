# fix: rank results by score before showing the picker

- **Priority:** high
- **Branch:** fix/rank-results-by-score
- **Touches:** cmd/root.go
- **Blocked by:** —

## Goal
The picker lists results highest score first, and the same query produces the
same order every run.

## Why
`Result.Score` is written and never read. There is no `sort` import in the
package. Results are appended in whatever order goroutines happen to send them,
so ranking is currently arbitrary and varies run to run.

Raised from medium to high by ADR-02: the tool now searches 14 embedded seed
files plus everything under `~/.wut`, so a broad query returns far more rows
than it did against one file. Arbitrary order was survivable at five results
and is not at fifty.

## Notes
- `Score` is set in `buildMatch` (`cmd/root.go:344`); the scoring rules are the
  comment in `scanChunk` (`cmd/root.go:301`) — direct match 1000, word match
  500 + 5 per matching word.
- The sort belongs in `searchCoordinator`, after the `for r := range resultsChan`
  drain (`cmd/root.go:141`) and before `choices := make([]ui.Choice, ...)` at
  `cmd/root.go:165`. `idx` from `ui.Pick` indexes back into `finalResults`, so
  both slices must stay in the same order.
- `sort.Slice` is not stable and equal scores are common — two entries can both
  be 500. Break ties on a field that doesn't move (command text) so the order is
  reproducible, or use `sort.SliceStable`, which only helps if the input order is
  itself deterministic. It isn't.
- Seed and user files can hold the same snippet — a user who edits a shipped
  command copies it into `~/.wut` and gets both. Identical scores with identical
  command text are now expected, not hypothetical.
- ADR-01 fixes the picker's interface at `ui.Pick(title, []ui.Choice)`. Ordering
  is the caller's job; don't push sorting into `internal/ui`.

## Done when
- [ ] `finalResults` is ordered by `Score` descending before the picker is built
- [ ] Equal scores break on a deterministic tiebreak
- [ ] The same query run twice gives the identical order
- [ ] The copied command still matches the highlighted row
- [ ] `go build ./...` and `go vet ./...` pass
