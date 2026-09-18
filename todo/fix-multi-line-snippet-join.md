# fix: a multi-line snippet loses its line breaks

- **Priority:** low
- **Branch:** fix/multi-line-snippet-join
- **Touches:** internal/search/scan.go, internal/search/scan_test.go
- **Blocked by:** —

## Goal
A snippet whose command spans more than one line copies to the clipboard as
something that runs.

## Why
`buildMatch` at `internal/search/scan.go:114-127` appends each command line onto
the previous with `result.Cmd += line` — no newline, no space, no separator. A
two-line snippet becomes one run-on string, and `cmd/root.go:96` puts that on
the clipboard. The user pastes it and gets a syntax error with no clue why.

No shipped snippet triggers it today: all 133 are exactly one command line. But
`~/.wut` is user-authored and nothing validates it, and
`feat/expand-seed-snippets` adds roughly 70 more chances to introduce one by
accident.

## Notes

The same concatenation runs for `Desc`, which is less harmful but equally
unintended — a description is one `#` line by construction.

The real question is what a multi-line snippet should mean, and it's worth
deciding rather than patching:

- **Join with `\n`** — treat the lines as a literal multi-line command. Correct
  for a heredoc or a `for` loop; the picker only shows one row's worth, so the
  user copies more than they can see.
- **Join with ` `** — treat them as one wrapped command. Wrong for anything
  where a newline is syntax.
- **Reject the snippet and warn** — `Find` already has a warnings channel for
  exactly this kind of "this file has a problem" report, and it would tell the
  user their file is malformed instead of silently misbehaving.

Whichever wins, the decision belongs in the commit message. If the answer is
that multi-line snippets are supported, the README's format section and
`feat/expand-seed-snippets`'s format rule both need to say so.

`fstest.MapFS` makes this trivial to test — `scan_test.go` already uses it.

## Done when
- [ ] A two-line command in a snippet produces a `Cmd` that is correct under the
      chosen rule, not a run-on string
- [ ] A test covers it, built on `fstest.MapFS`
- [ ] `Desc` concatenation is handled consistently with `Cmd`
- [ ] The chosen behavior is stated in the commit message
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
