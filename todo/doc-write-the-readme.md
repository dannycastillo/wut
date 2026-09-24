# doc: write the README

- **Priority:** medium
- **Branch:** doc/write-the-readme
- **Touches:** README.md
- **Blocked by:** doc-add-license

## Goal
`README.md` shows what the tool does, how to install it, how to use it, and how
to add your own snippets — enough that a stranger can go from the repo page to a
working install without asking a question.

## Why
There is no README. The repo page currently shows a file listing and nothing
else. This is the portfolio piece's front door.

## Notes

### Order, roughly

1. One line saying what it is: search your own command-line notes from the
   terminal and copy the result to the clipboard.
2. Install — Homebrew first once `chore/homebrew-release` lands, `go install`
   second, build-from-source third.
3. Usage — `wut <words>`, the picker keys, what enter does.
4. Adding your own snippets — the `~/.wut/*.txt` format with a real example,
   and that your own snippets rank above the shipped ones.
5. What ships — roughly 200 snippets across the topic files, embedded in the
   binary, working with no setup.
6. License, one line, linking `LICENSE` and `THIRD_PARTY_LICENSES.md`.

### Things worth getting right

- **The format section has to be exact.** Three lines per snippet: `# desc`,
  the command, a blank line. A user who gets this wrong sees silently wrong
  results rather than an error, so show it rather than describe it.
- **CI badge** at the top if `chore/add-ci` has landed.
- Do not document the architecture. `docs/` holds the ADRs and they're better
  at it; a link to `docs/` is enough for a reader who wants that.
- Do not write a roadmap. An unfulfilled one ages worse than no README section.
- Keep the developer section to what someone needs to run the tests: `go test
  ./...`, and a pointer to AGENTS.md for how work is organized.

### Blocked on the license

The README links it. Everything else can be drafted before it lands.

## Done when
- [ ] `README.md` exists
- [ ] Install instructions cover Homebrew (or note it's coming), `go install`,
      and building from source
- [ ] The `~/.wut` snippet format is shown as a literal example
- [ ] User-snippets-rank-above-seed is stated
- [ ] License section links `LICENSE` and `THIRD_PARTY_LICENSES.md`
- [ ] Every command in the README was run and works from a clean shell
- [ ] No name or email beyond what the license carries
- [ ] `go build ./...` and `go vet ./...` pass
