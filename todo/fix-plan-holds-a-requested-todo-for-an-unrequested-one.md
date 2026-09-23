# fix: plan holds a requested todo for one nobody requested

- **Priority:** medium
- **Branch:** fix/plan-holds-a-requested-todo-for-an-unrequested-one
- **Touches:** harness/lib/graph.sh, harness/lib/run.sh, harness/verbs/plan.sh, harness/verbs/run.sh
- **Blocked by:** —

## Goal
`harness run <stems>` dispatches every requested todo that could safely run,
and a todo outside the set never holds one inside it on `Touches` alone.

## Why
`harness_plan` ranks every open todo and walks down; each one it marks
runnable has its `Touches` treated as taken for everything below. It does
this for all todos, requested or not. `run` then filters the runnable rows to
its set, after the walk. So:

```
harness run fix-help-text-copy
```

holds `fix-help-text-copy` as "conflicts with runnable chore-raise-test-coverage
on cmd/root.go", dispatches nothing, and exits idle, even though nothing
will ever claim `chore-raise-test-coverage` during this run. The failure is
under-dispatch, never mis-dispatch: the loop does less than asked and says
why. On this backlog, where five todos meet on `cmd/root.go` and the test
files, any targeted run of two or three todos hits it.

## Notes

`harness_plan` in `harness/lib/graph.sh` builds `_runs`, the list of runnable
todos above the current one, and `harness_plan_clash` checks the current
todo's `Touches` against it. That list is where the fix goes: only todos in
the set should enter it. Give `harness_plan` an optional set (stems, one per
line, on stdin or as arguments) and skip todos outside it in the walk
entirely, so they are neither runnable nor held. Todos that are claimed still
print as claimed whatever the set, and an active claim still holds anything
it meets: a human may have claimed the unrequested one by hand, and `claim`
refuses the collision on either side regardless.

`Blocked by` is not `Touches`. A requested todo blocked by an unrequested one
stays held; that is a dependency, not a scheduling choice.

`harness plan <stem>...` takes the same set, so a human can preview what
`run <stem>...` will do. With no arguments both behave as today.

`harness_run_next` in `harness/lib/run.sh` then needs no filter of its own,
and the "held by a todo outside the set" line in `harness_run_report` has
nothing left to report; drop both.

The greedy pass exists so the first runnable row is always safe to claim
without colliding with the second. That still holds inside the set, which is
the only place this loop ever claims.

## Done when
- [ ] In a scratch repo with two todos meeting on one path, the higher one
      unrequested: `run <lower>` dispatches and merges it
- [ ] `harness plan a b` lists only `a`, `b` and whatever is claimed
- [ ] `harness plan` with no arguments prints exactly what it prints today
- [ ] A requested todo blocked by an unrequested open todo is still held
- [ ] `harness gate --full` green, `check --selftest` passes
