# doc: write the harness README

- **Priority:** medium
- **Branch:** doc/write-the-harness-readme
- **Touches:** harness/README.md
- **Blocked by:** —

## Goal
Someone who has never seen the harness can read one file and run it.

## Why
The role docs are prompts for agents; this is the page for a person. It is also
where the harness's own conventions are stated, so they survive the session
that invented them.

The role docs moved: `worker.md` and `integrator.md` to
`chore-add-the-integrator`, `reviewer.md` to
`chore-retire-the-human-merge-gate`, each landing with the thing it describes
rather than ahead of it.

## Notes

What the harness is, the three roles, the verbs by owner, how to
run several workers, and one worked example of a stop condition:
`doc-add-license` declares `AGENTS.md`, so it always parks. Without that example
the first park reads as a broken harness.

Tone is AGENTS.md's: bullets, short sentences, present tense, specifics. A role
doc that gets skimmed is a role doc that gets followed.

State the honest limit in the README rather than burying it: max parallelism on
this backlog is six and realistically three, and the harness earns its keep as a
template rather than on this repo alone.

### The harness's own conventions, which the README must state

- POSIX sh only. macOS ships bash 3.2.57, so no arrays and no `mapfile`, and a
  lifted copy may run under dash.
- No shell file over `HARNESS_SHELL_MAX_LINES` (120). Enforced by the
  `shellsize` gate. A total line budget was tried and dropped: it says nothing
  about whether any one file fits in your head, and it turns every addition
  into a negotiation.
- `shellcheck -s sh` clean, enforced by the `shellcheck` gate. Suppressions
  carry their reason inline.
- Libraries in `harness/lib/` may only define functions: `bin/harness` sources
  `lib/*.sh` in glob order, so anything running at source time runs in that
  order too.
- No verb registry. A verb is a file in `harness/verbs/`; `help` globs the
  directory. Adding one edits nothing, which is why two branches adding verbs
  do not conflict.

## Done when
- [ ] Covers the three roles, the verbs by owner, and running N workers
- [ ] Carries the `doc-add-license` park as a worked example
- [ ] States all five conventions above
- [ ] States the honest parallelism limit rather than burying it
- [ ] Names no platform, and no language outside the `.harness.conf` example
- [ ] `harness gate --full` passes
