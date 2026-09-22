# chore: add the integrator and retire the human merge gate

- **Priority:** high
- **Branch:** chore/add-the-integrator
- **Touches:** harness/verbs/*, harness/lib/integrate.sh, harness/lib/adr.sh, harness/lib/review.sh, harness/lib/report.sh, AGENTS.md
- **Blocked by:** chore-add-plan-claim-and-dispatch, chore-add-the-gate-and-check

## Goal
A submitted branch merges to trunk and pushes without a human, or parks with a
reason that needs no interpreting.

## Why
This is the bottleneck. Everything before this unit makes parallel work safe;
this is what makes it unattended.

## Notes

### The handshake

`integrate --next --wait` runs the mechanical steps, then stops, prints a
judgment packet and exits 10. The agent decides, then continues with
`integrate --continue --verdict pass`, `--reject "<which Done when box>"`, or
`--park <code> --detail "<what>"`.

Split in two because mechanics have to be deterministic and judgment must not
be — and because an agent cannot sit in a blocking loop and also think.

`--continue` must refuse when no `--next` phase is pending, and `pass` must
refuse without a completed check and, where a review was requested, a verdict.
If either can be skipped, the merge gate is decorative.

### Order, and why it is that order

Baseline gate on trunk **before** any merge: otherwise a red trunk blames the
next branch to arrive and the queue loses credibility.

Post-merge gate **after**: both sides green and the merge red is a semantic
conflict, and it is the real risk of merging in parallel. On that, `git reset
--hard` to the pre-merge trunk and park both branches. Never repair it inside
the merge commit — a merge holding code found on neither parent cannot be
reviewed.

Trunk preconditions: clean, no `MERGE_HEAD`, not diverged from origin. A dirty
root parks the queue and is never cleaned; it is not the harness's tree. Note
that a hook-blocked merge leaves `MERGE_HEAD` staged rather than aborted, so
checking `git status` alone is not enough.

`git branch -d` and `git worktree remove` are used without `--force`, as free
assertions: they refuse when the work is unmerged or the tree is dirty, which is
exactly when stopping is correct.

### Review

File-based: write `review/<stem>`, then block for the verdict file or run
`$HARNESS_REVIEW_SPAWN` if it is set. Blocking is the supported path — the
integrator cannot portably spawn a session on an arbitrary platform, and that
constraint is what keeps the seam agnostic.

### ADR numbering

Per ADR-08, inside the lock, with `--no-commit`: recompute `NN`, `git mv` the
draft, rewrite the heading and status block, and replace the `ADR-DRAFT-<KEBAB>`
token everywhere `git grep -l` finds it.

### Audit trail

`Harness-*` trailers after the worker's prose and a `---` separator, parseable
by `git interpret-trailers`, never in the subject. The merge commit is the
record; the state directory holds only in-flight work.

### AGENTS.md

Replace "Merging is Danny's call" with the integrator rule, keeping the `--no-ff`
reasoning as it stands. Add the marker-delimited "Working in parallel" section
pointing at `harness/README.md` and `harness/roles/`. Amend the ADR file shape
for the draft convention. Rewrite "Picking one up" around `harness claim`.

Land this one by hand, and watch the first few merges it makes.

## Done when
- [ ] A submitted branch merges, gates, pushes, and cleans up its branch and worktree
- [ ] `--continue` refuses with no pending phase, and `pass` refuses without a
      completed check or a requested verdict
- [ ] A red post-merge gate resets trunk and parks as `gate-red-merge`, leaving
      the worker's branch intact
- [ ] A dirty trunk parks as `dirty-trunk` and is not cleaned
- [ ] A diff touching `AGENTS.md` parks as `protected-path`
- [ ] A draft ADR lands numbered and Accepted with no `ADR-DRAFT` token left
- [ ] `harness log` shows each merge's gate, review and flags from the trailers
- [ ] `pause`, `pause --hard`, `resume` and `unpark` behave as documented
- [ ] AGENTS.md carries the integrator rule, the parallel section, the amended
      ADR shape, and the rewritten "Picking one up"
- [ ] `sh -n` passes on every shell file
- [ ] `go build ./...` and `go vet ./...` pass
