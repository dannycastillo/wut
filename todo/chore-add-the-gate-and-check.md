# chore: add the gate and the mechanical check

- **Priority:** high
- **Branch:** chore/add-the-gate-and-check
- **Touches:** harness/verbs/check.sh, harness/lib/check.sh, AGENTS.md
- **Blocked by:** —

## Goal
`harness check` answers mechanically whether a branch is fit to merge.

## Already landed
`chore/add-claim-and-gate` shipped `gate` with its exclusive-gate lock, and the
preflight that refuses to run a declared gate whose tool is absent. Only
`check` is left.

## Why
The gate is what replaces a human reading every diff, so it lands before the
thing that trusts it. `check` is the part of review that is mechanical, and
exposing it to workers means a Touches violation costs a local failure instead
of a rejection round.

## Notes

### check

Read-only, no checkout, working from `git diff --name-only <trunk>...<branch>`.

Hard stops: `AGENTS.md`; `harness/**` or `.harness.conf`; a `HARNESS_PROTECTED`
path not declared in Touches; a hunk inside an accepted ADR's `## Decision`; two
`docs/adr-NN-*` sharing an `NN`; a surviving `ADR-DRAFT` token; a deleted todo
other than the claimed one; an undeclared path intersecting another active
claim's Touches; an added `t.Skip(`.

Soft flags: an undeclared path nobody has claimed; a diff over
`HARNESS_DIFF_SOFT_LIMIT`; net-negative test lines beside non-test changes.

Every result is a code from a closed set. `status` is only readable if the
vocabulary is finite, so a situation with no code is `unknown`, which is itself
a stop.

The duplicate-ADR assertion is the one check with no git backstop (ADR-08) —
git reports no conflict there at all — so it gets a deliberate test rather than
an incidental one.

### AGENTS.md

"Before every commit" stops naming `go build` and `go vet` and says
`harness gate --quick` instead (ADR-09). That is the only AGENTS.md edit here;
the merge rules wait until there is an integrator to hand them to.

## Done when
- [ ] `check` returns each hard stop above with its reason code
- [ ] Two hand-made `docs/adr-07-*.md` files fail `check` as `adr-duplicate`
- [ ] A diff touching `AGENTS.md` fails as `protected-path`
- [ ] A situation with no matching code returns `unknown` rather than passing
- [ ] AGENTS.md says `harness gate --quick`
- [ ] `sh -n` passes on every shell file
- [ ] `go build ./...` and `go vet ./...` pass
