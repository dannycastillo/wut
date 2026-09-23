# chore: rename the integrator to reviewer and drop the third role

- **Priority:** high
- **Branch:** chore/rename-the-integrator-to-reviewer
- **Touches:** harness/*, .harness.conf
- **Blocked by:** —

## Goal
The harness names two roles, worker and reviewer, and nothing in it refers to
the optional third role ADR-07 described.

## Why
ADR-10 supersedes ADR-07 with two roles. The word reviewer already meant the
unbuilt third role, in the README table, in two config keys and in a merge
trailer, so the rename has to delete that meaning before the loop todos can
cite the new one without ambiguity.

## Notes

### Rename

- `harness/roles/integrator.md` becomes `harness/roles/reviewer.md`. Add what
  it does not yet say: it runs from the trunk checkout because `integrate`
  demands it, and a needs-running box is exercised in the worker's worktree,
  whose path is `worktree=` in `submitted/<stem>`, changing nothing there.
- `harness/README.md`: the roles table shrinks to two, the verb table's owner
  column follows, the `Design:` line cites ADR-10, and the Status block is
  refreshed. It still lists `plan`, `dispatch`, `submit`, `check` and
  `integrate` as unbuilt; they are built. The unbuilt list becomes `run`,
  `pause`, `resume` and `log`.
- Comments that say integrator where they mean the role: `lib/common.sh:11`,
  `lib/integrate.sh:1`, `lib/packet.sh:1`, `verbs/submit.sh:1,85,90`,
  `bin/harness:2`. The verb `integrate` keeps its name, and so does `EX_JUDGE`.

### Delete

- `HARNESS_REVIEW` and `HARNESS_REVIEW_SPAWN` from `.harness.conf`, and the
  `Harness-Review:` line `harness_ig_message` writes. A trailer that always
  says `none` records nothing.
- The `reviewer | integrator` arm in `verbs/dispatch.sh` becomes `reviewer`
  alone, refusing with "arrives with chore-add-the-agent-registry".

### One behaviour change, small

The boot prompt in `verbs/dispatch.sh` ends "stop and report what you did".
`roles/worker.md` ends with `harness submit`. Both are read by the same worker,
and the prompt wins because it arrives last. Make the prompt end with
`harness submit` so the manual path and the loop agree.

### Not this todo

ADR-07, ADR-08 and ADR-09 keep their wording. They are records. The AGENTS.md
merge rule is `chore-retire-the-human-merge-gate`.

## Done when
- [ ] `grep -rw integrator harness .harness.conf` finds nothing
- [ ] `harness/roles/reviewer.md` exists, names where a needs-running box is
      run, and `integrator.md` is gone
- [ ] `HARNESS_REVIEW` and `HARNESS_REVIEW_SPAWN` are gone from the config, and
      `harness_ig_message` writes no `Harness-Review` line
- [ ] The README describes two roles, cites ADR-10, and its Status block lists
      exactly the verbs `harness help` does not
- [ ] The dispatch boot prompt ends with `harness submit`
- [ ] `harness gate --full` green, `harness check --selftest` still passes
