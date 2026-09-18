# AGENTS.md

Working agreements for this repo. Minimal on purpose — sections get added when
we hit something actually worth writing down, not in anticipation.

## Git workflow

### Branch for everything

`main` is only ever written by a merge. Never commit to it directly, not even a
one-line fix or a typo. If you find yourself on `main` with uncommitted work,
create the branch first, then commit — the work moves with you.

### Four prefixes, nothing else

| Prefix  | Use for                                                 |
| ------- | ------------------------------------------------------- |
| `feat`  | new behavior someone using the tool can observe          |
| `fix`   | correcting behavior that was wrong                       |
| `doc`   | documentation only, including this file                  |
| `chore` | deps, build, tooling, `.gitignore` — no behavior change  |

If a change doesn't fit one of these, it's doing two things — split it until
each piece fits.

### One branch unless the split earns it

A minor change in scope — a decision lands mid-branch, an answer widens the work
a little — stays on the branch you're on. Two branches cost two reviews and two
merges, and stacking one on the other pays that to preserve an intermediate
state nobody will check out.

Nothing is pushed until the merge, so the history isn't fixed yet:

```sh
git reset --soft main   # branch pointer back to main, every change still staged
```

Recommit from there in whatever shape reads best, and rename the branch when its
old name stops describing the work.

Split only when the halves could genuinely ship apart — when someone would want
to merge, revert, or bisect them separately.

### Naming

- **Branch:** `<prefix>/<short-kebab-description>` — `feat/pane-resize`
- **Commit subject:** `<prefix>: <imperative summary>` — `fix: stop the exit erase eating a line`

Imperative mood ("stop", "add", "align") because a commit describes what
applying it *does* to the tree, not what you did yesterday. The branch prefix
and its commits' prefixes normally match; when they don't, the branch takes the
prefix of its most significant change.

### Before every commit

```sh
go build ./...
go vet ./...
```

Both must pass. Don't commit over a failure — fix it or report it. Say in your
summary that they ran and what they said, so the check is visible rather than
assumed.

### Merging is Danny's call

When a branch is finished:

1. Show what's on it:
   ```sh
   git log --oneline main..HEAD
   git diff main...HEAD
   ```
2. **Stop.** Wait for explicit approval in chat.
3. Only after approval:
   ```sh
   git switch main
   git merge --no-ff <branch>
   git push origin main
   git branch -d <branch>
   ```

`--no-ff` forces a merge commit even when `main` hasn't moved. A fast-forward
would splice the branch's commits into `main` as a flat line and lose the fact
that they shipped as one unit; the merge commit keeps that grouping, so
`git log --first-parent main` reads as a list of changes rather than a list of
keystrokes.

Never push a branch, merge, or force-push anything without being asked.

## Architecture decisions

Decisions about the project's direction live in `docs/` as Architecture
Decision Records — one file per decision, numbered in the order made.

### Read them before starting work

`ls docs/` and read the titles. Read in full any ADR whose subject touches what
you're about to change.

If your intended approach contradicts an accepted ADR, **stop and say so**.
Don't quietly follow the ADR against the request, and don't quietly break it.
The conflict is the useful signal: either the request is the better idea and the
ADR should be superseded, or the ADR has a reason behind it that the request
didn't account for. Both are worth a sentence before any code gets written.

### When to write one

Write an ADR when a decision would be expensive to reverse — someone later would
have to *undo* it rather than edit around it — or when a reasonable person would
have chosen the other option. Swapping a dependency, deciding where data lives,
fixing the shape of a package's public API, deciding what the tool deliberately
won't do.

Don't write one for: adding a flag, fixing a bug, refactoring inside a file, or
anything the code already makes obvious. If a reader could recover the reasoning
by reading the diff, the diff is the record.

Unsure? Ask — guessing wrong is cheap in one direction and expensive in the
other.

### File shape

`docs/adr-NN-short-kebab-title.md`, `NN` zero-padded, next number after the
highest already present.

```markdown
# ADR-NN: Title

- **Status:** Accepted
- **Date:** YYYY-MM-DD

## Context
What was true before. What forced a choice.

## Decision
What we do, present tense.

## Alternatives considered
Each option, and the one reason it lost.

## Consequences
What this makes easy, what it makes hard, what we now maintain. Costs
included.
```

An ADR that accompanies a change rides on the same branch as its own `doc:`
commit, so the decision and the work are reviewable together but separable.

### Tone

Write for scanning. State the facts and the reasons; don't argue them.

- Bullets over paragraphs. Short sentences. Present tense.
- One line per reason. No justifying, no persuading, no hedging.
- Prefer specifics — versions, function names, file paths, measured numbers —
  over adjectives.
- Don't restate the Decision inside the Consequences.
- If a reason needs a paragraph to defend, the decision isn't settled. Settle
  it, then record the outcome.

One screen per ADR. Longer than that means it's covering more than one
decision — split it.

### ADRs are append-only

Never rewrite the Decision of an accepted ADR. A record you edit is no longer a
record of what you decided — it's a record of what you currently think, and the
code already tells you that.

To change course, write a new ADR carrying `**Supersedes:** ADR-NN`, and add a
`**Superseded by:** ADR-MM` line to the old one's status block. Adding that
back-pointer is the only edit an accepted ADR ever takes.

## Todo

Work that needs doing lives in `todo/`, one file per item. `ls todo/` is the
backlog — if a file is there, the work is open.

### Filename is the branch name

`todo/<prefix>-<short-kebab>.md` → branch `<prefix>/<short-kebab>`.

```
todo/feat-pane-resize.md    →  git switch -c feat/pane-resize
todo/fix-empty-desc-line.md →  git switch -c fix/empty-desc-line
```

Same four prefixes as commits. No numbers: todos have no order, and two agents
filing at once would race for the same one.

### Shape

```markdown
# <prefix>: <short title>

- **Priority:** high | medium | low
- **Branch:** <prefix>/<short-kebab>
- **Touches:** comma-separated paths, or `new` / `unknown`
- **Blocked by:** other todo filenames, or `—`

## Goal
One sentence: what is true when this is done.

## Why
The reason it's worth doing. One or two lines.

## Notes
Constraints, file paths, function names, gotchas, ADRs that apply.
Everything needed to start without asking a question.

## Done when
- [ ] verifiable statement
- [ ] verifiable statement
- [ ] `go build ./...` and `go vet ./...` pass
```

### Priority

| Value    | Test                                                              |
| -------- | ----------------------------------------------------------------- |
| `high`   | the tool is wrong in a way a user hits, or this blocks other work  |
| `medium` | real work, no urgency                                              |
| `low`    | worth doing; fine if it never happens                              |

Priority is relative to what's in `todo/` right now, not absolute. If most of
the backlog is `high`, none of it is — re-rank rather than inflate.

```sh
grep '\*\*Priority:\*\*' todo/*.md
```

An agent filing a todo proposes a priority. Danny's edit is final, and priority
is the **only** field worth editing in place — unlike an ADR, a todo is a plan,
not a record. Rewrite it freely while it's still open.

Priority orders the queue; it does not override **Blocked by**. A blocked
`high` waits for the thing blocking it, whatever that thing's priority is.

### Touches, and why it's the precise one

`Touches` is what makes parallel work possible. Before dispatching two agents:

```sh
grep '\*\*Touches:\*\*' todo/*.md
```

Overlapping paths means run them one after the other, not side by side. If you
discover mid-task that you must touch a file the todo didn't list, **say so** —
another agent may be in that file right now.

**Done when** is the contract. Finish all of it; don't do more than it asks. If
you spot adjacent work, file a todo for it rather than folding it in.

### Picking one up

1. Read the todo file, and read in full any ADR it references.
2. Branch using the name in the file.
3. Do the work.
4. `git rm` the todo file as part of the final commit on the branch.
5. Stop for approval, per the git workflow above.

Deleting the file on the branch means merging the work and clearing the backlog
are the same event — there's no second step to forget, and no status field that
two branches can conflict over. What got done is still recoverable:

```sh
git log --diff-filter=D --oneline -- todo/
```

If a todo's Notes contradict the code — it was written before the code moved —
say so before working around it. A stale todo is worth a sentence, not a silent
reinterpretation.

### Filing one

File a todo when you notice work that's real but out of scope for what you're
doing. Don't file what you're about to do anyway, and don't file a vague
"improve X" — if you can't write the **Done when**, you don't understand it
well enough to hand off.

Filing is not prioritizing. Danny decides what gets picked up.
