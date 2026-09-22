# fix: give the tmux test a session name of its own

- **Priority:** medium
- **Branch:** fix/tmux-test-session-name
- **Touches:** internal/ui/list_picker_test.go
- **Blocked by:** —

## Goal
Two `go test` runs with `WUT_TERMINAL_TESTS=1` can run at the same time without
interfering.

## Why
`TestResizeLeavesNothingBehind` at `internal/ui/list_picker_test.go:459` uses a
fixed session name, `wut-resize-test`, and line 467 runs `tmux kill-session` on
it unconditionally before starting. A second concurrent run does not merely
collide with the first — it kills the first mid-assertion, and the failure then
reads as a picker bug rather than a test collision.

It is the only test in the suite that takes a global resource; everything else
uses `t.TempDir()`, and nothing touches the clipboard, the network or the
environment. It matters now because worktrees make two simultaneous test runs
normal (ADR-07), and the gate declares this test as one needing serialization
(ADR-09). A unique name makes that lock a safety net instead of the only thing
holding it together.

## Notes

`fmt.Sprintf("wut-resize-test-%d", os.Getpid())` is enough, and keeps the name
recognizable if a stray session is ever left behind.

Delete the unconditional `kill-session` at line 467: with a unique name there is
nothing to clear first, and it is the line that does the damage. The `t.Cleanup`
kill on line 468 stays — that one is the test tidying up after itself.

## Done when
- [ ] The session name is unique per process
- [ ] The unconditional `kill-session` before `new-session` is gone, and the
      `t.Cleanup` one remains
- [ ] Two concurrent
      `WUT_TERMINAL_TESTS=1 go test ./internal/ui/ -run TestResizeLeavesNothingBehind`
      runs both pass
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
