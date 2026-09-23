# fix: the Done-when classifier classifies nothing

- **Priority:** low
- **Branch:** fix/the-donewhen-classifier-classifies-nothing
- **Touches:** ai-harness/lib/packet.sh
- **Blocked by:** —

## Goal
The judgment packet's `[from diff]` / `[needs running]` split either earns its
fourteen lines of awk, or it goes.

## Why
Run `ai_harness_ig_boxes` over every open todo: **5 of 121 boxes** come back
`[from diff]`, and three of the five belong to one todo. Everything else
defaults to `[needs running]`, which is the safe direction and very nearly the
only direction.

The first real integration run showed the cost. All five boxes of
`chore-tidy-the-scanner` were marked `[needs running]`, including
"`countMatches`'s parameters are named for their contents" and "`scanChunk`'s
return type expresses zero-or-one" — two static properties of the tree,
readable from the patch in the time it takes to read the label telling you not
to. A classifier that is right but silent costs the reviewer the work it was
written to save.

## Notes

### Why it abstains

`packet.sh:11-12` whitelists phrasing and then vetoes on verbs:

```awk
if (l ~ /unchanged|restate|no longer (says|names)|carries|names no|is deleted/ &&
    l !~ /(^|[^a-z])(pass|fail|run|refuse|merge|park|return|behave|print|exit|reach|list|work)(e?s)?([^a-z]|$)/)
```

The whitelist is six phrases drawn from the todos that existed when it was
written, so it recognizes the boxes it was fitted to and nothing since. Boxes it
misses that are plainly static: "Every item in the 'delete outright' list above
is gone" and "`package ui`, `package cmd` and `package main` each have a package
doc" (`chore-trim-the-comments`), and both scanner boxes above.

### The two ways out

- **Widen it.** Keep the default and grow the static side — a named identifier
  plus `is named|expresses|has|each have|is gone|is absent`. Additive, testable
  against the 121 boxes now on record, and it can only ever be wrong in the
  direction of asking for more work.
- **Delete it.** Print the boxes plainly and let the reviewer judge which need
  running, which is what the packet's own header already instructs. Removes the
  whole function and the risk below.

Inverting the default — assume `[from diff]` unless a behavioural marker appears
— is the one direction to refuse. A wrong `[needs running]` wastes a minute; a
wrong `[from diff]` means a box is never checked and the merge claims otherwise.

Whichever way it goes, `AI-Harness-Donewhen` should stop being a literal — see
`fix-the-harness-forgets-its-parks`, which owns `packet.sh` for that and will
hold this todo in `plan` until it lands. The two are small; do them in order.

## Done when
- [ ] Either the from-diff share across the backlog is materially higher than
      5 of 121, measured by running `ai_harness_ig_boxes` over `todo/*.md`, or
      `ai_harness_ig_boxes` is gone and the packet prints the boxes unlabelled
- [ ] No box is labelled `[from diff]` unless it names a static property of the
      tree — checked by hand against every box the change newly labels
- [ ] `chore-tidy-the-scanner`'s five boxes are used as the fixture, since they
      are the first set a real run judged
- [ ] `aih gate --full` green, `sh -n` clean
