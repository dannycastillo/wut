# fix: the Done-when classifier classifies nothing

- **Priority:** low
- **Branch:** fix/the-donewhen-classifier-classifies-nothing
- **Touches:** ai-harness/lib/packet.sh
- **Blocked by:** —

## Goal
The judgment packet prints each Done-when box plainly, and the
`[from diff]` / `[needs running]` classifier is gone.

## Why
Measured twice. When this was filed, `ai_harness_ig_boxes` over every open
todo labelled 5 of 121 boxes `[from diff]`. On 2026-09-23 it is 2 of 104.
Everything else defaults to `[needs running]`, which is the safe direction
and very nearly the only direction, so the label carries no information and
costs the reviewer a line per box telling it not to trust the label.

The first real integration run showed the cost. All five boxes of
`chore-tidy-the-scanner` were marked `[needs running]`, including
"`countMatches`'s parameters are named for their contents" and "`scanChunk`'s
return type expresses zero-or-one", two static properties of the tree that
read from the patch faster than from the label.

## Notes

### The decision is delete, not widen

`packet.sh:5-24` whitelists six phrases fitted to the todos that existed when
it was written and vetoes on verbs. Widening it means fitting it again to
today's todos, and it goes stale the same way. The packet's header already
tells the reviewer to decide which boxes need running; the reviewer is an
agent reading a diff, and that judgment is its job.

Inverting the default is the one direction to refuse. A wrong
`[needs running]` wastes a minute; a wrong `[from diff]` means a box is never
checked and the merge claims otherwise.

### What to do

- Delete `ai_harness_ig_boxes` and print the boxes from the todo as they are,
  one `- ` line each, under the same heading in `ai_harness_ig_packet`.
- `AI-Harness-Donewhen` already prints the reviewer's verdict, not a
  classification; leave it.
- The fixture: `git show a114717^:todo/chore-tidy-the-scanner.md` is the
  first todo a real run judged. Its five boxes should come out unlabelled and
  intact.

## Done when
- [ ] `ai_harness_ig_boxes` is gone and the packet prints every box unlabelled
- [ ] The five boxes of the scanner fixture appear in the packet exactly as
      written in the todo, multi-line boxes joined onto one line
- [ ] `aih check --selftest` and `aih doctor --selftest` still pass
- [ ] `aih gate --full` green, `sh -n` clean
