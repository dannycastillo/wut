# chore: add plan, claim and dispatch

- **Priority:** high
- **Branch:** chore/add-plan-claim-and-dispatch
- **Touches:** harness/verbs/plan.sh, harness/verbs/claim.sh, harness/verbs/abandon.sh, harness/verbs/dispatch.sh, harness/lib/graph.sh, harness/lib/claim.sh, harness/lib/lock.sh
- **Blocked by:** chore-add-the-harness-skeleton

## Goal
Three agents can be put onto three non-conflicting todos with one command each,
and the backlog is what decides which three.

## Why
This is the unit that pays for itself before the rest exists. With `plan` and
`claim`, work runs in parallel while merging stays a human job, so the
throughput gain does not wait for the integrator.

## Notes

### plan

Parses every todo, builds the Blocked-by graph and the Touches intersections,
and prints the runnable set priority-ordered plus a reason for every item that
is not runnable: blocked, conflicts with an active claim, conflicts with a
higher-priority runnable item, or barrier.

Globs compare with sh `case`, where `*` crosses `/`. Two globs intersect if
either matches the other's literal prefix, or if a path already in the repo
matches both. When it is ambiguous, report a conflict: a false positive
serializes work, a false negative puts two agents in one file.

It must reproduce these, which are the ground truth on today's backlog:

| Cluster | Members |
| ------- | ------- |
| `ALL` barrier | chore-trim-the-comments against everything |
| `internal/ui/list_picker.go` | feat-help-above-results, feat-theme-aware-list-chrome |
| `cmd/root.go` | fix-help-text-copy, chore-raise-test-coverage |
| `internal/search/scan.go` | chore-tidy-the-scanner, fix-multi-line-snippet-join |
| `internal/search/*_test.go` ∩ `scan_test.go` | chore-raise-test-coverage, fix-multi-line-snippet-join |

The last one is the reason `plan` exists: eyeballing `grep` output missed it.

### claim

Two races, two mechanisms (ADR-07), in this order:

1. `mkdir` the claim lock, or fail
2. refuse if `PAUSED` or `BARRIER` is present
3. reject if Touches intersect an active claim — git cannot see this race
4. `git worktree add -b <branch> <path>` — non-zero means the todo is taken
5. write `claims/<stem>`
6. release the lock

Dying between 4 and 5 is recovered by `doctor --repair`, so step 5 is an
annotation and step 4 is the claim.

`--scratch` gives a personal worktree with no todo attached. `abandon` releases
a claim and frees its paths; `--keep-branch` leaves the work in place.

Stale locks are reported, never stolen.

### dispatch

Claims, then either execs `$HARNESS_AGENT_CMD` inside the new worktree or prints
the `cd` and the one-line boot prompt. Unset is a supported path, not a degraded
one — it is what lets the harness work on a platform nobody has written an
adapter for.

### Not in scope

Gate, check, submit, integrate.

## Done when
- [ ] `plan` reports all five clusters in the table above, and the barrier
- [ ] Six concurrent `claim` calls on one todo produce exactly one worktree
- [ ] A claim whose Touches overlap an active claim is refused, naming the path
- [ ] `claim` refuses past `HARNESS_MAX_WORKERS`, and while `PAUSED` or `BARRIER`
- [ ] `eval "$(harness dispatch worker)"` leaves an agent in its own worktree;
      with `HARNESS_AGENT_CMD` unset it prints a command that works when pasted
- [ ] `abandon` frees the paths and `plan` offers the todo again
- [ ] A stale lock is reported, not stolen
- [ ] `sh -n` passes on every shell file
- [ ] `go build ./...` and `go vet ./...` pass
