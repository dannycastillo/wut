# ADR-02: Seed snippets ship embedded in the binary

- **Status:** Accepted
- **Date:** 2026-09-18

## Context
Snippets used to come from a hardcoded relative `internal/data.txt`, so the
binary only worked with the repo root as cwd. Reading `~/.wut` instead fixes
that, but leaves a freshly installed `wut` with nothing to search and an error
on its first run — the user has to author a file in a format they have not seen
before they can tell whether the tool is worth using.

## Decision
`internal/seed/*.txt` holds a curated snippet set, one file per topic, compiled
into the binary with `//go:embed`. `listFiles` returns the seed set followed by
every `*.txt` under `~/.wut`, and both are searched on every query. A missing
`~/.wut` is the ordinary state of a fresh install, not an error.

## Alternatives considered
- **Copy the seed files into `~/.wut` on first run** — the binary would write to
  the user's home unprompted, and a deleted `git.txt` is then indistinguishable
  from one not yet seeded.
- **Search the seed set only while `~/.wut` is empty** — the shipped snippets
  would vanish the moment the user wrote a single file of their own.
- **Ship the seed files on disk next to the binary** — `go install` puts a
  binary on `$PATH` and nothing beside it.

## Consequences
- `go install` yields a working tool. There is no setup step to document.
- The seed set is source: it is reviewed, diffed, and versioned with the code.
- `//go:embed *.txt` fails the build when that directory holds no `.txt` files,
  so a binary with nothing to search cannot be produced by accident.
- Editing a shipped snippet means copying it into `~/.wut` first. A user who
  does that gets both copies in their results.
- `scanFile` reads through `fs.FS` rather than `os.Open`, which is what lets one
  code path serve embedded and on-disk files.
