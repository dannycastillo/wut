# chore: trim the comments to a standard

- **Priority:** high
- **Branch:** chore/trim-the-comments
- **Touches:** AGENTS.md, every `.go` file in the repo
- **Blocked by:** —

## Goal
AGENTS.md carries a Comments section, and every `.go` file matches it: comments
explain the surprising, not the ordinary.

## Why
The repo is going public as a portfolio piece, so a stranger will read the code.
Right now roughly a third of the comment lines argue a design rather than flag a
hazard, and prose that explains *why* drifts the moment the code moves. Writing
the rule down first means later branches don't reintroduce what this one removes.

## Notes

Two commits on one branch, the same shape an ADR uses to ride with its code:

1. `doc: add a comment standard to AGENTS.md`
2. `chore: trim comments to the standard`

### The standard to write

A comment earns its place when the code is surprising — a workaround, a measured
constant, an upstream bug, an invariant two files share, a non-obvious ordering.
The *why* behind a design belongs in an ADR or a commit message, where it can't
drift out of sync with the code it describes. Go's doc-comment convention stays:
exported identifiers and package docs keep theirs, stated plainly.

Note this does not change how work gets explained in review or in chat — only
what the source file carries.

### Delete outright — these aren't prose to trim, they're noise

- `cmd/root.go:14` and `:50-51` — verbatim Cobra generator boilerplate
  ("represents the base command when called without any subcommands"),
  stylistically foreign to everything else in the repo
- `internal/search/search.go:26` — `// 'args' captures all arbitrary positional
  arguments` restates the parameter
- `internal/search/search.go:64` — `// 3. Close the channel…`, orphaned
  numbering with no step 1 or 2
- `internal/search/scan.go:73-75` — a scoring table duplicating the two literals
  directly below it
- `internal/search/scan.go:95` and `:101` — `// Step 1:` / `// Step 2:`
  tutorial narration, a style used nowhere else
- `internal/search/scan.go:106-107` — `// Optional: Delete the item…` followed
  by commented-out `// delete(seen, item)`

### Trim to one line

25 multi-sentence prose blocks in production code and 11 more in the test files.
The densest: `internal/ui/list_picker_test.go:43-49` (7 lines, 2 paragraphs) and
`internal/search/rank_test.go:55-59`. Note `list_picker_test.go:118-121`
duplicates `list_picker.go:258-262` almost verbatim — one of the two goes.

### Keep — this is what the rule exists to protect

- All package docs, and add the three that are missing: `package ui`,
  `package cmd`, `package main`
- `internal/ui/list_picker.go:94-102` — the terminal pending-wrap guard. Nobody
  reconstructs that from the code
- `internal/ui/list_picker.go:25-26` — empirically measured bubbles/list row
  floors
- `internal/search/scan.go:17-18` — why `*fs.PathError.Path` is rewritten
- `internal/search/rank.go:23-24` — why the tiebreak exists at all
  (`sort.Slice` is not stable, results arrive in goroutine order)

### Ordering

This touches every `.go` file, so per AGENTS.md's Touches rule it cannot run
beside any other Go branch. Land it early so later work is written to the
standard rather than retrofitted.

## Done when
- [ ] AGENTS.md has a Comments section stating when a comment earns its place
- [ ] Every item in the "delete outright" list above is gone
- [ ] No comment in a `.go` file runs longer than the code it describes, except
      the four listed under Keep
- [ ] `package ui`, `package cmd` and `package main` each have a package doc
- [ ] `go test ./...` passes — the trim touches test files too
- [ ] `gofmt -l .` is empty
- [ ] `go build ./...` and `go vet ./...` pass
