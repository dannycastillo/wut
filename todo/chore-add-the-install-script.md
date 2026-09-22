# chore: add the install script and name the tool

- **Priority:** medium
- **Branch:** chore/add-the-install-script
- **Touches:** harness/*, .harness.conf, AGENTS.md, .claude/*
- **Blocked by:** chore-add-the-integrator, chore-add-the-platform-adapters

## Goal
The harness installs into a repo that has never seen it, and carries a name
that is not a generic word.

## Why
Lifting into other projects is the point; this repo is the test fixture. Max
parallelism on this backlog is six and realistically three, and the backlog
empties in a few sessions — the harness does not pay for itself here alone.

## Notes

### Rename first

`harness` squats a generic name in an unowned `$GIT_DIR` namespace (ADR-07). It
is cheap to rename with one consumer and annoying with two, so it happens here:
the binary, the config file, the state directory, the `Harness-*` trailers, the
role docs and the adapters all move together.

### install.sh

Copies the tree, detects the gate and writes the config, inserts the
marker-delimited AGENTS.md block (or creates AGENTS.md from the template),
installs the hooks into the shared common dir, and wires a named adapter.

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
- [ ] The tool has a distinctive name, applied everywhere including the state
      directory and the commit trailers
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
