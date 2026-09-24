# fix: a failed claim leaves its branch behind

- **Priority:** medium
- **Branch:** fix/a-failed-claim-leaves-its-branch-behind
- **Touches:** ai-harness/verbs/claim.sh
- **Blocked by:** —

## Goal
A claim that fails to create its worktree leaves no branch, so the todo is
offered again on the next tick instead of held until a human deletes it.

## Why
`git worktree add -b` creates the branch before it tries the directory. When
the directory fails (the worktree root is a file, unwritable, or already
holds the path), the branch survives, `plan` holds the todo as "branch
exists unclaimed", and the error blames the branch for a problem it did not
cause. Seen while testing `run` against a broken worktree root: one
transient failure turned into a permanent hold.

## Notes
- `ai-harness/verbs/claim.sh` runs `git worktree add -b "$_branch" "$_wt"`
  and bails on failure. On failure, `git branch -D "$_branch"` only if the
  branch did not exist before the attempt; check with
  `git rev-parse -q --verify "refs/heads/$_branch"` first, so a genuinely
  taken branch is still reported as taken.
- Split the error: the branch existing and the worktree path failing are
  different messages with different fixes.
- The scratch loop tests build a fixture under `/tmp/hx.*`; a case that
  points `AI_HARNESS_WORKTREE_ROOT` at a regular file reproduces this.

## Done when
- [ ] A claim whose worktree directory cannot be created leaves no branch
      and `aih plan` still lists the todo as runnable
- [ ] A claim on a branch that already existed still fails, names the
      branch, and leaves it alone
- [ ] `aih gate --full` green
