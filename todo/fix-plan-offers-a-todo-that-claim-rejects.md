# fix: plan offers a todo that claim rejects

- **Priority:** low
- **Branch:** fix/plan-offers-a-todo-that-claim-rejects
- **Touches:** ai-harness/lib/graph.sh, ai-harness/verbs/plan.sh
- **Blocked by:** —

## Goal
A todo that fails `ai_harness_todo_validate` is listed by `plan` as held,
with the validator's reason, instead of as runnable.

## Why
`plan` reads Priority, Touches and Blocked by straight from the file and
never runs the validator, so a todo whose Branch line disagrees with its
filename is offered as runnable. `claim` then refuses it with "did not
validate". Under `run` that is a dispatch failure every tick, and after
fix-run-idles-past-failures-it-only-reports it stops the loop. Seen on
fix-a-hand-merge-leaves-its-submission-queued, whose Branch line said
`fix/the-hand-merge-cleanup`.

## Notes
- The validator is `ai_harness_todo_validate` in `ai-harness/lib/todo.sh`;
  it warns each reason and returns 1. `plan`'s hold column needs the first
  reason as text, so either capture stderr or add a variant that prints.
- A held todo must not reserve its Touches, or a bad file would serialize
  good ones behind it.

## Done when
- [ ] A todo whose Branch line does not match its filename shows under
      `held` in `aih plan` with the reason, and `aih run` never dispatches it
- [ ] Its Touches do not hold back any other todo
- [ ] `aih gate --full` green
