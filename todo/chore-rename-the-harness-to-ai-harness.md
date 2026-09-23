# chore: rename the harness to ai-harness, run as aih

- **Priority:** high
- **Branch:** chore/rename-the-harness-to-ai-harness
- **Touches:** harness/*, ai-harness/*, .harness.conf, .ai-harness.conf, AGENTS.md, todo/*
- **Blocked by:** —

## Goal
The tool is named `ai-harness` everywhere a reader sees it, the command is
`aih`, and `aih` reaches PATH through a launcher that the loop never needs.

## Why
`harness` squats a generic name in an unowned `$GIT_DIR` namespace (ADR-07),
and `harness` is not on PATH at all, so the first unattended run would have
started a worker whose prompt names a command it cannot find. Renaming is
cheap with one consumer and annoying with two, so it happens before the
harness is lifted anywhere.

## Notes

### Two names, one rule

**The project is `ai-harness`; the command is `aih`; everything else follows
the project.** `aih` appears in exactly one place, the word a human or agent
types. Everything a reader browses or greps says `ai-harness`. This is the
kubectl/Kubernetes and rg/ripgrep convention.

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
| shell functions | `ai_harness_*`, including `ai_harness_gate_*` in the conf |
| lock, event and log files | unchanged; they live under the state directory |

The function prefix moves too. It is a painful rewrite and it is the point:
when this is its own project, nothing in it may answer to the bare word
`harness`. The standalone word goes away everywhere except prose, and prose
says "the harness" only where "AI Harness" would read badly.

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
refuses to run against another tree. `doctor` prints the launcher, and where
to put it, when `aih` is not on PATH. Installing it is `install.sh`'s job
(chore-add-the-install-script); for now a human copies it.

The loop controls the environment of every agent it starts, so make it own
PATH too: `harness_agent_spawn` prepends the worktree's own `ai-harness/bin`
before exec, and a dispatched agent finds `aih` with no launcher installed at
all. That is what makes the launcher a convenience for humans rather than a
requirement of the system.

### What moves

- `git mv harness ai-harness` and `git mv ai-harness/bin/harness ai-harness/bin/aih`.
  `bin/aih` derives its home from its own path and refuses a foreign tree;
  keep both behaviours, and update the message that suggests a shell function.
- `git mv .harness.conf .ai-harness.conf`, and every `HARNESS_*` variable in
  it and in the tree becomes `AI_HARNESS_*`, `HARNESS_GATE_TOOLS_*` included.
- Every `harness_*` function becomes `ai_harness_*`, the `harness_gate_*`
  and `harness_gate_build`-style functions in the conf included, and the
  loop's `harness_agent_spawn` with them. A mechanical `sed` on word
  boundaries does most of it; read the diff for the lock names and event
  words that share the prefix in strings.
- The state directory name, the trailer prefix (`lib/integrate.sh`, `verbs/log.sh`),
  the AGENTS.md marker and the checksum `doctor` verifies against it.
- Every `harness <verb>` in `AGENTS.md`, `ai-harness/README.md`,
  `ai-harness/roles/*.md`, the worker and reviewer prompts in
  `verbs/dispatch.sh`, and the hints verbs print (`harness status`,
  `harness doctor --repair`, …) becomes `aih <verb>`.
- The `shellcheck` and `shellsize` gates in the conf list the tree's paths.
- Todos that reserve `harness/*` or cite `.harness.conf` in Touches or Notes:
  chore-add-ci, chore-add-the-install-script, chore-add-the-platform-adapters,
  chore-raise-test-coverage, fix-a-hand-merge-leaves-its-submission-queued,
  fix-the-donewhen-classifier-classifies-nothing.
- ADRs are append-only and stay as written; `harness` there is history.

The AGENTS.md block is edited here on purpose, so recompute the checksum in
the marker rather than leaving `doctor` to report drift.

## Done when
- [ ] `ai-harness/bin/aih doctor` passes from the main checkout and from a
      linked worktree
- [ ] `git grep -nwi harness -- . ':!docs/' ':!todo/chore-rename*'` finds only
      prose; no path, command, variable, function, trailer or marker
- [ ] `git grep -n 'harness_' -- . ':!docs/'` finds nothing
- [ ] `aih check --selftest` passes, and `aih gate --full` is green
- [ ] With no `aih` on PATH, `aih doctor` output names the launcher and where
      to put it, and a worker started by `aih dispatch worker --detach` with a
      stub `AI_HARNESS_AGENT_CMD` finds `aih` on its PATH
- [ ] The launcher above, installed in `~/.local/bin`, runs `aih status` from
      the main checkout and from a linked worktree
- [ ] The six todos listed reserve and cite the new paths
- [ ] `go build ./...` and `go vet ./...` pass
