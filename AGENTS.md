# AGENTS.md

Working agreements for this repo. Minimal on purpose — sections get added when
we hit something actually worth writing down, not in anticipation.

## Git workflow

### Branch for everything

`main` is only ever written by a merge. Never commit to it directly, not even a
one-line fix or a typo. If you find yourself on `main` with uncommitted work,
create the branch first, then commit — the work moves with you.

### Four prefixes, nothing else

| Prefix  | Use for                                                  |
| ------- | -------------------------------------------------------- |
| `feat`  | new behavior someone using the tool can observe          |
| `fix`   | correcting behavior that was wrong                       |
| `doc`   | documentation only, including this file                  |
| `chore` | deps, build, tooling, restructuring — no behavior change |

`chore` covers moving code as well as maintaining it: an extraction that leaves
behavior identical is a chore however large its diff, because what a reader
needs to check is that nothing changed.

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
harness gate --quick
```

It must pass. What it runs is declared in `.harness.conf` (ADR-09), so this
file names no language. Don't commit over a failure — fix it or report it. Say
in your summary that it ran and what it said, so the check is visible rather
than assumed.

### Trunk is written only by `harness integrate`

Two roles, and the session that writes a diff never reviews it (ADR-10):

- A **worker** finishes by running `harness submit`. It never merges, never
  pushes, and never runs `git merge`.
- A **reviewer** verifies the packet `harness integrate --next` prints and
  finishes by running `harness integrate --continue` with a verdict. The verb
  merges; the reviewer never does.

`integrate` merges with `--no-ff`, so there is a merge commit even when `main`
hasn't moved. A fast-forward would splice the branch's commits into `main` as a
flat line and lose the fact that they shipped as one unit; the merge commit
keeps that grouping, so `git log --first-parent main` reads as a list of
changes rather than a list of keystrokes.

Anything the verbs stop on — a park, a red gate, a path outside `Touches` — is
a human's to resolve. The hooks refuse a direct write to trunk; a human merging
by hand sets `HARNESS_ALLOW_TRUNK=1` to say so on purpose.

Never push a branch, merge, or force-push anything without being asked.

<!-- harness:begin cksum=979730883 -->
## Working in parallel

Several agents work this backlog at once, one todo each, in separate
worktrees, and trunk is written only by `harness integrate`. The mechanics and
the verbs are in `harness/README.md`; each role's sequence is in
`harness/roles/`. `harness run` works a set of todos unattended.

`Touches` in a todo is a reservation on paths, and it is the only thing that
decides what runs side by side.
<!-- harness:end -->

## Architecture decisions

Decisions about the project's direction live in `docs/` as Architecture
Decision Records — one file per decision, named by the date it was made.

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

`docs/adr-YYYY-MM-DD-short-kebab-title.md`, dated the day it is written.
Two authors on one day pick different titles; the same title on the same day
is the same path, which git reports as a conflict instead of merging silently.
That is the whole reason for the date: sequential numbers were tried and two
branches can each add the next one with no conflict at all.

Refer to an ADR by its file name without the directory and extension. The
first ten are numbered `ADR-01` to `ADR-10` and keep those names.

```markdown
# ADR YYYY-MM-DD: Title

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

To change course, write a new ADR carrying `**Supersedes:** <old name>`, and
add a `**Superseded by:** <new name>` line to the old one's status block.
Adding that back-pointer is the only edit an accepted ADR ever takes. List the
old file in `Touches`, so two branches superseding it serialize.

## Comments

A comment earns its place when the code is surprising: a workaround, a measured
constant, an upstream bug, an invariant two files share, a non-obvious ordering.
The things a reader would otherwise "fix".

Everything else is noise. The reasoning behind a design goes in the commit
message or an ADR, where it cannot drift out of sync with the code it describes,
and where this repo already expects it in full.

- Default to none. The code says what it does; a comment says why it looks wrong.
- Keep Go's doc comments — exported identifiers and package docs, stated plainly.
- A comment longer than the code it describes is arguing a design. Move it.
- Never restate the line below, number steps, or leave commented-out code.

This governs source files only. Explanations in review and in chat are a
different thing and stay as long as they need to be.

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
- **Touches:** paths or globs, or one of `ALL` / `NEW <glob>` / `UNKNOWN`
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

`Touches` is what makes parallel work possible. It is a reservation on a set of
paths, and it is the only thing deciding what can run side by side.

Paths or globs, space- or comma-separated, repo-relative. No prose and no
backticks: a field a script cannot parse reserves nothing.

```
- **Touches:** internal/search/scan.go, internal/search/scan_test.go
- **Touches:** internal/*
```

A `*` matches across `/`, so `internal/*` covers `internal/ui/list_picker.go`.
That is the shell's `case` behaviour rather than a choice, and it errs the
useful way: too broad only costs serialization, too narrow puts two agents in
one file.

Three tokens stand in for a path list:

| Token         | Means                                                        |
| ------------- | ------------------------------------------------------------ |
| `ALL`         | the whole repo. Conflicts with everything, so it runs alone  |
| `NEW <glob>`  | creates files that don't exist yet, bounded by the glob      |
| `UNKNOWN`     | not scoped yet. Treated as `ALL` until someone scopes it     |

There is no `Excludes:`. An exclusion the scheduler has to reason about is a
collision it can get wrong; the nuance belongs in **Notes**, where a reader
acts on it instead.

Overlapping paths means run them one after the other, not side by side:

```sh
grep '\*\*Touches:\*\*' todo/*.md
```

If you discover mid-task that you must touch a file the todo didn't list,
**say so** — another agent may be in that file right now.

**Done when** is the contract. Finish all of it; don't do more than it asks. If
you spot adjacent work, file a todo for it rather than folding it in.

### Picking one up

1. `cd "$(harness claim <todo-stem>)"`. It cuts the branch and a worktree from
   trunk and reserves `Touches`. `harness dispatch worker` takes the top
   runnable one instead.
2. Read the todo file, and read in full any ADR it references.
3. Do the work. `harness gate --quick` before every commit, and
   `harness check` to see what `integrate` will say.
4. `git rm` the todo file as part of the final commit on the branch.
5. Rebase onto trunk if it moved, then `harness submit`.

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
