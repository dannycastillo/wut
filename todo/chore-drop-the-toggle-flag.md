# chore: drop the toggle flag and cobra placeholders

- **Priority:** low
- **Branch:** chore/drop-the-toggle-flag
- **Touches:** cmd/root.go, main.go
- **Blocked by:** —

## Goal
No generated placeholder text or dead flags remain in the command setup.

## Why
`cobra init` left a `--toggle` flag and two copyright headers addressed to
`NAME HERE <EMAIL ADDRESS>`. The flag is registered and never read, so it shows
up in `wut --help` as a documented option that does nothing.

## Notes
- The flag is `rootCmd.Flags().BoolP("toggle", "t", false, ...)` at
  `cmd/root.go:96`, inside `init()`. Nothing reads it — `grep -rn toggle
  --include="*.go" .` returns that one line.
- The commented-out `PersistentFlags` example above it is scaffolding too.
- Headers are at the top of `cmd/root.go` and `main.go`. `LICENSE` is empty
  (0 bytes); filling it is a separate decision, not this task.
- No behavior change. If a test starts failing, something else is wrong.

## Done when
- [ ] `grep -rn toggle --include="*.go" .` returns nothing
- [ ] `wut --help` lists no `-t` / `--toggle`
- [ ] No `NAME HERE` or `EMAIL ADDRESS` remains in any `.go` file
- [ ] `go build ./...` and `go vet ./...` pass
