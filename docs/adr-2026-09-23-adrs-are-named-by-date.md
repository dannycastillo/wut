# ADR 2026-09-23: ADRs are named by date, and the harness knows nothing of them

- **Status:** Accepted
- **Date:** 2026-09-23
- **Supersedes:** ADR-08

## Context
ADR-08 fixed the number race with drafts numbered at merge. Building that
put a draft convention, a renumbering step inside `integrate`, and three
check codes into the harness, all to serve one fact: sequential numbers are
assigned by authors who cannot see each other. The harness is meant to be
lifted into repos that have no ADRs at all.

## Decision
An ADR is `docs/adr-YYYY-MM-DD-short-kebab-title.md`, headed
`# ADR YYYY-MM-DD: Title`, dated the day it is written. It is referred to by
its file name. The ten numbered ADRs keep their names.

The harness carries no ADR logic: no draft convention, no numbering, and no
check code that names `docs/`. Append-only is a rule in AGENTS.md that the
reviewer reads the diff against, like every other rule there.

## Alternatives considered
- **Keep numbering at merge** — sixty lines and three codes in every repo the
  harness is installed into, for a convention most of them will not have.
- **Number, and let a human fix duplicates** — git never reports the duplicate,
  so nobody is told to fix it.
- **Kebab only, no date** — loses the chronological order `ls docs/` gives.
- **A timestamp to the second** — unreadable, and the date already turns the
  only collision into a same-path conflict, which git reports.

## Consequences
- Two ADRs on one day with the same title conflict at merge and park. That is
  the visible failure the numbers never gave.
- The `adr-decision` stop is gone. An edit to an accepted ADR's Decision is
  caught by the reviewer or not at all.
- `check --selftest` covers nine codes instead of thirteen.
- The record has two naming schemes. The break is dated and this file is it.
