# ADR 2026-10-01: The harness is installed, not vendored

- **Status:** Accepted
- **Date:** 2026-10-01

## Context
ai-harness was written in this repo, under `ai-harness/`, and `aih` ran from
`ai-harness/bin/aih`. It has since been extracted to its own repo and is
published through Homebrew as `ai-harness`; 0.2.0 is on this machine. The
vendored copy had fallen behind: no `init --new-trunk`, no `version`, and it
read `AI_HARNESS_PUSH` where 0.2.0 reads `AI_HARNESS_PUSH_TRUNK`.

Two gates, `shellcheck` and `shellsize`, existed only to check the vendored
shell.

## Decision
This repo runs the machine-installed `aih` and carries none of the harness
itself. `ai-harness/` is deleted. `.ai-harness.conf` is the only harness
file in the repo and declares Go gates only: build, vet, fmt, test, lint.

AGENTS.md points at `aih protocol`, `aih role <role>` and
`aih <verb> --help` rather than at files in the tree.

The harness ADRs (ADR-07 to ADR-10 and the two dated 2026-09-23) stay. They
record decisions made here and the installed tool still honours them.

## Alternatives considered
- **Keep the vendored copy and sync it by hand** — two sources of truth, and
  the copy was already behind.
- **Pin the harness as a git submodule** — a submodule is still a copy to
  update, and `brew upgrade` is the update path the harness project chose.
- **Delete the harness ADRs too** — ADRs are append-only records (AGENTS.md);
  the decisions still govern how this repo is worked.

## Consequences
- `aih doctor` reports which version runs; the repo cannot drift from it.
- A harness change needs a release and `brew upgrade`, not a commit here.
- The gate no longer lints shell, because there is no shell to lint.
- A machine without `ai-harness` installed cannot run the gate or the loop.
