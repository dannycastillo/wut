# ADR-09: The gate is declared in `.harness.conf`

- **Status:** Accepted
- **Date:** 2026-09-21

## Context
What counts as passing is currently spread across three places. AGENTS.md
mandates `go build ./...` and `go vet ./...` before every commit. Individual
todos add `go test ./...`, `go test -race ./...` and an empty `gofmt -l .`.
`chore-add-ci` proposes build, vet, fmt, race-enabled tests and a linter.

The harness has to run those checks mechanically, and it is meant to be lifted
into other projects. Both of those fail if the commands live in prose.

## Decision
One file, `.harness.conf`, holds everything project-specific. It declares each
gate as a shell function and lists which ones run, in order:

```sh
HARNESS_GATES="build vet fmt test lint"
HARNESS_QUICK_GATES="build vet"

harness_gate_fmt() { out=$(gofmt -l .); [ -z "$out" ] || { printf '%s\n' "$out"; return 1; }; }
```

It is **sourced** as POSIX sh, not parsed. A gate is a command, and `gofmt -l .`
plus "fail when the output is non-empty" is not expressible as a value.

AGENTS.md stops naming commands and says `harness gate --quick` instead. The
same list drives CI, so passing is stated once.

Gates that take a global resource are declared, and serialized across
worktrees: `internal/ui`'s tmux test is one.

`.harness.conf` is a hard stop for the integrator. A diff that touches it is
never merged automatically.

## Alternatives considered
- **A `key=value` file the harness parses** — re-quoting commands back out
  through `eval` is the likeliest place a shell harness grows a bug.
- **Leave the commands in AGENTS.md and read them out of it** — makes a prose
  document load-bearing for execution, and it is the file most often reworded.
- **Detect the toolchain at run time** — a wrong gate is worse than no gate,
  because it discredits every result the harness reports.
- **A `Makefile` as the seam** — imposes a build tool on projects without one.
  The config can prefer `make` where it already exists.

## Consequences
- Sourcing a committed file is arbitrary code execution. That is moot — the
  harness already runs `go build` from the same tree — so the protection that
  matters is that an agent cannot loosen the gate and merge the change.
- AGENTS.md no longer names a language. Its one remaining Go-specific rule is
  the doc-comment carve-out under Comments, which stays project-owned.
- Passing is now described in two places that must agree: this file and CI.
  `chore-add-ci` should read the config rather than restate the job list.
- A project the installer does not recognise gets an empty gate, and `doctor`
  fails until someone fills it in.
- POSIX sh only. macOS ships bash 3.2, so no arrays and no `mapfile`.
