# fix: correct the long help text

- **Priority:** medium
- **Branch:** fix/help-text-copy
- **Touches:** cmd/root.go
- **Blocked by:** —

## Goal
`wut --help` describes how the tool actually works today, with no typos.

## Why
The `Long` string at `cmd/root.go:18-40` tells the user to "Store a txt file in
a ~/.wut directory" before anything happens. ADR-02 made that false in `4359aaa`
— `wut` ships 133 snippets embedded in the binary and searches them on every
query, whether or not `~/.wut` exists. The help text is the first thing a new
user reads, and right now it describes a prerequisite that isn't one.

## Notes

- `:19` — "perviously" → "previously"
- `:39` — "easiy" → "easily"
- `:30` — trailing whitespace at end of line
- The substance: say that snippets ship with the tool and work immediately, and
  that `~/.wut/*.txt` is how you add your own. Mention that your own snippets
  rank above the shipped ones (`internal/search/rank.go:19`) — that's behavior a
  user would otherwise have to discover.
- Keep the worked example. It teaches the file format in less space than prose
  would, and the format is otherwise undocumented until the README lands.
- `Short` at `:17` is fine.

Check the rendered output, not the source string — Cobra reflows nothing, so
every line break in the literal is a line break on screen at any terminal width.

## Done when
- [ ] `wut --help` mentions the shipped snippets and that they work with no setup
- [ ] `~/.wut` is described as how to add your own, not as a prerequisite
- [ ] User-snippets-rank-first is stated
- [ ] No typos; no trailing whitespace in the string
- [ ] The output was read as rendered, not just as source
- [ ] `go build ./...` and `go vet ./...` pass
