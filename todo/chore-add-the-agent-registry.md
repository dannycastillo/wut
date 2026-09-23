# chore: add the agent registry, detached dispatch and log

- **Priority:** high
- **Branch:** chore/add-the-agent-registry
- **Touches:** harness/*, .harness.conf
- **Blocked by:** chore-rename-the-integrator-to-reviewer

## Goal
Every agent the harness starts is a record on disk with its pid, role, log and
exit code, it outlives the shell that started it, and `harness log` reads the
history without a loop running.

## Why
The loop in ADR-10 holds no state, so the state has to exist before the loop
does. "The loop dies, the workers continue" is only true if a restarted loop
can find the workers, and "at most once" is only enforceable if a record says
a stem was already dispatched.

## Notes

### The spawn

`dispatch worker --detach` claims as today, then starts the agent through a
wrapper that captures the exit code, because a detached process's status is
unreadable from any other shell:

```sh
nohup sh -c '"$@" >"$0.log" 2>&1; printf "%s\n" "$?" >"$0.exit"' \
    "$rec" $HARNESS_AGENT_CMD "$prompt" </dev/null >/dev/null 2>&1 &
```

`$HARNESS_AGENT_CMD` stays unquoted, as the `exec` path already has it, so
the command may carry its own flags. The recorded pid is the wrapper's. Its
child is the CLI, and the CLI's children are gates; killing the wrapper alone
orphans them, which is the loop todo's problem to solve, not this one's.

macOS has no `setsid`. `nohup`, `&`, and every fd redirected is the portable
way to survive the parent, and it has to be verified by killing the parent,
not assumed.

### The record

`$(harness_state_dir)/agents/<stem>.<role>`, key=value like every other state
file, parsed with `harness_kv_get`: `role`, `stem`, `pid`, `cmd`, `started`,
`epoch`, `log`. The wrapper writes `<record>.exit` when the agent ends. Alive
means no exit file and `kill -0` succeeds; the epoch is there so a caller can
notice a pid younger than its record. Logs go to
`$(harness_state_dir)/log/<stem>.<role>.log` and are never deleted by the
harness; they are the only place an agent's output survives.

### Who clears a record

The record is the at-most-once guard, so it is removed exactly where the claim
is: `abandon`, `harness_ig_cleanup`, and the landed arm that
`fix-a-hand-merge-leaves-its-submission-queued` adds. Nothing else touches it.
After `abandon` the stem is unclaimed and unrecorded, so a loop will dispatch
it again; that is the human's deliberate re-run.

### The reviewer's dispatch

`dispatch reviewer --detach` refuses unless `integrate/pending` has
`phase=judge`. It runs in the trunk checkout, since `integrate --continue`
must, and its prompt names the packet file. For that to exist,
`integrate --next` writes what `harness_ig_packet` prints to
`integrate/packet` as well as stdout. A human can run this after their own
`integrate --next` exits 10, with no loop involved.

### Events and log

`$(harness_state_dir)/events`, one line per event, appended with one `printf`
so lines do not interleave:
`<iso-time> <stem> <role or -> <event> <detail>`. Written by `claim`,
`dispatch`, `submit`, `abandon`, every park and merge in `integrate`, and by
the reaper when it notices an exit file.

`harness log [<stem>]` prints events and the `Harness-*` trailers of
`git log --first-parent $HARNESS_TRUNK` as one timeline. The trailers are the
durable record; events are the annotations, and `rm -rf .git/harness` losing
them is by design (ADR-07's state rule survives in ADR-10).

`status` grows three sections: agents with alive or exited and age, parks with
their codes, and a pending judgment if one exists.

### Testing without an AI

`HARNESS_AGENT_CMD` can be any command, so the tests use stubs: `true` for an
agent that exits at once, `sh -c 'sleep 3; touch "$1"' --` for one that
outlives its parent. No test here needs a model, and the loop todo builds on
the same stubs.

## Done when
- [ ] `dispatch worker --detach` returns at once and writes
      `agents/<stem>.worker` with pid, log path and start time; the log holds
      the agent's output
- [ ] Killing the shell that ran `dispatch --detach` leaves the agent running
      to completion, and its exit code lands in `<record>.exit`
- [ ] `dispatch reviewer --detach` starts a session in the trunk checkout with
      the packet path in its prompt, and refuses when nothing is pending
- [ ] `integrate --next` writes the packet to `integrate/packet`
- [ ] `events` records claim, dispatch, submit, park, merge, abandon and agent
      exit, one line each
- [ ] `harness log` prints events and merge trailers in one timeline, and
      `harness log <stem>` filters to one stem
- [ ] `status` lists agents, parks and a pending judgment
- [ ] `abandon` and a merge remove the stem's records; the log files stay
- [ ] `harness gate --full` green, `harness check --selftest` passes, no shell
      file over `HARNESS_SHELL_MAX_LINES`
