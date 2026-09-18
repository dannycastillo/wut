# chore: tidy the scanner's leftovers

- **Priority:** low
- **Branch:** chore/tidy-the-scanner
- **Touches:** internal/search/scan.go
- **Blocked by:** —

## Goal
`countMatches` names its parameters for what they hold, and `scanChunk` returns
a value whose type matches what it can actually produce.

## Why
Both were deliberately left alone during the `internal/search` extraction
(`2ca2ce4`) so the move could be verified as a move — every function body
diffed byte-identical against `git show main:cmd/root.go`. That constraint is
gone now, and these are the two things a reader of a public repo would notice
first in an otherwise clean package.

## Notes

### `countMatches` — `internal/search/scan.go:94`

Parameters are `slice1` and `slice2`. They are not interchangeable: one is the
query's words, the other the candidate's. The names say nothing about which is
which, which matters because the function is asymmetric.

### `scanChunk` — `internal/search/scan.go:70`

Returns `[]Result` but can only ever produce zero or one element. `(Result,
bool)` or `*Result` says that in the signature instead of leaving the caller to
discover it. Check the call site in `scanFile` (`:44-58`) — it iterates the
slice to stamp `FromUser` at `:53-57`, so the loop collapses too.

### Neither changes behavior

That is the point, and it's what makes this a `chore`. If a test has to change
to accommodate either one, stop — something is different that shouldn't be.

Worth pairing with `chore/raise-test-coverage`, which adds the first direct
tests for both functions. Doing that first gives this branch something to prove
itself against; doing it second means writing the tests twice.

## Done when
- [ ] `countMatches`'s parameters are named for their contents
- [ ] `scanChunk`'s return type expresses zero-or-one
- [ ] `scanFile`'s call site is simplified accordingly
- [ ] `go test ./...` passes with no test modified
- [ ] `go build ./...` and `go vet ./...` pass
