# chore: fix the module path in go.mod

- **Priority:** medium
- **Branch:** chore/fix-go-mod-module-path
- **Touches:** go.mod, go.sum, main.go, cmd/*.go, internal/search/sources.go, internal/search/golden_test.go, README.md
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
  update every `wut/...` import to match. Today that is `main.go`,
  `cmd/root.go`, `cmd/root_test.go`, `internal/search/sources.go` and
  `internal/search/golden_test.go`; `grep -rn '"wut/' --include='*.go' .`
  is the list.
- `go.mod` and `go.sum` are in `AI_HARNESS_PROTECTED`, so `aih integrate`
  parks this branch and the maintainer merges it by hand. Expected.
- `chore-homebrew-release` also touches `main.go`, `cmd/root.go` and
  `README.md`; the overlapping `Touches` serializes the two. Whichever runs
  second rebases onto the first.
- The repo is private and has no tags, so the remote `go install` check
  cannot run from this branch. Verify locally instead:
  `cd "$(mktemp -d)" && GOFLAGS=-mod=mod go install <repo-path>@<branch-commit>`
  fails before the rename and passes after it only once the repo is public;
  until then, `go build ./...` with the new path and a clean `go vet` is the
  proof. The maintainer runs the remote form after going public.
- `README.md`'s "go install" section goes back to the one-line
  `go install github.com/dannycastillo/wut-command@latest`. Say "needs a
  published tag" next to it until `v0.1.0` exists.

## Done when
- [ ] `go.mod` declares `module github.com/dannycastillo/wut-command`
- [ ] All internal imports updated to match
- [ ] `README.md`'s go install section is updated to the one-line remote form
- [ ] `go build ./...` and `go vet ./...` pass

Maintainer, once the repo is public:
- [ ] `go install github.com/dannycastillo/wut-command@main` succeeds from
      outside the repo
