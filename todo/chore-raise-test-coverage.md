# chore: raise test coverage to something defensible

- **Priority:** medium
- **Branch:** chore/raise-test-coverage
- **Touches:** internal/search/*_test.go, internal/ui/list_picker_test.go, cmd/*_test.go, cmd/root.go
- **Blocked by:** —

## Goal
Every function in `internal/search` has a test that asserts its behavior, and
`cmd` is no longer at zero.

## Why
Coverage today: `cmd` 0.0%, `internal/search` 34.3%, `internal/ui` 83.7%,
`internal/seed` no test files. The scoring rules — the thing that decides what a
user sees first — have no direct test at all. On a portfolio repo the test suite
is read as evidence of how the author works, and a package that ranks results
with an untested comparator undercuts that.

## Notes

### `internal/search` — the mechanical half

Untested entirely:

- `NewQuery` (`search.go:25`) — note it lowercases **the caller's slice in
  place** at `:28`. That aliasing is worth a test that pins it, or a decision to
  stop doing it.
- `listFiles` (`sources.go:27`), including the `fs.ErrNotExist` tolerance at
  `:46` that makes a missing `~/.wut` ordinary rather than fatal
- `collectTxt` (`sources.go:56`)
- `Find` (`search.go:42`) — the goroutine fan-out, the channel close, and the
  `len(scanErrs) == len(files)` total-failure branch at `:81`. That branch is
  the one that closed the `errors.Join()`-returns-nil silent-exit trap; nothing
  proves it still holds.

Executed but never asserted (they run under `TestScanFileStampsOrigin`, which
only checks `FromUser`):

- `scanChunk` (`scan.go:70`) — the 1000 direct-match vs `500 + 5n` word-match
  scoring
- `countMatches` (`scan.go:94`)
- `buildMatch` (`scan.go:114`) — the multi-line concatenation is entirely
  unexercised; see `fix/multi-line-snippet-join`
- `scanFile`'s error paths — the `*fs.PathError` label rewrite at `:16-25` and
  the scanner error at `:63-65`

`fstest.MapFS` covers all of this without touching disk; `scan_test.go` already
proves the pattern works. `listFiles` is the exception — it reads the real
`os.UserHomeDir()`, so testing it means either extracting the directory lookup
or accepting that one function stays uncovered. Say which in the commit.

### `cmd` — the design half

`run` (`cmd/root.go:62`) calls `search.Find` and `ui.Pick` directly, so there is
no seam to test against. That is a design decision to make on this branch, not a
mechanical addition. Options worth weighing: function variables the test swaps,
a small interface, or passing the two as parameters from `RunE`. Whatever wins,
the behavior worth pinning is the part with no other coverage — warnings going
to stderr, empty results exiting 0, `ErrAborted` exiting 0, and the
`results`/`choices` index parallelism at `:79-84` that the clipboard read at
`:94` depends on.

If the seam costs more than it's worth, say so and test what is reachable
instead. An honest 40% with the ranking rules covered beats 80% reached by
testing `Execute`.

### `internal/ui`

At 83.7% the gaps are mostly unreachable without a TTY: `Pick`'s real path
(`:82-110`), the `final.(model)` assertion, the CPL erase. `Choice.FilterValue`
(`:37`) is dead — filtering is disabled at `:53` — and may disappear anyway if
the picker stops using bubbles/list. Leave this package alone unless something
is cheap.

### Interaction with other branches

`chore/trim-the-comments` rewrites comments in every test file. Run these two in
sequence, not beside each other.

### Dead defensiveness in the tmux helper

`internal/ui/list_picker_test.go`'s `tmux` helper guards with
`if err != nil && args[0] != "kill-session"`, but no call reaches it with
`kill-session`: the four helper calls are `new-session`, `send-keys`,
`capture-pane` and `resize-window`, and the only kill is the `t.Cleanup` one,
which calls `exec.Command` directly and discards its error. So the condition is
always true and reduces to `if err != nil`.

It predates `fix/tmux-test-session-name` and was flagged by that branch's
worker rather than folded in, correctly, since the todo did not declare it.
Worse than redundant: it implies the helper handles kills, so a reader goes
looking for a path that does not exist. Recorded as `AI-Harness-Notes:` on
`fc5e53d`.

## Done when
- [ ] `scanChunk`'s two scoring rules are asserted directly, with the numbers
- [ ] `countMatches` and `buildMatch` each have a test that asserts their output
- [ ] `Find`'s total-failure branch is covered, including that it returns a
      non-nil error
- [ ] `NewQuery`'s in-place mutation is either tested or removed
- [ ] `scanFile`'s `*fs.PathError` rewrite is asserted — the label replaces the
      fs-relative path
- [ ] `cmd` has a test file, and the chosen seam (or the decision not to build
      one) is stated in the commit message
- [ ] `go test -race ./...` passes
- [ ] The `args[0] != "kill-session"` guard is gone from the tmux helper
- [ ] `go build ./...` and `go vet ./...` pass
