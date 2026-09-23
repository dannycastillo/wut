# ADR-10: A shell loop schedules two roles

- **Status:** Accepted
- **Date:** 2026-09-23
- **Supersedes:** ADR-07

## Context
ADR-07 put parallel work in worktrees under three roles, with a review round
trip per item and a human still merging. Building it showed that a merge is
fully scriptable: `integrate` checks, gates, merges and records, and the one
judgment left is whether **Done when** holds. The plan to have an interactive
agent schedule workers fails two goals at once: it dies with its session, and
it restates `harness plan` in prose.

## Decision
Kept from ADR-07: one todo, one branch, one worktree; git's ref lock decides a
claim and a `mkdir` lock reserves `Touches`; state lives in
`$(git rev-parse --git-common-dir)/harness/` and is disposable; trunk is
discovered, locked only during a merge, and never cleaned; merges are
`--no-ff` and carry `Harness-*` trailers; a park is a human's to resolve.

Two roles, each a one-shot process started with a one-line prompt:

- **worker**: claims, works, rebases, and ends with `harness submit`.
- **reviewer**: reads the packet `integrate --next` prints, verifies each
  Done-when box by reading the diff or running it, and ends with
  `integrate --continue` carrying pass, reject or park.

The session that writes a diff never reviews it. There is no third role.

Verbs own every write to shared state. A role ends by running a verb, and the
verb does the merge, the queueing and the cleanup. No agent runs `git merge`.

A shell loop, `harness run`, schedules. It holds no state: each tick re-derives
everything from the state directory and git, reaps dead agents, dispatches
workers up to `HARNESS_MAX_WORKERS`, and starts one reviewer when a packet is
pending and no reviewer is alive. Agents run under `nohup` with their pids
recorded, so the loop's death leaves them running. One loop per repo, by lock.

Dispatch is at most once. A worker that exits without submitting, a park and a
reject are all terminal until a human acts. The loop kills an agent that runs
past `HARNESS_AGENT_TIMEOUT`.

## Alternatives considered
- **An agent orchestrates** — dies with its session, duplicates `plan`, and
  spends tokens on every tick.
- **Three roles** — a second judgment at double the wall-clock, when most of
  review is already mechanical in `check`.
- **The reviewer merges with git** — every invariant moves from code into a
  prompt.
- **Retry a failed worker** — unbounded spend on a stuck todo, and retry state
  the loop would have to keep.
- **File events instead of polling** — POSIX sh has no portable watcher.

## Consequences
- Spend is bounded by construction: at most two sessions per todo per run,
  each time-capped.
- Every agent ending is one of a closed set readable from files, so `status`
  reports without guessing.
- AGENTS.md's human merge rule contradicts this and goes, once `integrate` has
  been watched working.
- `reviewer` changes meaning. The old optional role's config keys, trailer and
  verbs are deleted, not renamed.
- A recycled pid can pass for a live agent; the registry records start time
  and exit so the check is not `kill -0` alone.
- Trunk can go red. The `--no-ff` merge commit reverts as one unit.
