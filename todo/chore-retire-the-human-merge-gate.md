# chore: retire the human merge gate

- **Priority:** high
- **Branch:** chore/retire-the-human-merge-gate
- **Touches:** AGENTS.md, harness/lib/review.sh, harness/lib/adr.sh, harness/lib/report.sh, harness/verbs/review.sh, harness/verbs/next-review.sh, harness/verbs/pause.sh, harness/verbs/resume.sh, harness/verbs/unpark.sh, harness/verbs/log.sh, harness/hooks/pre-commit, harness/hooks/pre-merge-commit, harness/roles/reviewer.md
- **Blocked by:** chore-add-the-integrator

## Goal
AGENTS.md no longer says merging is Danny's call, and everything that rule was
holding back is in place: an independent reviewer, ADR numbers assigned at
merge, and a queue that can be stopped.

## Why
This is the bottleneck the whole harness exists to remove. It is last on
purpose. The mechanism that replaces the human lands in
`chore-add-the-integrator` and gets watched working first, so this branch
changes a rule against evidence rather than against a design.

**Land this one by hand and watch its first few merges.** It is also the unit
whose own diff a human should read closely, since it is the one that stops
requiring that.

## Notes

### The AGENTS.md edits, all of them

This is the only todo that touches AGENTS.md, apart from `doc-add-license`.
Keeping every edit here means exactly one branch trips the `protected-path`
hard stop, and that branch is the one a human was always going to read.

- **Replace "Merging is Danny's call"** (`AGENTS.md:70-94`) with the integrator
  rule. Keep the `--no-ff` reasoning exactly as it stands: `git log
  --first-parent main` reading as a list of changes is still the point.
- **"Before every commit"** (`AGENTS.md:59-68`) stops naming Go. It becomes
  `harness gate --quick`, and the `go build`/`go vet` pair lives in
  `.harness.conf` (ADR-09). This is the biggest portability win in the whole
  design: AGENTS.md stops naming a language.
- **Add the marker-delimited "Working in parallel" section**, pointing at
  `harness/README.md` and `harness/roles/`. Marker-delimited with a checksum so
  `install.sh` can refresh it and `doctor` can report drift without fixing it.
- **Amend the ADR file shape** for the draft convention (ADR-08).
- **Rewrite "Picking one up"** around `harness claim`.

### Review

File-based, which is what keeps it agnostic: write `review/<stem>`, then block
for the verdict file or run `$HARNESS_REVIEW_SPAWN` if set. The integrator
cannot portably spawn a session on an arbitrary platform, and that constraint is
the seam, not a limitation to engineer around.

`HARNESS_REVIEW` accepts `always`, `on-flag` and `never`. It is `never` today.

Worth knowing before building it: roughly 80% of a reviewer's job is mechanical
and already lives in `check`. The remaining judgment is what a separate session
buys, at roughly double the wall-clock per item.

### ADR numbering

Per ADR-08, inside the lock, with `--no-commit`: recompute `NN` as max of
`docs/adr-[0-9][0-9]-*.md` plus one, `git mv` the draft, rewrite the heading,
`Proposed` to `Accepted`, and the date, then replace `ADR-DRAFT-<KEBAB>`
everywhere `git grep -l` finds it.

The recomputation *is* the fix. Two branches each adding a different
`docs/adr-07-*.md` merge with **zero conflict**, so the duplicate assertion in
`check` and in the post-merge gate is the only thing standing between trunk and
two ADR-07s — including when a human hand-numbers one.

### Stopping

`pause "<reason>"` makes every mutating verb exit 3; in-flight workers keep
editing but cannot submit. `pause --hard` also aborts a mid-merge and drains
the queue to `parked/`, leaving every worktree intact. `resume` clears it.
`unpark <todo>` returns one item to the queue.

Third level, and it must stay true: `rm -rf .git/harness && harness doctor
--repair` is safe by design, because git is the authority. That already works.

### Hooks

`pre-commit` and `pre-merge-commit` refuse a direct write to trunk unless
`HARNESS_ALLOW_TRUNK=1`. Installed into the shared common dir, so one install
covers every worktree. Note the trap: a hook-blocked merge leaves `MERGE_HEAD`
staged rather than aborted.

### log

`harness log` joins `git log --first-parent main` trailers with `parked/` and
`claims/`. That split is what makes the state directory disposable: the
permanent record is in the merge commits.

Trailers have no separator line — see `chore-add-the-integrator` for why `---`
empties the block.

### reviewer.md

Read the diff against the Done-when list and AGENTS.md. The verdict file
format. And what is not its job: resolving conflicts, merging, or re-running
the gate. Sequence and stop conditions only; point at AGENTS.md for rules.

## Done when
- [ ] AGENTS.md carries the integrator rule, and no longer says merging is Danny's call
- [ ] AGENTS.md's per-commit check is `harness gate --quick` and names no language
- [ ] The "Working in parallel" block is marker-delimited, and `doctor` reports drift without fixing it
- [ ] AGENTS.md carries the ADR draft shape and the `harness claim` rewrite
- [ ] A review is requested, answered from a second session, and recorded in the merge trailers
- [ ] A draft ADR lands numbered and Accepted with no `ADR-DRAFT` token left on trunk
- [ ] Two hand-made `docs/adr-NN-*` files with one `NN` fail `check` as `adr-duplicate`
- [ ] `pause`, `pause --hard`, `resume` and `unpark` behave as documented
- [ ] A direct commit on trunk is refused by the hook unless `HARNESS_ALLOW_TRUNK=1`
- [ ] `harness log` shows each merge's gate, review, flags and notes from the trailers
- [ ] `rm -rf .git/harness && harness doctor --repair` still recovers every claim
- [ ] `harness gate --full` passes, including `shellcheck` and `shellsize`
