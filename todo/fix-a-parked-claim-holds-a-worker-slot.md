# fix: a parked claim holds a worker slot

- **Priority:** medium
- **Branch:** fix/a-parked-claim-holds-a-worker-slot
- **Touches:** ai-harness/lib/state.sh, ai-harness/verbs/status.sh
- **Blocked by:** —

## Goal
`AI_HARNESS_MAX_WORKERS` bounds agents that are running, so a claim whose
worker has exited holds its paths but not a slot.

## Why
`ai_harness_claim_count` counts claim files, and `run` dispatches only
while that count is below the cap. A parked claim keeps its file until a
human merges by hand, and every harness todo parks by design. In a mixed
run, three parks fill the cap and the loop exits with nothing else
dispatched. Traced against the backlog of 2026-09-23 with `aih run --all`:
CI parks, the license parks, coverage merges, the plan fix parks, and the
loop stops having merged one todo of seventeen.

The cap exists to bound cost and load. A parked claim runs nothing.

## Notes
- A claim counts while it could still produce work: its worker record is
  absent (a hand claim, or one not yet dispatched) or its worker is alive.
  A claim whose worker has exited, whichever way, counts for nothing. Its
  paths stay reserved through `plan`, which reads claims, not this count.
- `ai_harness_claim_count` in `ai-harness/lib/state.sh` is the one place to
  change; `run`'s dispatch loop and `claim`'s cap check both call it, so a
  hand claim honours the same rule. `ai_harness_agent_file` and
  `ai_harness_agent_alive` in `ai-harness/lib/agents.sh` give the test.
- `status` prints `claims (n of MAX)`; keep that as the slot count and add
  how many claims hold paths only, so the two numbers stop looking like one.
- The scratch loop suite (`/tmp/hx.*` fixtures, a stub agent, `prot` mode
  parks on protected-path) reproduces this with `AI_HARNESS_MAX_WORKERS=1`
  and two todos: today the second is never dispatched.

## Done when
- [ ] With the cap at 1 and one claim parked, `aih run` dispatches the next
      runnable todo
- [ ] With the cap at 1 and one worker alive, `aih run` and `aih claim`
      both still refuse a second
- [ ] `aih status` shows slots used and claims holding paths only as two
      numbers
- [ ] `aih gate --full` green
