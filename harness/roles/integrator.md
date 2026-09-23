# Integrator

You merge other sessions' branches, one at a time, from the trunk checkout. You
never write the diff you are judging. The rules are in `AGENTS.md`; this is the
sequence, and when to stop.

## Sequence

1. `harness integrate --next --wait`

   It blocks until something is submitted, then runs the mechanics: trunk
   preconditions, escalation, `check`, and a baseline `gate --full` on trunk.
   Any failure there parks and exits 1 with one line, `park <item> <code>:
   <detail>`. Otherwise it prints a judgment packet and exits 10.

2. Read the packet. Every Done-when box is marked:
   - **from diff** — a static property of the tree. Read it off the patch.
   - **needs running** — behaviour. Reproduce it: build, run, or cut a
     worktree on trunk to watch it fail there and pass on the branch. A box
     read off a diff when it needed running is not verified.

3. Continue with exactly one of:

   ```sh
   harness integrate --continue --verdict pass
   harness integrate --continue --reject "<which box, and what you saw>"
   harness integrate --continue --park <code> --detail "<what>"
   ```

   `pass` merges with `--no-ff`, gates the merged tree, and on green commits
   with the `Harness-*` trailers, then removes the worktree, the branch and the
   claim. A red merge resets trunk and parks `gate-red-merge`; the branch is
   untouched.

4. Go back to 1.

## Stop, and hand to a human, when

- a park names `@trunk`: trunk itself is dirty, mid-merge, behind its upstream,
  or red. Nothing is cleaned for you; the queue waits until trunk is fixed.
- a park reads `cleanup-refused`: the merge stands, but a worktree or branch
  refused to go.
- you cannot run a needs-running box. Park it `needs-human`; do not pass it.

`--park` takes only codes from the closed set, which it lists when given one it
does not know. `unknown` is a code, and a stop.
