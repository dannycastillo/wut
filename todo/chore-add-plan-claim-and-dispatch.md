# chore: add plan, claim and dispatch

- **Priority:** high
- **Branch:** chore/add-plan-claim-and-dispatch
- **Touches:** harness/verbs/plan.sh, harness/verbs/dispatch.sh, harness/verbs/claim.sh, harness/lib/graph.sh
- **Blocked by:** —

## Goal
Three agents can be put onto three non-conflicting todos with one command each,
and the backlog is what decides which three.

## Already landed
`chore/add-claim-and-gate` shipped `claim`, `abandon`, `path`, `status` and the
`mkdir` lock, so a todo can be claimed and given back today. What is missing is
everything that decides *which* todo: `plan`, the Touches intersection, the
barrier, `--next`, `--scratch` and `dispatch`. Until those exist a human picks
the todo by name, which is safe for one worker and unsafe for three.

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

### claim, the parts still missing

Steps 1, 4, 5 and 6 of ADR-07's sequence are built. Still to add:

- step 2: refuse while `PAUSED` or `BARRIER` is present
- step 3: reject a candidate whose Touches intersect an active claim — the race
  git cannot see, and the reason two agents on two *different* todos can still
  end up in one file
- `--next` to pick the highest-priority runnable todo, which needs `plan`
- `--scratch` for a personal worktree with no todo attached

The claim file already carries `touches=`, so step 3 needs no state change.

### dispatch

Claims, then either execs `$HARNESS_AGENT_CMD` inside the new worktree or prints
the `cd` and the one-line boot prompt. Unset is a supported path, not a degraded
one — it is what lets the harness work on a platform nobody has written an
adapter for.

### Not in scope

Gate, check, submit, integrate.

## Done when
- [ ] `plan` reports all five clusters in the table above, and the barrier
- [ ] A claim whose Touches overlap an active claim is refused, naming the path
- [ ] `claim` refuses while `PAUSED` or `BARRIER` is present
- [ ] `eval "$(harness dispatch worker)"` leaves an agent in its own worktree;
      with `HARNESS_AGENT_CMD` unset it prints a command that works when pasted
- [ ] `plan` offers an abandoned todo again
- [ ] `sh -n` passes on every shell file
- [ ] `go build ./...` and `go vet ./...` pass
