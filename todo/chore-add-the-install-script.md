# chore: add the install script and name the tool

- **Priority:** medium
- **Branch:** chore/add-the-install-script
- **Touches:** harness/*, ai-harness/*, .harness.conf, .ai-harness.conf, AGENTS.md, .claude/*
- **Blocked by:** chore-add-the-platform-adapters

## Goal
The harness installs into a repo that has never seen it, is named
`ai-harness`, and is run as `aih`.

## Why
Lifting into other projects is the point; this repo is the test fixture. Max
parallelism on this backlog is six and realistically three, and the backlog
empties in a few sessions — the harness does not pay for itself here alone.

## Notes

### Rename first

`harness` squats a generic name in an unowned `$GIT_DIR` namespace (ADR-07). It
is cheap to rename with one consumer and annoying with two, so it happens here.

Two names, one rule: **the project is `ai-harness`; the command is `aih`;
everything else follows the project.** `aih` appears in exactly one place, the
word a human or agent types. Everything a reader browses or greps says
`ai-harness`. This is the kubectl/Kubernetes and rg/ripgrep convention.

| Thing | Name |
| --- | --- |
| the tool, in prose and titles | AI Harness, written `ai-harness` |
| the command, and the only command | `aih` |
| vendored directory | `ai-harness/`, so the binary is `ai-harness/bin/aih` |
| config file | `.ai-harness.conf` |
| state directory | `$(git rev-parse --git-common-dir)/ai-harness/` |
| environment variables | `AI_HARNESS_TRUNK` and the rest; a hyphen is illegal there |
| commit trailers | `AI-Harness-Todo`, `AI-Harness-Worker`, … |
| AGENTS.md marker | `<!-- ai-harness:begin -->` … `<!-- ai-harness:end -->` |
| role docs, README | `ai-harness/roles/`, `ai-harness/README.md` |
| lock, event and log files | unchanged; they live under the state directory |

Do not ship an `ai-harness` command as well. Two names for one executable
means every doc still picks one and agents copy whatever the docs say. The
README says once that `aih` is short for ai-harness.

Checked 2026-09-23: `aih` is on no PATH here, in no Homebrew formula, Debian
package or crate, and has no GitHub repo; npm holds an abandoned library with
no binary and PyPI an empty placeholder. `ai-harness` is free on all of them.

### The launcher

The vendored tree stays the source of truth and each worktree runs its own
copy, so `aih` on PATH is a launcher, not an install:

```sh
#!/bin/sh
exec "$(git rev-parse --show-toplevel)/ai-harness/bin/aih" "$@"
```

A symlink does not work: `bin/aih` resolves its home from its own path and
refuses to run against another tree. `install.sh` drops the launcher into
`~/.local/bin` when no `aih` is on PATH, and `doctor` prints that one command
when the launcher is missing. The launcher never changes, so it is never
upgraded; the tree upgrades per repo through git.

The loop controls the environment of every agent it starts, so make it own
PATH too: `harness_agent_spawn` prepends the worktree's own `ai-harness/bin`
before exec, and a dispatched agent finds `aih` with no launcher installed at
all. That is what makes the launcher a convenience for humans rather than a
requirement of the system.

### install.sh

Copies the tree, detects the gate and writes the config, inserts the
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
- [ ] The command is `aih` and nothing else; every file, directory, variable,
      trailer and marker is named `ai-harness` per the table, and
      `git grep -iw harness` outside prose finds nothing left over
- [ ] The launcher runs `aih doctor` from the main checkout and from a linked
      worktree, and a dispatched agent finds `aih` with the launcher absent
- [ ] `doctor` names the launcher command when `aih` is not on PATH
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
