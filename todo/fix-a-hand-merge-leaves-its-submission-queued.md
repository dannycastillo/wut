# fix: a hand-merged submission stays in the queue

- **Priority:** medium
- **Branch:** fix/the-hand-merge-cleanup
- **Touches:** harness/verbs/integrate.sh, harness/lib/integrate.sh, harness/verbs/abandon.sh
- **Blocked by:** —

## Goal
A submission that reached trunk without the integrator leaves the queue,
without a human deleting files in the state directory.

## Why
Every branch touching `harness/**`, `AGENTS.md` or `.harness.conf` parks
permanently and is resolved by a human merging it. That is by design and never
changes, so the hand-merge is not an edge case — it is the only path the
harness's own construction can take.

Nothing cleans up after it. `abandon` releases the worktree, the branch and the
claim; `submitted/<stem>` and `submitted/<stem>.body` survive. After merging the
four branches of 2026-09-23 by hand, six files had to be removed with `rm`.

## Notes

### What actually happens, observed

`integrate --next` does pick the stale entry up, and it fails safely:

```
park fix-thing moved: fix/thing is not at the commit it was submitted at — resubmit
exit: 1
```

So there is no risk of a wrong merge — the head check catches it first. The
damage is a **false park**: an item recorded as parked when its work is already
on trunk, waiting for a resubmission that will never come because the worker is
gone and the todo is deleted. With parks now carried into merge trailers, that
record has no merge left to reach, so it sits in `parked/` permanently.

### The discriminator is already available

A submission that was hand-merged has its `head=` in trunk's history; a branch
that was rebased or amended does not:

```sh
git merge-base --is-ancestor "$(harness_kv_get "$_sub" head)" "$HARNESS_TRUNK"
```

True means the work landed and the entry is finished bookkeeping, not a
conflict. So the `moved` arm should split: ancestor of trunk → clear the claim,
the queue entry, the body and any park, report it as landed outside the
harness, and move to the next item. Not an ancestor → `moved`, as today.

That fixes it with no new verb and no human step, which is the point: a step a
human has to remember is a step the harness has not automated.

### `abandon` is the other half

`abandon` means *give the claim back*, which is a different act from *this is
finished*. It should refuse, or at least warn, when `submitted/<stem>` exists —
today it silently leaves the item queued while destroying the branch the queue
entry points at, which is how the false park gets created in the first place.

### Not to be confused with

`fix-the-harness-forgets-its-parks` made parks durable through the merge. This
is about a park that should never have been recorded. Its Touches overlap on
`harness/lib/integrate.sh`, so the two cannot run together; that one has landed.

## Done when
- [ ] A branch merged by hand, then `integrate --next`: the entry is cleared and
      reported as landed, with no park recorded
- [ ] A branch whose head moved for any other reason still parks `moved`
- [ ] `abandon` refuses, or warns loudly, while a submission is queued
- [ ] No step in the hand-merge path requires removing a file by hand
- [ ] Exercised against a real hand-merged harness branch, since that is the
      only way this path is ever reached
- [ ] `harness gate --full` green, `check --selftest` still thirteen of thirteen
