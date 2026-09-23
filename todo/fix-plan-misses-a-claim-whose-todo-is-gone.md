# fix: plan misses a claim whose todo file is already deleted

- **Priority:** medium
- **Branch:** fix/plan-misses-a-claim-whose-todo-is-gone
- **Touches:** harness/lib/graph.sh, harness/verbs/plan.sh
- **Blocked by:** —

## Goal
`harness plan` lists every active claim, including one whose worker has already
deleted its todo file.

## Why
`plan` reads active claims from two different places and they disagree.
`harness/lib/graph.sh:72` counts them with `harness_claim_count`, which reads
`claims/`, and that count is correct. But the emitting loop on line 73 is
`for _f in todo/*.md`, so a claim only reaches the output if its todo file
still exists in the tree `plan` is run from.

A worker deletes its todo in its final commit, per AGENTS.md's **Picking one
up**. So from that worker's own worktree — after the work is done and before
the merge — `plan` shows its claim in the count and not in the list. Observed
while evaluating three parallel branches:

```
chore-trim-the-comments  barrier: ... after 3 active claim(s) ...
claimed
  chore-add-the-integrator           worker-chore-add-the-integrator
  doc-write-the-harness-readme       worker-doc-write-the-harness-readme
```

Three counted, two listed. The missing one was the branch `plan` was running
from. It corrected itself once that branch merged, which confirms the cause.

The window is small but it is exactly the window in which someone looks: a
worker checking what else is in flight before submitting, or a human deciding
whether to start a fourth worker. `harness status` reads `claims/` directly and
is unaffected, so the two verbs contradict each other.

## Notes

Drive the `claimed` section from `harness_claim_stems` rather than from the
todo glob, and let the todo loop handle only the unclaimed. Git is the
authority and `claims/` annotates it — the same principle `doctor --repair`
already follows.

A claim whose todo is gone has no Priority or Touches to read from the tree.
`doctor --repair` has the same problem and solves it by reading the todo from
trunk with `git show "$HARNESS_TRUNK:$_todo"`; the claim file also carries
`touches=` from when it was written, which is cheaper and is already there.

Watch the reason strings that mention conflicts: they compare against active
claims' Touches, and those come from the claim file already, so they should
need no change.

## Done when
- [ ] From a worktree whose todo is deleted, `plan` lists that claim
- [ ] The count in the barrier reason and the number of `claimed` rows always agree
- [ ] `plan` and `status` never disagree about which claims are active
- [ ] A claim whose todo is absent from the tree still shows its agent and branch
- [ ] `harness gate --full` passes, including `shellcheck` and `shellsize`
