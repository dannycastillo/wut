# feat: status shows the run set

- **Priority:** medium
- **Branch:** feat/status-shows-the-run-set
- **Touches:** ai-harness/verbs/status.sh, ai-harness/lib/run.sh
- **Blocked by:** —

## Goal
`aih status` prints one line per todo in the last run set with its state,
so a todo the loop held or never reached is accounted for without reading
the run log.

## Why
`status` answers "what is in flight". A todo the loop held is not in
flight, so it appears nowhere. On 2026-09-24 a four-todo run dispatched
three; the fourth was held on Touches behind three parked claims, and the
only record was the loop's final report in `run.log`, printed at the moment
it stopped. Asked "what happened to the fourth", `status` had no answer.
The loop's exit code and its reason are in the log only, too.

## Notes
- The set persists in `run/set` (`ai_harness_run_set`), which is how a bare
  `aih run` reuses it. The `@run` events carry `started`, `stopped <why>`
  and `idle`; the per-stem events carry `merged <sha>`, `parked <code>`,
  `dispatched`. `ai_harness_run_plan` gives the hold reason for what is
  neither.
- Shape, only when a set exists:

  ```
  run set (4), started 01:31:54, stopped 01:36:58 rc 1
    fix-plan-holds-...          parked   protected-path
    chore-add-the-platform-...  parked   protected-path
    fix-the-donewhen-...        parked   protected-path
    chore-add-the-install-...   held     conflicts with active claim ... on ai-harness/*
  ```

  States: `running` (claim with a live worker), `submitted`, `parked <code>`,
  `merged <sha>` (the `merged` event), `landed <sha>` (the `landed` event
  the sweep writes for a hand merge), `held <reason>`, `queued` (runnable,
  not yet reached), `gone` (no todo file and neither event).
- The `rc` and the stop reason come from the last `@run stopped` or `idle`
  event after the last `started`; a loop still running shows `running` and
  the lock line already printed.
- Move the report body out of `ai_harness_run_report` into a function both
  it and `status` call, so the loop's final report and `status` cannot
  disagree.

## Done when
- [ ] After a run that held a requested todo, `aih status` names it with the
      hold reason
- [ ] After a run that parked, merged and held one todo each, `aih status`
      shows all three states and the loop's exit code
- [ ] With no run set on disk, `aih status` output is unchanged
- [ ] `aih gate --full` green
