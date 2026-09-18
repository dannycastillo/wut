# feat: read snippets from ~/.wut

- **Priority:** high
- **Branch:** feat/read-from-wut-dir
- **Touches:** cmd/root.go
- **Blocked by:** —

## Goal
`wut <query>` finds snippets from every `*.txt` under `~/.wut`, run from any
directory.

## Why
`listFiles()` returns a hardcoded relative `internal/data.txt`, so the binary
only works with the repo root as cwd:

```
$ cd /tmp && wut directory size
Error: open internal/data.txt: no such file or directory
```

The long help already documents `~/.wut` as the location. The tool does not do
what its own `--help` says it does.

## Notes
- `listFiles() []string` is `cmd/root.go:178`. Its callers don't care where the
  paths come from — `searchCoordinator` only ranges over them and hands each to
  `scanFile`. The change is contained to that function plus its signature if it
  starts returning an error.
- `~/.wut` does not exist on this machine. Creating it is out of scope; handling
  its absence is not.
- **The empty-list path is a trap.** With no files, `wg.Add(0)` closes the
  channels immediately, `finalResults` and `scanErrs` are both empty, and
  `len(scanErrs) == len(files)` is `0 == 0` — true. `errors.Join()` with no
  arguments returns `nil`, so the command exits 0 having printed nothing at all.
  Verified. Don't let a missing `~/.wut` land there.
- Use `os.UserHomeDir()`, not `os.Getenv("HOME")`.
- The parser in `scanFile` splits on `\n#`, so the first chunk of a file only
  matches if the file starts with `#`. Unchanged by this task, just don't be
  surprised by it.

## Done when
- [ ] Every `*.txt` under `~/.wut` is searched
- [ ] Running from a directory other than the repo root returns results
- [ ] A missing or empty `~/.wut` prints one actionable line naming the path,
      and does not exit silently
- [ ] An unreadable single file still degrades to a warning, as today
- [ ] `go build ./...` and `go vet ./...` pass
