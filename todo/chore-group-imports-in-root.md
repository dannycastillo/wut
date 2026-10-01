# chore: separate stdlib and project imports in cmd/root.go

- **Priority:** low
- **Branch:** chore/group-imports-in-root
- **Touches:** cmd/root.go
- **Blocked by:** —

## Goal
`cmd/root.go` imports read as three groups: standard library, this module,
third party.

## Why
The module rename left the two `github.com/dannycastillo/wut/...` imports
sorted into the standard-library block between `fmt` and `os`. gofmt accepts
it, so the gate does not catch it, but it is not the shape Go readers expect.

## Notes
- gofmt sorts within a blank-line-separated group and never moves lines
  across groups, so the fix is adding blank lines, then letting gofmt sort.
- Review note from PR #43 and PR #44; both branches left it for later.

## Done when
- [ ] `cmd/root.go` imports are grouped stdlib, then this module, then
      third party, each group separated by a blank line
- [ ] `gofmt -l cmd/` prints nothing
- [ ] `go build ./...` and `go vet ./...` pass
