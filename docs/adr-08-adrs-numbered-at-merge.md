# ADR-08: ADRs are drafted unnumbered and numbered at merge

- **Status:** Accepted
- **Date:** 2026-09-21

## Context
The file shape says `docs/adr-NN-short-kebab-title.md`, `NN` the next number
after the highest already present. That assumes one author at a time.

Two branches each adding `docs/adr-07-<different-kebab>.md` merge with **no
conflict** — git compares paths, and the paths differ. `main` ends up holding
two ADR-07s and nothing reports it. Tested, not inferred.

The Todo section already rejected numbering for exactly this reason: "two
agents filing at once would race for the same one." That reasoning was never
carried across to `docs/`.

## Decision
A worker writes `docs/adr-draft-<kebab>.md`, headed
`# ADR-DRAFT-<KEBAB>: Title`, with `**Status:** Proposed`. Two concurrent
drafts get different filenames, so they cannot collide.

The integrator assigns the number at merge, inside its lock: recompute `NN`
from the files present, `git mv`, rewrite the heading, set the status to
Accepted with the merge date, and replace the `ADR-DRAFT-<KEBAB>` token
wherever `git grep -l` finds it.

The kebab stays inside the token so that two drafts landing in one merge
remain distinguishable to a `sed`.

`harness check` and the post-merge gate both assert that no two
`docs/adr-NN-*` share an `NN`, and that no `ADR-DRAFT` token survives on
trunk. A human numbering an ADR by hand is covered by the same assertion.

Superseding an ADR still edits the old one's status block, written as
`**Superseded by:** ADR-DRAFT-<KEBAB>` and resolved at merge. The old file
goes in the todo's `Touches`, so two branches superseding the same ADR
serialize instead of racing.

## Alternatives considered
- **Workers pick the number, the integrator fixes collisions** — there is
  nothing to fix against: git reports no conflict, so the duplicate is
  invisible at merge time.
- **Reserve a number when the todo is claimed** — a claim that never lands
  burns a number, and the gap is permanent in an append-only record.
- **Drop numbers, name ADRs by kebab alone** — loses the ordering the record
  is built on, and every existing cross-reference is written `ADR-04`.
- **One bare `ADR-DRAFT` token** — ambiguous as soon as two drafts land in the
  same merge.

## Consequences
- An ADR's number is unknowable while it is being written. Drafts that cite
  each other cite the kebab.
- The integrator edits file contents inside a merge. It is the one content
  change it may make, and it is mechanical.
- `Proposed` becomes a real status, on a branch only. Trunk holds Accepted.
- Numbering a draft is not editing an accepted record, so the append-only rule
  is untouched.
- The duplicate assertion is the only thing standing between the repo and two
  ADR-07s, because git will not raise it.
