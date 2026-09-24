# chore: fix the module path in go.mod

- **Priority:** medium
- **Branch:** chore/fix-go-mod-module-path
- **Touches:** go.mod, go.sum
- **Blocked by:** —

## Goal
`go.mod` declares `module wut`. `go install github.com/dannycastillo/wut-command@<version>`
works from a clean shell once the repo is public.

## Why
Discovered while writing `README.md` (`doc/write-the-readme`): `go install`
resolves a remote path by fetching the module and checking that its `go.mod`
declares that same path. Since `go.mod` says `module wut` instead of
`module github.com/dannycastillo/wut-command`, the fetch fails with:

```
go: github.com/dannycastillo/wut-command@main: version constraints conflict:
	github.com/dannycastillo/wut-command@<pseudo-version>: parsing go.mod:
	module declares its path as: wut
	        but was required as: github.com/dannycastillo/wut-command
```

This isn't a privacy artifact — it fails the same way once the repo is
public. It's also why the README's "go install" section documents cloning
first (`go install .`) rather than the one-line remote form most Go CLIs
support; that workaround should stop being necessary once this lands.

## Notes
- Rename the module directive to `github.com/dannycastillo/wut-command` and
  update the one internal import (`wut/cmd` in `main.go`, plus any `wut/...`
  imports under `internal/` and `cmd/`) to match.
- Verify with the actual failing case: from outside this repo,
  `go install github.com/dannycastillo/wut-command@<a real commit or tag>`
  should succeed once pushed.
- `README.md`'s "go install" section should go back to a plain
  `go install github.com/dannycastillo/wut-command@latest` once this is
  fixed and a tag exists — update it there too.

## Done when
- [ ] `go.mod` declares `module github.com/dannycastillo/wut-command`
- [ ] All internal imports updated to match
- [ ] `go install github.com/dannycastillo/wut-command@<commit>` succeeds
      from outside the repo
- [ ] `README.md`'s go install section is updated to the one-line remote form
- [ ] `go build ./...` and `go vet ./...` pass
