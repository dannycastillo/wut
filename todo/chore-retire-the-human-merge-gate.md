# chore: retire the human merge gate

- **Priority:** high
- **Branch:** chore/retire-the-human-merge-gate
- **Touches:** AGENTS.md, harness/*
- **Blocked by:** chore-add-the-run-loop

## Goal
AGENTS.md no longer says merging is Danny's call and names no language, trunk
refuses a direct write, and a draft ADR lands numbered.

## Why
This is the bottleneck the whole harness exists to remove, and it is last on
purpose. A reviewer agent reads AGENTS.md before its role doc and will obey
"stop and wait for approval in chat" over `integrate --continue`, so the loop
cannot run unattended until this lands. It lands after `integrate` has been
watched working with a human playing reviewer, so the rule changes against
evidence rather than against a design.

**Land this one by hand and watch the first unattended run.** It is also the
diff a human should read most closely, since it is the one that stops
requiring that.

## Notes

### The AGENTS.md edits, all of them

This is the only todo that touches AGENTS.md apart from `doc-add-license`.
Keeping every edit here means exactly one branch trips the `protected-path`
stop, and it is the branch a human was always going to read.

- **Replace "Merging is Danny's call"** with the two-role rule from ADR-10: a
  worker ends with `harness submit`, a reviewer ends with
  `integrate --continue`, and no agent runs `git merge`. Keep the `--no-ff`
  reasoning exactly as it stands; `git log --first-parent main` reading as a
  list of changes is still the point.
- **"Before every commit"** stops naming Go. It becomes `harness gate --quick`,
  and the `go build`/`go vet` pair lives in `.harness.conf` (ADR-09). This is
  the biggest portability win in the design: AGENTS.md stops naming a
  language.
- **Add the marker-delimited "Working in parallel" section**, pointing at
  `harness/README.md`, `harness/roles/` and `harness run`. Marker-delimited
  with a checksum so `install.sh` can refresh it and `doctor` can report drift
  without fixing it.
- **Amend the ADR file shape** for the draft convention (ADR-08).
- **Rewrite "Picking one up"** around `harness claim`.

### ADR numbering

Per ADR-08, inside `integrate --continue` after the merge and before the
commit: recompute `NN` as max of `docs/adr-[0-9][0-9]-*.md` plus one,
`git mv` the draft, rewrite the heading, `Proposed` to `Accepted`, and the
date, then replace `ADR-DRAFT-<KEBAB>` everywhere `git grep -l` finds it.

The recomputation *is* the fix. Two branches each adding a different
`docs/adr-07-*.md` merge with **zero conflict**, so the `adr-duplicate` check
already in `harness_check_paths` and its post-merge twin are the only thing
between trunk and two ADR-07s, including when a human hand-numbers one.

### Hooks

`pre-commit` and `pre-merge-commit` refuse a direct write to trunk unless
`HARNESS_ALLOW_TRUNK=1`. Installed into the shared common dir, so one install
covers every worktree. The trap: a hook-blocked merge leaves `MERGE_HEAD`
staged rather than aborted, which `harness_ig_trunk_ready` already names.

### Gone from this todo

The reviewer role, `review`, `next-review` and `HARNESS_REVIEW` went with
ADR-10. `pause`, `resume` and `log` moved to `chore-add-the-run-loop` and
`chore-add-the-agent-registry`. `unpark` is not needed: resubmitting from the
worktree already clears a park.

## Done when
- [ ] AGENTS.md carries the two-role rule and no longer says merging is Danny's
      call
- [ ] AGENTS.md's per-commit check is `harness gate --quick` and names no
      language
- [ ] The "Working in parallel" block is marker-delimited, and `doctor` reports
      drift without fixing it
- [ ] AGENTS.md carries the ADR draft shape and the `harness claim` rewrite
- [ ] A draft ADR lands numbered and Accepted with no `ADR-DRAFT` token left on
      trunk
- [ ] Two hand-made `docs/adr-NN-*` files with one `NN` fail the post-merge
      gate as `adr-duplicate`
- [ ] A direct commit on trunk is refused by the hook unless
      `HARNESS_ALLOW_TRUNK=1`
- [ ] `rm -rf .git/harness && harness doctor --repair` still recovers every
      claim
- [ ] One real todo is merged by `harness run` with real agents and nobody
      typing a verb, and its merge commit carries the trailers
- [ ] `harness gate --full` passes, including `shellcheck` and `shellsize`
