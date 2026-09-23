# fix: the harness forgets every park

- **Priority:** high
- **Branch:** fix/the-harness-forgets-its-parks
- **Touches:** harness/lib/integrate.sh, harness/lib/packet.sh, harness/verbs/submit.sh
- **Blocked by:** —

## Goal
Every verdict leaves a record that outlives the state directory — parks as well
as merges — and the two trailers that claim to carry the judgment carry it
instead of restating that a merge happened.

## Why
`chore-retire-the-human-merge-gate` states the record's design: "That split is
what makes the state directory disposable: the permanent record is in the merge
commits." That holds for merges and fails for parks. A merge writes eight
`Harness-*` trailers into git forever; a park writes `parked/<todo-stem>` into
the state directory, and `harness/verbs/submit.sh:87` deletes it the moment the
worker resubmits.

So the harness permanently remembers every success and forgets every failure,
which is backwards. The question that decides whether the integrator earns its
authority — how often does the gate catch something a worker missed? — cannot
be answered from the repo today, and that is the evidence
`chore-retire-the-human-merge-gate` should be decided on. Hence its priority
above that todo.

## Notes

### Where the record lives now

| What | Written by | Survives |
| --- | --- | --- |
| eight `Harness-*` trailers | `harness_ig_message`, `packet.sh:52-58` | forever, in git |
| `integrate/green` | phase 6 | one SHA, overwritten each merge |
| `parked/<stem>` | `harness_ig_park`, `integrate.sh:44-56` | until the next `submit` |

A park has no commit to hang trailers on, which is why it needs somewhere else
to go. The constraint is AGENTS.md's: `main` is only ever written by
`git merge --no-ff`, so the integrator cannot commit a park record to trunk.

Two directions, both honest:

- **Append-only in the state dir** (`parked/history`, or the journal the MVP
  plan named and never built). Cheap, and lost with the state directory — which
  matters less if the claim is only that it survives a resubmit, not a `rm -rf`.
- **On the worker's branch.** The branch and worktree survive a park by design,
  so the record can live where the work does and reach trunk with the eventual
  merge. Strictly better provenance, and it means a merge's trailers can say
  the submission was parked twice before it landed.

Pick one; do not build both.

### The two decorative trailers

`packet.sh:55-56` print string literals:

```sh
printf 'Harness-Check: clean\n'
printf 'Harness-Donewhen: pass\n'
```

Both are true today only because a merge cannot happen without `check=clean` and
`--verdict pass` — so they restate the existence of the merge commit and record
no judgment. They become actively wrong when `chore-widen-the-check` adds soft
flags, since a submission will then merge with a check that is not clean. Read
both from `integrate/pending` and the verdict.

## Done when
- [ ] A park, then a resubmit, then a merge: the merge commit can be traced back
      to the park, without reading the state directory
- [ ] `rm -rf "$(git rev-parse --git-common-dir)/harness"` loses no park that
      has already been resolved
- [ ] `Harness-Check` and `Harness-Donewhen` are read from the pending record,
      not printed as literals
- [ ] A deliberate park of a real submission is exercised end to end, since the
      park path has never run
- [ ] `harness gate --full` green, `sh -n` clean on every touched file
