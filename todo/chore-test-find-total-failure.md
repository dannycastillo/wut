# chore: cover Find's total-failure branch

- **Priority:** low
- **Branch:** chore/test-find-total-failure
- **Touches:** internal/search/search.go, internal/search/*_test.go
- **Blocked by:** —

## Goal
`Find`'s `len(scanErrs) == len(files)` branch (`search.go:81`) is exercised by
a test that asserts it returns a non-nil error.

## Why
`chore/raise-test-coverage` asked for this branch specifically — it's the one
that closed the `errors.Join()`-returns-nil silent-exit trap, and nothing
proved it still holds. That todo's `Touches` scoped the branch to
`internal/search/*_test.go, internal/ui/list_picker_test.go, cmd/*_test.go,
cmd/root.go`, which doesn't include `search.go`. `aih check` enforces `Touches`
against trunk's copy of the todo, so it can't be widened mid-branch by editing
the local copy. Filed separately rather than expanded into that branch.

## Notes
`Find` (`search.go:38-83`) inlines `listFiles()` and the fan-out in one
function. `listFiles`'s files come from the embedded seed (`internal/seed`,
always opens) plus `~/.wut`, so every file failing to scan isn't reachable
through `Find` with real inputs — the seam has to live in `search.go` itself.

One shape that worked in a since-reverted attempt on `chore/raise-test-coverage`:
split `Find` into `Find` (calls `listFiles`, unchanged) and an unexported
function taking `[]snippetSource` and `Query` that does the fan-out — same
body, no behavior change — then test that function directly with
`fstest.MapFS{}` sources whose `Open` always fails. `scan_test.go` and the new
`search_test.go`/`sources_test.go` from that branch already show the pattern.

## Done when
- [ ] `Find`'s total-failure branch is exercised by a test, built on
      `fstest.MapFS`
- [ ] The test asserts the returned error is non-nil
- [ ] `go build ./...` and `go vet ./...` pass
- [ ] `go test -race ./...` passes
