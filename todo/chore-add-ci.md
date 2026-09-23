# chore: run the standard Go checks in CI

- **Priority:** high
- **Branch:** chore/add-ci
- **Touches:** .github/workflows/ci.yml, .golangci.yml, README.md, .ai-harness.conf
- **Blocked by:** —

## Goal
Every push to `main` and every pull request runs build, vet, format, race-enabled
tests and a linter, and a failure is visible as a red check on the commit.

## Why
The repo has no `.github/` directory at all. On a public portfolio repo, a green
check is the first thing a reader trusts and the cheapest signal to provide.
Landing CI before the rest of the backlog means every branch after it proves
itself the same way, instead of each one being spot-checked by hand.

## Notes

### Jobs

| Job | Command | Why it's here |
| --- | --- | --- |
| build | `go build ./...` | AGENTS.md already requires it per-commit |
| vet | `go vet ./...` | same |
| fmt | `gofmt -l .`, fail if output is non-empty | `gofmt -l` exits 0 even when it lists files, so test the output, not the status |
| test | `go test -race ./...` | see below |
| lint | `golangci-lint run` | |

The `lint` gate is defined in `.ai-harness.conf` but deliberately left out of
`AI_HARNESS_GATES`, because a declared gate whose tool is absent is a hard
failure. Installing golangci-lint is what makes declaring it honest, so adding
`lint` to that list belongs to this todo.

`-race` is the one worth arguing for: `Find` at `internal/search/search.go:48-69`
fans out a goroutine per file over an unbuffered result channel and a buffered
error channel, closed by a third goroutine after `wg.Wait()`. Nothing currently
proves that's clean, and a data race there would be intermittent and awful to
debug from a bug report.

### Setup

- `actions/checkout` and `actions/setup-go`, both pinned to a major version tag.
- Read the Go version from `go.mod` (`go-version-file: go.mod`) so CI can't
  drift from the toolchain — currently `1.26.5`.
- Enable setup-go's module cache; the graph is 23 modules and uncached restores
  dominate the run.
- `golangci-lint` via the official action. Start from its default linter set
  plus `errcheck` and `staticcheck`; add a `.golangci.yml` only if the defaults
  produce noise worth suppressing, and if they flag something real, fix it here
  rather than disabling the linter.
- `permissions: contents: read` at the workflow level.

### Not in scope

No coverage threshold. `cmd` is at 0.0% and `internal/search` at 34.3% today, so
a gate would block every merge until `chore/raise-test-coverage` lands. Revisit
after it does. Release automation is `chore/homebrew-release`, a separate file.

### Badge

Add the workflow status badge to README.md if a README exists when this lands;
otherwise `doc/write-the-readme` picks it up.

## Done when
- [ ] `.github/workflows/ci.yml` runs on `push` to `main` and on `pull_request`
- [ ] It runs build, vet, `gofmt -l` (failing on non-empty output),
      `go test -race ./...`, and `golangci-lint run`
- [ ] The Go version comes from `go.mod`, not a hardcoded string
- [ ] All actions are pinned to at least a major version tag
- [ ] The workflow passes on this branch before the merge is requested
- [ ] `go test -race ./...` passes locally — CI must not be the first place it runs
- [ ] `go build ./...` and `go vet ./...` pass
