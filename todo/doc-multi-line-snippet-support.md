# doc: document that snippets can span multiple lines

- **Priority:** low
- **Branch:** doc/multi-line-snippet-support
- **Touches:** cmd/root.go
- **Blocked by:** —

## Goal
`wut`'s help text (`rootCmd.Long` in `cmd/root.go`) says a command in a
`~/.wut` file can span more than one line and is copied with its line breaks
intact.

## Why
`fix/multi-line-snippet-join` made `buildMatch` join a multi-line command's
lines with `\n` instead of concatenating them into a run-on string, so
multi-line snippets are now supported rather than silently broken. Nothing
tells the user that. `cmd/root.go`'s `Long` string is the closest thing this
repo has to the README the original todo's Notes pointed at — there is no
top-level `README.md`.

## Notes
Fits naturally after the existing "Your own snippets rank above the shipped
ones" paragraph, around `cmd/root.go:47`.

## Done when
- [ ] `rootCmd.Long` states that a command can span multiple lines and is
      copied as written
- [ ] `go build ./...` and `go vet ./...` pass
