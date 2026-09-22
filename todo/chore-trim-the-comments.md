# chore: trim the comments to a standard

- **Priority:** high
- **Branch:** chore/trim-the-comments
- **Touches:** ALL
- **Blocked by:** —

## Goal
Every `.go` file matches AGENTS.md's Comments section: comments explain the
surprising, not the ordinary.

## Why
The repo is going public as a portfolio piece, so a stranger will read the code.
Roughly a third of the remaining comment lines argue a design rather than flag a
hazard, and prose that explains *why* drifts the moment the code moves. The rule
is already written, so this is applying it, not deciding it.

## Notes

### Already done

The standard is written: AGENTS.md has a **Comments** section as of
`fix/resize-redraw`, which also trimmed `internal/ui/list_picker.go` (110
comment lines to 56), `internal/ui/list_picker_test.go` (112 to 64) and three
blocks in `cmd/root.go`. What remains is applying it to the rest of the repo.

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

The multi-sentence prose blocks left in `internal/search`, `internal/seed`,
`main.go` and the parts of `cmd/root.go` not listed above. The densest remaining
is `internal/search/rank_test.go:55-59`.

### Keep — this is what the rule exists to protect

- All package docs, and add the three that are missing: `package ui`,
  `package cmd`, `package main` — `internal/ui` still needs its one
- `internal/search/scan.go:17-18` — why `*fs.PathError.Path` is rewritten
- `internal/search/rank.go:23-24` — why the tiebreak exists at all
  (`sort.Slice` is not stable, results arrive in goroutine order)

### Ordering

Still touches most `.go` files, so per AGENTS.md's Touches rule it cannot run
beside another Go branch. The standard itself has landed, so later work is
already written to it.

## Done when
- [ ] Every item in the "delete outright" list above is gone
- [ ] No comment in a `.go` file runs longer than the code it describes, except
      those listed under Keep
- [ ] `package ui`, `package cmd` and `package main` each have a package doc
- [ ] `go test ./...` passes — the trim touches test files too
- [ ] `gofmt -l .` is empty
- [ ] `go build ./...` and `go vet ./...` pass
