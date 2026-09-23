# chore: add the run loop

- **Priority:** high
- **Branch:** chore/add-the-run-loop
- **Touches:** harness/*, .harness.conf
- **Blocked by:** chore-add-the-agent-registry

## Goal
`harness run` works a set of todos to completion or to a human stop without
anyone typing a verb, and survives the death of whatever started it.

## Why
This is the vision in ADR-10: an interactive session says "work through
these", starts the loop, and afterwards reads `status` and `log`. The loop is
shell so that it survives the session, costs no tokens, and reuses `plan`
instead of restating it.

## Notes

### Invocation

`harness run [<stem>...] [--detach] [--once]`. No stems means every todo.
`--detach` re-executes itself under `nohup` with output in `log/run.log` and
prints the pid. `--once` runs a single tick and exits, for tests. It runs from
the trunk checkout, as `integrate` must.

It takes the `run` lock with `harness_lock_wait`. A dead holder is reported,
never stolen, so a crashed loop costs one `harness unlock run --force`. Two
loops dispatching the same todo is the failure that rule prevents.

### One tick, in order

1. Reap: for every record with an exit file and no event yet, write the event.
2. Time out: kill every alive agent past `HARNESS_AGENT_TIMEOUT` seconds since
   its epoch, write `timeout` into its exit file, and log it. The claim stays.
3. Dispatch: unless `PAUSED` exists, while the claim count is under
   `HARNESS_MAX_WORKERS` and `harness_plan` lists a `run` row in the set with
   no `agents/<stem>.worker` record, `dispatch worker --detach`.
4. Judge: if `integrate/pending` exists and a reviewer record is alive, do
   nothing. If it exists and the reviewer has exited, log `reviewer-lost` and
   stop dispatching reviewers; the human recovers. Otherwise, if a submission
   is queued, run `integrate --next`: exit 10 means `dispatch reviewer
   --detach`; exit 1 is a park `integrate` already logged.
5. Exit when nothing is alive, nothing in the set is runnable, nothing is
   pending and the queue is empty. Print what merged, what parked and why,
   what timed out, and which requested stems were held by a todo outside the
   set. Otherwise sleep `HARNESS_RUN_POLL` seconds, default 10, and go to 1.

`PAUSED` with nothing alive exits 3. A park on `@trunk` exits 1 with the park
line; no merge can happen until a human fixes trunk, and workers still running
are left to finish.

Polling, not events: POSIX sh has no portable file watcher, `integrate --wait`
already polls, and a tick is a few reads and `kill -0` calls.

### What it never does

- Dispatch a stem that has a record. At most once is the token bound.
- Respawn a reviewer for a pending whose reviewer died. A human may run
  `dispatch reviewer --detach` again, or clear it with
  `integrate --continue --park needs-human`.
- Steal a lock, clean trunk, or abandon a claim.

### pause and resume

`pause "<reason>"` writes `PAUSED`, which `claim` already honours, so the loop
stops dispatching. Queued submissions still merge, so a pause drains cleanly.
`resume` removes the file. There is no `pause --hard` and no `unpark`: a park
is cleared by resubmitting from the worktree, which `submit` already does.

### Killing an agent

The record's pid is the wrapper. Its child is the CLI and the CLI's children
are gates, and a non-interactive shell puts all of them in one process group
that the loop shares, so `kill -- -pgid` is not an option. Walk the tree with
`ps -A -o pid=,ppid=`, which macOS and Linux both accept, and kill children
before parents. `pkill -P` also works on both but is one more dependency.

### Config

```sh
HARNESS_AGENT_TIMEOUT=3600   # seconds; the loop kills an agent past it
HARNESS_RUN_POLL=10
```

Both belong in `.harness.conf` with the comment above `HARNESS_AGENT_CMD`
gaining one line: a headless agent needs whatever flag its CLI takes to act
without prompting, and that flag goes in the command string, not the harness.

### The test is end to end, with no AI

In a scratch repo, as `check --selftest` builds one, with a fixture todo and
`HARNESS_AGENT_CMD` set to a stub script that does what a worker does:
`git rm` the todo, commit with a valid prefix, `harness submit`. The reviewer
stub runs `harness integrate --continue --verdict pass`. Every box below is
checked that way, and a run that merges the fixture end to end with zero
tokens spent is the proof the loop and the roles are separable.

## Done when
- [ ] `harness run` in the scratch repo merges a fixture todo end to end with
      stub agents, and `harness log` shows claim, dispatch, submit, dispatch
      reviewer and merge for it
- [ ] A second `harness run` refuses, naming the first's pid
- [ ] Killing the loop mid-run leaves the worker to finish and submit, and a
      restarted loop merges that submission
- [ ] A stub worker that exits without submitting keeps its claim, shows its
      exit in `status`, and is not dispatched again until `abandon`
- [ ] A reviewer that dies mid-judgment is reported as `reviewer-lost` and not
      respawned
- [ ] A stub that sleeps past `HARNESS_AGENT_TIMEOUT` is killed with its
      children, recorded as `timeout`, and its claim stays
- [ ] `pause` stops dispatch while a queued submission still merges, the loop
      exits 3 once idle, and `resume` lets a fresh run dispatch again
- [ ] A park on `@trunk` exits the loop with the park line
- [ ] `harness run a b` never claims a todo outside the set, and names a
      requested todo held by one outside it at exit
- [ ] No tick ever has two alive reviewer records, checked with a reviewer
      stub that sleeps
- [ ] `harness gate --full` green, no shell file over `HARNESS_SHELL_MAX_LINES`
