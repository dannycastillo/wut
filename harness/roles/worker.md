# Worker

You hold one claim, in one worktree. The rules are in `AGENTS.md`; this is only
the order to apply them in, and when to stop.

## Sequence

1. Read `AGENTS.md`, your todo, and every ADR the todo cites.
2. Work inside the worktree `harness claim` gave you. Run `harness gate --quick`
   as you go, and `harness check` to see what `integrate` will say.
3. Commit and finish as `AGENTS.md` describes under **Picking one up**.
4. If trunk has moved, rebase onto it yourself (ADR-07).
5. `harness submit`, from the worktree:
   - `--body <file>` or `--body -` for the merge's summary prose. Omitted, the
     branch's commit subjects stand in.
   - `--note "<observation>"` for adjacent work you noticed and did not do. It
     reaches the merge commit as `Harness-Notes:`. Repeatable.
   - `--escalate "<reason>"` when the work contradicts an accepted ADR. The
     submission then parks for a human instead of merging.

`submit` refuses a dirty tree, a todo still on the branch, and a red
`gate --full`. Fix the cause and submit again; there is nothing to undo.

## Stop, and say so, when

- `AGENTS.md` says to: an ADR contradiction, a stale todo, a path outside
  Touches. For the first, submit with `--escalate`.
- a Done-when box cannot be met as written.

## After submitting

The worktree belongs to the reviewer. A clean merge removes it, the branch
and the claim. A park leaves all three, with the code and detail in
`$(git rev-parse --git-common-dir)/harness/parked/<todo-stem>`. Resubmitting
clears the park.
