# feat: show aih status as one table, a row per todo

- **Priority:** medium
- **Branch:** feat/status-table
- **Touches:** ai-harness/verbs/status.sh, ai-harness/lib/run.sh, ai-harness/README.md
- **Blocked by:** —

## Goal
`aih status` opens with one aligned table, a row per open or in-flight todo,
that says for each what state it is in and why.

## Why
Today a human needs `status` and `plan` together, plus `todo/*.md`, to learn
what is happening. The four hand-aligned sections (`claims`, `agents`,
`pending`/`parked`, `lock`) each use their own `printf` widths, and a todo's
story is spread across all of them.

## Notes

Target shape, built by hand from `plan` and the todo fields on 2026-09-24:

```
TODO                          PRI     STATE      WHY
chore-raise-test-coverage     medium  worker     pid 17142, 4m
chore-add-ci                  high    runnable
feat-help-above-results       medium  held       shares list_picker_test.go with chore-raise-test-coverage
doc-record-demo-gifs          medium  blocked    by feat-help-above-results
chore-add-the-install-script  low     stuck      branch exists unclaimed — git branch -d it
```

- Order the rows by in-flight first, then runnable, then held, then blocked.
  Within each group sort by priority. Once in-flight work comes first, the
  table reads top-down as "what's happening, what's next".
- STATE comes from the most specific source that has an answer. Parked and
  pending come from `ai_harness_ig_file`. Worker and reviewer come from
  `ai_harness_agent_records`/`ai_harness_agent_state`, then claimed. When
  nothing is in flight, take the `run`/`hold` verdict from `ai_harness_plan`
  (`lib/graph.sh:69`), whose reason becomes WHY. Split `hold` into `blocked`
  (a Blocked-by reason) and `held` (a Touches conflict) by matching the
  reason text, or better, by having `ai_harness_plan` emit a kind. If it
  emits a kind, `lib/graph.sh` joins Touches. Say so first, because
  `run.sh:15` consumes that output.
- Priority comes from `ai_harness_todo_field <file> Priority`.
- Leave Touches out of the table. It is what makes `plan` rows wrap.
  `aih plan` keeps the overlaps section.
- Keep the current `!` warnings (worktree gone, exited without finishing,
  stale lock). They become WHY text or a line beneath the table, not a
  separate section. Locks and the `run set` footer
  (`ai_harness_run_status`, `lib/run.sh:212`) stay below the table. The
  footer is the only place a human sees when the loop started, when it
  stopped, and why (`started 08:29:58, stopped 08:30:56 rc 1: <reason>`).
  Keep all three, and keep its per-todo lines (`landed 6fe71be`).
- "exited without finishing" misfires today. A worker or reviewer whose todo
  then parked or was rejected still has a claim and no `submitted` file, so
  `status.sh` flags it. On 2026-09-24 both agents of a rejected
  `chore-raise-test-coverage` showed it. A row's WHY must not repeat that:
  when the todo is parked, the park is the answer.
- Fit 100 columns. Truncate WHY with `…` rather than wrap. Size the columns
  from the data (one `awk` pass) instead of fixed `%-30s` widths.
- Nothing parses `status` output: `run` calls `ai_harness_plan` directly, and
  the selftest does not exercise the verb. The format is free to change.
- The README lines 73, 97, 117 and 128 describe `status` by its old sections.
  Update the one-line descriptions.
- A todo that merged in this run set and is no longer in `todo/` still
  appears in the `run set` footer. Don't duplicate it in the table.

## Done when
- [ ] `aih status` prints a header row, then one row per todo in `todo/` plus
      any claimed todo, with columns TODO, PRI, STATE, WHY
- [ ] Rows are ordered in-flight, runnable, held, blocked, then by priority
- [ ] With nothing claimed, every row's STATE and WHY agree with `aih plan`
- [ ] A running worker's row shows its role, pid and age
- [ ] A parked todo's row shows its park code and detail
- [ ] No line exceeds 100 columns
- [ ] The existing `!` warnings still appear, except "exited without
      finishing" for an agent whose todo is parked
- [ ] The `run set` footer still shows the loop's start time, and its stop
      time, exit code and reason once it has stopped
- [ ] README's `status` descriptions match the new output
- [ ] `aih gate --quick` passes
