# chore: fix the errcheck findings lint currently excludes

- **Priority:** medium
- **Branch:** chore/check-lint-errcheck-findings
- **Touches:** cmd/root.go, cmd/root_test.go, internal/search/scan.go, internal/ui/list_picker.go, .golangci.yml
- **Blocked by:** —

## Goal
`golangci-lint run` passes with no path-scoped exclusions in `.golangci.yml`,
because every unchecked error it found now has an explicit decision instead of
a blanket ignore.

## Why
`chore-add-ci` turned on `golangci-lint run` in CI. Its default linter set
(errcheck, gosimple, govet, ineffassign, staticcheck, unused) found four real
unchecked-error sites, but fixing them touched files outside that todo's
`Touches` — one of them, `internal/ui/list_picker.go`, was claimed at the time
by `feat/help-above-results`. Rather than fold unrelated source edits into a CI
todo, `.golangci.yml` excludes `errcheck` for these four paths and this todo
tracks removing that.

## Notes

Four sites, found by running `golangci-lint run ./...` with the exclusion
rules in `.golangci.yml` temporarily removed:

- `cmd/root.go:118` — `fmt.Fprintf(colorprofile.NewWriter(...), ...)` writing
  the "Copied" message. `run` returns `error`; propagate the write's error
  instead of dropping it.
- `cmd/root_test.go:39` — `w.Close()` on the stderr-redirect pipe in
  `withStderr`. It's a test helper with a `*testing.T` in scope; `t.Fatal` on
  a non-nil error is consistent with the rest of the file.
- `internal/search/scan.go:27` — `defer file.Close()` on a file opened
  read-only for scanning. Nothing meaningful to do with a close error here;
  discard it explicitly (`defer func() { _ = file.Close() }()`) rather than
  leaving it for errcheck to flag.
- `internal/ui/list_picker.go:206` — `fmt.Fprint(w, style.Render(row))` inside
  `choiceDelegate.Render`, which implements `list.ItemDelegate` and has no
  error return. Discard explicitly (`_, _ = fmt.Fprint(...)`).

Check `internal/ui/list_picker.go`'s current claimant with
`grep '**Touches:**' todo/*.md` before starting — if `feat/help-above-results`
(or whatever superseded it) is still open, this collides and should run after
it, not alongside it.

## Done when
- [ ] All four sites above have an explicit, deliberate handling of the error
      (propagate, discard, or fail the test), not a silent drop
- [ ] `.golangci.yml`'s `linters.exclusions.rules` no longer lists any of
      these four paths — delete the whole file if nothing else needs it
- [ ] `golangci-lint run` passes with that exclusion removed
- [ ] `go build ./...`, `go vet ./...`, and `go test -race ./...` pass
