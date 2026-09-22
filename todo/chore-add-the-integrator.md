# chore: add submit and the integrator handshake

- **Priority:** high
- **Branch:** chore/add-the-integrator
- **Touches:** harness/verbs/submit.sh, harness/verbs/integrate.sh, harness/verbs/check.sh, harness/lib/check.sh, harness/lib/integrate.sh, harness/roles/worker.md, harness/roles/integrator.md
- **Blocked by:** —

## Goal
A submitted branch merges to trunk without a human reading the diff, or parks
with a reason that needs no interpreting.

## Why
`claim` and `gate` made parallel work safe. This closes the loop: it is what
makes a merge happen without anyone typing it.

It is deliberately **not** the unit that retires the human gate. AGENTS.md
still says merging is Danny's call, and `chore-retire-the-human-merge-gate`
changes that — after this handshake has been watched working. Splitting them
means the mechanism can be trusted on its own evidence before the rule that
depends on it is rewritten.

## Notes

### The handshake

`integrate --next --wait` runs the mechanical steps, stops, prints a judgment
packet and exits 10. The agent decides, then continues with exactly one of
`integrate --continue --verdict pass`, `--reject "<which box>"`, or
`--park <code> --detail "<what>"`.

Split in two because mechanics have to be deterministic and judgment must not
be — and because an agent cannot sit in a blocking loop and also think.

`--continue` must refuse with no pending phase, and `pass` must refuse without
a completed check. If either can be skipped, the merge gate is decorative.

### The judgment packet must say which boxes it cannot answer

Proven on `fix/tmux-test-session-name`: its Done-when box 3 was *"two
concurrent `WUT_TERMINAL_TESTS=1` runs both pass"*, which is the entire point
of the todo and is invisible in the diff. Verifying it meant cutting a worktree
on trunk, running two processes, watching both fail, then running two against
the branch and watching both pass.

So the packet marks each box **verifiable from the diff** or **needs running**.
Any behavioural claim is the second kind, and that is the common case, not an
edge case. An integrator that reads six boxes and ticks them off a patch would
have passed that branch without ever learning whether the fix worked.

### check, and the three things git status decides

Read-only, no checkout, from `git diff --name-only <trunk>...<branch>`.

Touches does not govern `todo/`; git status does, and the rule has three arms
because each has a different failure:

| Change | Rule | Why |
| --- | --- | --- |
| added | always allowed | AGENTS.md *requires* filing a todo for adjacent work. If that were an undeclared path, the harness would forbid what the process mandates — and a new file cannot collide, since two agents choosing one name produce a visible git conflict |
| deleted | must be the claimed one | it is how the work clears the backlog |
| modified | must be declared | two agents rewriting one todo is a real collision |

The **added** arm was found the hard way: a worker spotted adjacent work,
reasoned that filing it would put a file outside its Touches, and flagged it in
chat instead. It was right, and it should never have been put in that position.

The **deleted** arm is load-bearing in the other direction: the claimed todo is
not in its own Touches, so without the exemption the first run parks on its own
success.

Hard stops beyond that: `AGENTS.md`; `harness/**` or `.harness.conf`; a
`HARNESS_PROTECTED` path not declared in Touches; an added `t.Skip(`; a commit
subject outside the four prefixes. Undeclared paths are a hard park in this
unit — telling a soft flag from a hard stop needs the active-claim set, which
is `chore-add-plan-claim-and-dispatch`.

Every result is a code from a closed set. A situation with no code is
`unknown`, which is itself a stop.

### The trailers, and the separator that does not work

Measured on `fc5e53d`, the first harness-produced merge:
`git interpret-trailers --parse` reads only the **last paragraph**, and that
paragraph must contain nothing but trailers. Two things silently empty it:

- **A `---` line above the block.** Git treats `---` in a commit message as the
  patch separator, as in `format-patch` and `am`, so everything after it is
  discarded. An earlier draft of this todo specified that separator; it makes
  the trailers unreadable, which defeats their only purpose.
- **Any non-trailer line inside the block**, including a heading such as
  `Harness trailers:`.

So: summary prose, blank line, then trailers, and no separator at all. Folded
continuation lines do work, so a long `Harness-Notes:` value may wrap with a
leading space.

The merge-level prose is a summary, not the worker's full commit body — that
already exists on the branch commit, and `git log --first-parent main` is meant
to read as a list of changes.

### submit

Requires a clean tree on the claimed branch, requires the claimed todo deleted,
runs `gate --full` and refuses on red, then writes `submitted/<stem>` and
`submitted/<stem>.body`.

`--body <file>`, or `--body -` for stdin, and the harness writes the file
itself so `git merge -F` receives a real path. `git merge -F -` does not read
stdin, and finding that out at merge time already produced one misleading gate
run in this project's history.

`--escalate "<reason>"` for an ADR contradiction. `--note "<observation>"` for
adjacent work spotted in passing, landing as a `Harness-Notes:` trailer — the
channel that was missing when a worker's observation about dead code in the
tmux helper survived only because a human pasted it into chat.

### Order, and why it is that order

Baseline gate on trunk **before** any merge: a red trunk otherwise blames the
next branch to arrive and the queue loses credibility.

Post-merge gate **after**: both sides green and the merge red is a semantic
conflict, and it is the real risk of merging in parallel. On that,
`git reset --hard` to the pre-merge trunk and park. Never repair it inside the
merge commit — a merge holding code found on neither parent cannot be reviewed.

Trunk preconditions: clean, no `MERGE_HEAD`, not diverged. A dirty root parks
and is never cleaned; it is not the harness's tree. A hook-blocked merge leaves
`MERGE_HEAD` staged rather than aborted, so `git status` alone is not enough.

`git branch -d` and `git worktree remove` without `--force`, as free
assertions: they refuse when the work is unmerged or the tree is dirty, which
is exactly when stopping is correct.

### The two role docs

`worker.md` and `integrator.md`. State the **sequence** and the **stop
conditions**; point at AGENTS.md for the rules and never restate them. A role
doc that duplicates the Touches rule or the commit prefixes will drift from
AGENTS.md the first time either changes.

That this is safe was tested: a worker session booted with a one-line prompt
read AGENTS.md and the cited ADRs unprompted, and stayed inside its Touches.

`reviewer.md` belongs to `chore-retire-the-human-merge-gate`, which is what
builds the queue it would describe.

### Not in scope

The reviewer queue (`HARNESS_REVIEW=never`), ADR renumbering, compositional
conflict resolution, `pause`/`unpark`/`log`, the trunk-guard hooks, and every
AGENTS.md edit.

## Done when
- [ ] A submitted branch merges, gates, cleans up its branch and worktree, and clears its claim
- [ ] `--continue` refuses with no pending phase; `pass` refuses without a completed check
- [ ] The judgment packet marks each Done-when box verifiable-from-diff or needs-running
- [ ] A red post-merge gate resets trunk and parks `gate-red-merge`, branch intact
- [ ] A dirty trunk parks `dirty-trunk` and is not cleaned
- [ ] A diff touching `AGENTS.md` parks `protected-path`
- [ ] An added `todo/*.md` passes check; a modified one outside Touches parks
- [ ] `git log -1 --format=%B | git interpret-trailers --parse` lists every `Harness-*` line
- [ ] `submit --note` reaches the merge commit as `Harness-Notes:`
- [ ] `worker.md` and `integrator.md` restate no rule that AGENTS.md already states
- [ ] AGENTS.md is unchanged
- [ ] `harness gate --full` passes, including `shellcheck` and `shellsize`
