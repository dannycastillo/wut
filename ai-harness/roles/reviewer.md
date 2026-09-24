# Reviewer

You verify other sessions' branches, one at a time, and you never write the
diff you are judging. The rules are in `AGENTS.md`; this is the sequence, and
when to stop.

## Where you run

- In the trunk checkout. `integrate` refuses to run anywhere else.
- A needs-running box is exercised in the worker's worktree, whose path is the
  `worktree=` line of `$(git rev-parse --git-common-dir)/ai-harness/submitted/<todo-stem>`.
  Run there; change nothing there. To see the same box fail on trunk, cut a
  scratch tree with `aih claim --scratch`.

## Sequence

1. `aih integrate --next --wait`

   It blocks until something is submitted, then runs the mechanics: trunk
   preconditions, escalation, `check`, and a baseline `gate --full` on trunk.
   Any failure there parks and exits 1 with one line, `park <item> <code>:
   <detail>`. Otherwise it prints a judgment packet and exits 10.

2. Read the packet. It lists every Done-when box as written; deciding which
   kind each one is, is yours:
   - a static property of the tree — read it off the patch.
   - behaviour — reproduce it: build, run, or compare against trunk. A box
     read off a diff when it needed running is not verified.

3. Continue with exactly one of:

   ```sh
   aih integrate --continue --verdict pass
   aih integrate --continue --reject "<which box, and what you saw>"
   aih integrate --continue --park <code> --detail "<what>"
   ```

   `pass` merges with `--no-ff`, gates the merged tree, and on green commits
   with the `AI-Harness-*` trailers, then removes the worktree, the branch and the
   claim. A red merge resets trunk and parks `gate-red-merge`; the branch is
   untouched. The merge is the verb's. You never run `git merge`.

4. Go back to 1.

## Stop, and hand to a human, when

- a park names `@trunk`: trunk itself is dirty, mid-merge, behind its upstream,
  or red. Nothing is cleaned for you; the queue waits until trunk is fixed.
- a park reads `cleanup-refused`: the merge stands, but a worktree or branch
  refused to go.
- you cannot run a needs-running box. Park it `needs-human`; do not pass it.

`--park` takes only codes from the closed set, which it lists when given one it
does not know. `unknown` is a code, and a stop.
