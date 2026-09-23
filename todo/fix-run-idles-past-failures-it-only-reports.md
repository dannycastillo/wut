# fix: run idles past failures it only reports

- **Priority:** medium
- **Branch:** fix/run-idles-past-failures-it-only-reports
- **Touches:** ai-harness/lib/run.sh, ai-harness/verbs/run.sh
- **Blocked by:** —

## Goal
`aih run` exits 1 when a worker exits without submitting, and stops
redispatching a todo whose dispatch keeps failing.

## Why
Seen while renaming the tree: a dispatch that failed with "No such file"
was retried every tick, forever, with the loop lock held, and a worker that
exited 1 without submitting left the loop to report `idle` and exit 0. Both
are a stop for a human that the loop reports and then walks past. An
unattended run is only trustworthy if exit 0 means everything merged.

## Notes
- `ai_harness_run_dispatch` logs "not retried this tick" and retries next
  tick. Count failures per stem in `run/` and stop with exit 1 after the
  second, naming the stem.
- `ai_harness_run_idle` treats a claim whose worker exited without a
  submission as nothing in flight. `status` already detects that case (claim
  present, no `submitted/<stem>`, agent record `exited`); the loop should use
  the same test before declaring idle, and exit 1 with the `status` hint.
- A timeout kill is the same case with a different exit word; F in the
  scratch loop tests expects rc 0 today and should expect 1.
- `--once` still exits after one tick; only the exit code changes.

## Done when
- [ ] A stub worker that exits 1 without submitting makes `aih run` exit 1
      and name the stem
- [ ] A stub whose dispatch fails twice stops the loop with exit 1 instead of
      looping
- [ ] Timeout kills exit 1 the same way
- [ ] Exit 0 still means every todo in the set merged or was held with a
      reason
- [ ] `aih gate --full` green
