# chore: add the install script

- **Priority:** medium
- **Branch:** chore/add-the-install-script
- **Touches:** ai-harness/*, .ai-harness.conf, AGENTS.md, .claude/*
- **Blocked by:** chore-rename-the-harness-to-ai-harness, chore-add-the-platform-adapters

## Goal
`ai-harness` installs into a repo that has never seen it.

## Why
Lifting into other projects is the point; this repo is the test fixture. Max
parallelism on this backlog is six and realistically three, and the backlog
empties in a few sessions — the harness does not pay for itself here alone.

## Notes

### The name is settled

`ai-harness` is the project, `aih` is the command, and every file, variable,
trailer and marker follows the project; the table and the launcher are in
chore-rename-the-harness-to-ai-harness, which lands first. This todo only
installs what that one names.

### install.sh

Copies the `ai-harness/` tree, detects the gate and writes the config, inserts the
marker-delimited AGENTS.md block (or creates AGENTS.md from the template),
installs the launcher if needed, and wires a named adapter. It installs no
git hooks (adr-2026-09-23-the-harness-installs-no-git-hooks).

Detection, in order of preference: `go.mod`; `package.json` scripts that
actually exist; `Cargo.toml`; `pyproject.toml` tools that are actually declared;
`Makefile` targets. Nothing recognized means an empty gate and a `doctor` that
fails loudly.

Always print the generated config and require `--yes` or an interactive
confirm. **Never guess a gate silently** — a wrong gate is worse than no gate,
because it discredits every result the harness reports afterwards.

`--upgrade` replaces the tree, refreshes the AGENTS.md block only if its
checksum still matches, and never touches the config.

### The portable boundary

Portable: the git workflow, the prefixes, naming, the ADR protocol, the todo
protocol, the parallel section. Project-owned: the gate (ADR-09) and the
Comments section, whose doc-comment carve-out is Go-specific and is not the
harness's business.

### Verify by installing

Into a scratch repo with no AGENTS.md, and into one with an unrelated AGENTS.md
that must come back unharmed.

## Done when
- [ ] It installs the launcher into `~/.local/bin` when no `aih` is on PATH,
      and leaves an existing one alone
- [ ] `install.sh` produces a working harness in a scratch Go repo
- [ ] In a repo it cannot classify, it produces an empty gate and a `doctor`
      that fails with a readable reason
- [ ] It prints the generated config and refuses to proceed unconfirmed
- [ ] It inserts the AGENTS.md block, or creates AGENTS.md when absent, without
      disturbing surrounding sections
- [ ] `--upgrade` leaves the config alone and reports a modified block instead
      of overwriting it
- [ ] `doctor` passes in the installed repo
- [ ] `sh -n` passes on every shell file
- [ ] `go build ./...` and `go vet ./...` pass
