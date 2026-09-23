# ADR 2026-09-23: The harness installs no git hooks

- **Status:** Accepted
- **Date:** 2026-09-23

## Context
Trunk is written only by `harness integrate` (ADR-10). Every other rule in the
harness is enforced by a verb, because the verb is the only way to do the
thing. This one is different: git itself offers `git merge`, and the reviewer
is a headless agent with a shell in the trunk checkout.

The first cut of `chore-retire-the-human-merge-gate` added `pre-commit` and
`pre-merge-commit` hooks that refused a write to trunk unless
`HARNESS_ALLOW_TRUNK=1`, installed by `doctor --repair` as symlinks into the
repo's `.git/hooks/`.

## Decision
The harness ships no hooks and never writes into `.git/hooks/`. The rule stays
a sentence in AGENTS.md, which the reviewer reads first and whose role doc
ends with exactly one `integrate --continue` command.

Going around it is detected rather than prevented: a merge commit with no
`Harness-*` trailers is shown by `harness log` as `by hand`.

## Alternatives considered
- **The hooks as built** — sixty lines across four files, a variable on every
  hand merge, and a symlink into `.git/hooks/` that fails to install in any
  repo already using husky or the pre-commit framework, which is the kind of
  repo the harness is meant to be lifted into. All to stop a slip, since an
  agent that decides to merge by hand reads the refusal, which names the
  variable.
- **`core.hooksPath` pointing at `harness/hooks/`** — one config line and no
  symlink, but it silently disables every hook the project already has.
- **Refuse in the hook without naming the override** — moves the variable into
  the README, where the same agent finds it with one grep.

## Consequences
- A rogue merge is possible and visible, not impossible. Its recovery is the
  one every red trunk has: revert the `--no-ff` merge commit as a unit.
- `doctor --repair` changes only `.git/harness/`, never git's own behaviour.
- Nothing about hooks stands between the harness and a repo that has its own.

## If a guard is ever needed
Add it when a rogue merge has actually happened, shaped by what happened.
Options, cheapest first:

- **Branch protection on the remote.** Free, outside the harness, and covers
  the push side entirely. Trunk is local today (`HARNESS_PUSH=no`); the moment
  it is pushed by the loop, this is the first thing to turn on.
- **A `pre-merge-commit` hook in `.harness.conf`, opt-in.** The config already
  holds project-specific shell. A `HARNESS_HOOKS=yes` switch could have
  `doctor --repair` append a call to the harness's check at the end of an
  existing hook rather than replace it, and `doctor` report when it is absent.
- **A post-merge assertion instead of a pre-merge refusal.** `run` already
  reads `git log --first-parent`. A merge on trunk without trailers, made while
  the loop is running, can park the queue with `@trunk rogue-merge` and name
  the commit, so the human sees it within one poll interval rather than at the
  next `harness log`.
