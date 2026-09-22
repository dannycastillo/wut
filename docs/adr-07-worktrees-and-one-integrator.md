# ADR-07: Parallel work runs in worktrees under one integrator

- **Status:** Accepted
- **Date:** 2026-09-21

## Context
`todo/` holds thirteen open items and the repo has one maintainer. Three rules
written for one agent at a time now cap throughput: merging waits for approval
in chat, so every branch queues behind one person; a todo carries no status
field, deliberately, so two agents can claim the same one; and there is one
working tree, so two agents overwrite each other.

## Decision
One todo, one branch, one worktree under `../wut-command-worktrees/`.

A claim is `git worktree add -b <branch>`. Git's ref lock picks the winner:
six concurrent racers on one branch produce one success and five exits of 128.
Touches globs are reserved separately, under a `mkdir` lock, because two agents
claiming *different* todos that overlap on paths both win the git race.

Coordination state lives in `$(git rev-parse --git-common-dir)/harness/`:
shared by every worktree, and untrackable rather than ignored, because git
excludes any path with a `.git` component. Only `--git-common-dir` is shared;
the near-miss spellings are a hazard the code carries a comment for.

Trunk is discovered from `git worktree list --porcelain`, stays in the root
checkout, and the integrator locks it only while merging. A dirty root parks
the queue rather than being cleaned.

Three roles: worker, reviewer, integrator. The session that writes a diff
neither reviews nor merges it. The integrator never rebases — the worker does,
before submitting.

A merge is automatic only on a green baseline gate, a clean mechanical check,
verified **Done when** boxes, a passing review, no behavioural conflict, and a
green post-merge gate. Anything else parks for a human.

## Alternatives considered
- **Merge detached, advance trunk with a compare-and-swap `update-ref`** — moves
  HEAD without the root's index or worktree, so a clean tree reports staged
  deletions of everything the merge added, and committing there reverts it.
- **The integrator rebases each branch** — the branch is checked out in the
  worker's worktree, so this destroys the tree the worker needs to fix a
  rejection.
- **State in `refs/harness/*`** — appears in `git log --all` and rides along on
  `push --mirror`.
- **State in a sibling directory** — needs a configured path and orphans when
  the repo moves.
- **A status field on the todo** — already rejected under Todo: two branches
  conflict over it.
- **Keeping the human merge gate** — the bottleneck being removed.

## Consequences
- The root checkout belongs to the integrator while it runs, so uncommitted
  work there stalls merging.
- A crashed worker holds its todo until `harness abandon` releases it: the
  claim is atomic, not self-healing.
- `Touches` is load-bearing. Wrong globs put two agents in one file.
- State sits in an unowned `$GIT_DIR` namespace: `gitrepository-layout(5)`
  describes that directory rather than specifying it, and git claims names only
  for `extensions.*` config keys. A collision costs one `harness doctor
  --repair`, since claims rebuild from `git worktree list`. The path is
  hardcoded, not configurable.
- That state is per machine, and is never cloned, fetched or backed up. The
  durable record is the merge commit's `Harness-*` trailers.
- Trusting the gate means `main` can go red. A `--no-ff` merge commit reverts
  as one unit, which is the recovery.
- Three sessions per item instead of one, and a review round trip in each.
