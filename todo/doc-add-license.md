# doc: add the license and third-party notices

- **Priority:** high
- **Branch:** doc/add-license
- **Touches:** LICENSE, THIRD_PARTY_LICENSES.md, AGENTS.md
- **Blocked by:** —

## Goal
`LICENSE` holds the MIT license text, `THIRD_PARTY_LICENSES.md` reproduces the
license of every dependency that ships inside the binary, and the repo names no
individual outside those two files.

## Why
`LICENSE` is currently 0 bytes. A public repo with an empty license file is
legally "all rights reserved" — nobody can use, fork, or even safely read it
with intent to learn. Homebrew's formula also carries a `license` field, so this
blocks the release work.

## Notes

### The license

MIT. `Copyright (c) 2026 Danny Castillo`. Use the canonical SPDX MIT text
verbatim — no edits, no reflowing.

### Why MIT is safe here

Every one of the 23 modules in the build is permissive, verified against the
license file in each module cache directory:

| License | Modules |
| --- | --- |
| MIT | all three `charm.land/*` v2 packages, all `charmbracelet/*`, `sahilm/fuzzy`, `mattn/go-runewidth`, `rivo/uniseg`, both `clipperhouse/*`, `muesli/cancelreader`, `xo/terminfo`, `lucasb-eyer/go-colorful` |
| BSD-3-Clause | `atotto/clipboard`, `spf13/pflag`, `golang.org/x/sync`, `golang.org/x/sys` |
| Apache-2.0 | `spf13/cobra`, `inconshreveable/mousetrap` |

No copyleft anywhere, so nothing constrains the choice. Neither Apache-2.0
module ships a `NOTICE` file, which is the one Apache obligation that would
otherwise have to propagate — checked directly, only `LICENSE.txt` and `LICENSE`
are present.

### Third-party notices

Go links dependencies statically, so the shipped binary contains their code and
their licenses have to travel with it. `THIRD_PARTY_LICENSES.md` lists every
module, its version, its license, and its copyright line. Generate the list from
the module cache rather than by hand:

```sh
go list -deps -f '{{if .Module}}{{.Module.Path}} {{.Module.Version}}{{end}}' ./... | sort -u
go list -m -f '{{.Dir}}' <module>   # then read its LICENSE
```

Regenerate whenever a dependency is added or bumped.

### Removing the name from elsewhere

`AGENTS.md:70`, `:238` and `:287` say "Danny". Replace with "the maintainer" so
the working agreements read impersonally to an outside contributor. No `.go`
file mentions a name — the Cobra `NAME HERE <EMAIL ADDRESS>` headers went in
`a4a47a8`. Do not add an email address anywhere; the copyright line is name only.

## Done when
- [ ] `LICENSE` contains the unmodified MIT text with the 2026 copyright line
- [ ] `THIRD_PARTY_LICENSES.md` covers all 23 modules with version, license and
      copyright, and was generated from the module cache rather than typed
- [ ] `grep -rn 'Danny' --include='*.md' --include='*.go' .` returns only
      `LICENSE` and `THIRD_PARTY_LICENSES.md`
- [ ] No email address appears in any tracked file
- [ ] `go build ./...` and `go vet ./...` pass
