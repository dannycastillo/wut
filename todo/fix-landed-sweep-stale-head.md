# fix: the landed sweep misses a hand-merged branch whose head moved

- **Priority:** low
- **Branch:** fix/landed-sweep-stale-head
- **Touches:** ai-harness/lib/integrate.sh
- **Blocked by:** —

## Goal
A parked claim whose branch a human amended and then merged by hand is
cleared by the next `aih integrate`, the same as one merged at the parked head.

## Why
`ai_harness_ig_landed_head` reads the head from the submitted or parked record
before it falls back to the branch ref. `submit` refreshes that record; a hand
amend does not. So the ancestor check runs against a commit trunk never took,
the claim stays parked with its worktree and slot, and `aih status` keeps
reporting the todo unfinished after it landed. Seen on `doc-add-license`,
2026-09-24: parked at 29bf774, amended to 1817f99, merged as 86b291f, and the
sweep only cleared it after the record's `head=` was edited by hand.

## Notes
- The check is `ai-harness/lib/integrate.sh`, `ai_harness_ig_landed_head`.
  When the recorded head is not an ancestor of trunk, also try the branch ref
  before giving up. The todo-gone-from-trunk half of the test stays as it is;
  that is what stops a fresh claim looking landed.
- Log the head that actually landed, not the recorded one.
- `ai-harness/lib/selftest.sh` covers `check` codes only; no harness test
  drives the sweep. Reproduce by hand in a throwaway repo, or add a case if it
  fits `aih check --selftest` without stretching it.
- `.ai-harness.conf` caps shell files per file; `integrate.sh` is under the
  limit but check with `aih gate` before adding lines.
- Harness paths are protected, so this parks for a hand merge by design.

## Done when
- [ ] A claim parked at head A, amended to B and hand-merged at B, is cleared
      by the next `aih integrate` and logged `landed B by hand`
- [ ] A claim whose branch was merged at the parked head still clears as before
- [ ] A fresh claim, or a todo deleted on purpose without its branch merged,
      is still not treated as landed
- [ ] `aih gate --full` passes, including shellcheck and shellsize
