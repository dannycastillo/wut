# doc: design the dispatcher

- **Priority:** high
- **Branch:** doc/design-the-dispatcher
- **Touches:** docs/adr-draft-the-dispatcher.md
- **Blocked by:** —

## Goal
An accepted ADR that decides how agents are started, supervised, noticed and
stopped — the component that turns the harness from a set of verbs a human
types into a loop that runs.

## Why
Full automation is the point of the project, and it is the one part with no
design. ADR-07 decides isolation, claims, roles and merge policy; ADR-09
decides where the gate lives; nothing decides **process lifecycle**. So the
verbs exist and a human is still the scheduler: `dispatch` claims a todo and
`exec`s one agent in one terminal (`harness/verbs/dispatch.sh:32-35`), nothing
notices a worker finishing, and `dispatch.sh:11` refuses the integrator role
outright.

This is a decision, not a build. It will be expensive to reverse — every other
harness todo is being sequenced around a component nobody has specified — and a
reasonable person would pick differently on at least three of the questions
below. AGENTS.md's test for writing an ADR is met on both counts.

## Notes

### What is already decided, and must not be re-litigated

- ADR-07: one todo, one branch, one worktree; git's ref lock arbitrates claims;
  state in `--git-common-dir`; exactly one integrator; the session that writes a
  diff neither reviews nor merges it; anything not perfectly clean parks.
- ADR-08: ADRs are drafted unnumbered — so this one is
  `docs/adr-draft-the-dispatcher.md`, `# ADR-DRAFT-THE-DISPATCHER`, status
  Proposed, numbered by the integrator at merge.
- ADR-05: macOS and Linux only. POSIX sh, `/bin/sh` is bash 3.2.57.
- `harness/**`, `AGENTS.md` and `.harness.conf` park permanently. The harness
  can never merge its own construction.

### The questions the ADR has to answer

**1. Where does "full automation" stop?** The boundary above is permanent, so
the end state is not "no human." Define it: a human files todos and reads
merges, agents do everything between — or something else, stated. An unbounded
goal cannot be declared reached.

**2. Daemon or one-shot?** A long-running `harness up` that holds the loop, or
`dispatch --detach` invocations driven by something outside the harness (tmux,
launchd, cron). A daemon must outlive the terminal that started it and needs its
own liveness story; a one-shot pushes scheduling to a tool this repo then
depends on.

**3. What substrate?** tmux panes, bare background processes with log files, or
a job runner. tmux is attachable, which matches the harness's habit of reporting
state rather than hiding it; it is also a new dependency for a tool that
currently needs only git and a shell.

**4. How is liveness known?** `status` reports claims, not processes: a claim
whose agent died is indistinguishable from one being worked. Decide what is
recorded (pid, heartbeat, both), what "dead" means, and what happens then. The
lock precedent is binding — report, never steal.

**5. How is a submission noticed?** Polling `submitted/`, or `submit` waking the
integrator directly. Polling is dumb and survives anything; triggering makes the
integrator the worker's child process, which needs an explicit ruling on whether
ADR-07's separation is about sessions or about process trees.

**6. Who runs the judgment half?** `integrate --next` exits 10 by design, so an
agent must read the packet and answer. That makes the integrator a dispatched
role with a role doc — `harness dispatch integrator`, which `dispatch.sh:11`
currently refuses — and it must be a singleton even when two submissions land
together. Decide whether the supervisor needs its own lock or leans on the one
`integrate` already takes.

**7. How are agents invoked unattended?** An agent that stops for approval is
not unattended. Headless mode and permission scope are platform concerns, and
`chore-add-the-platform-adapters` forbids adapters carrying behaviour, so
`HARNESS_AGENT_CMD` in `.harness.conf` is the only AI-agnostic home. Decide
whether the integrator needs a separate command and permission scope, since it
is the only role that writes trunk.

**8. How does it stop?** The question that decides whether this can be left
running. `PAUSED`, `pause --hard`, a consecutive-park budget, a wall-clock or
spend budget, and the behaviour on a park storm. A loop with no stop is the
thing not to build.

**9. What happens while a human is working?** A dirty trunk parks the queue
(ADR-07), but workers never touch trunk. Decide whether the dispatcher keeps
dispatching workers while trunk is dirty, or quiesces entirely.

**10. What must it never do?** At minimum: exceed `HARNESS_MAX_WORKERS`, steal a
lock, restart a worker whose claim still stands, or dispatch a todo whose
Touches intersect an active claim. Write these as the invariants, since they are
what a reviewer will check the implementation against.

### Sequencing is part of the decision

There is a staged answer worth weighing rather than assuming: dispatching
**workers** is safe today, because merging still needs a human, so the loop
cannot run away. Dispatching the **integrator** is what needs
`chore-retire-the-human-merge-gate` and its `pause`/`log` verbs first. If the ADR
takes that split, automation can start now instead of queueing behind the
largest todo in the backlog.

### Shape

AGENTS.md's ADR file shape, and its instruction that an ADR records a decision
rather than a plan. Alternatives get the one reason each lost. The
implementation does not belong here — it belongs in the todos this one files.

## Done when
- [ ] `docs/adr-draft-the-dispatcher.md` exists, `**Status:** Proposed`, in
      AGENTS.md's file shape, drafted per ADR-08 rather than numbered
- [ ] Each of the ten questions above is answered in the Decision, or listed
      explicitly as deliberately not decided and why
- [ ] The automation boundary is stated as an end state a human can test
      against, not as a direction
- [ ] The invariants from question 10 are written as assertions an
      implementation can be checked against
- [ ] Alternatives considered names the rejected option for questions 2, 3 and
      5 at minimum, each with the one reason it lost
- [ ] Consequences names what the harness then has to maintain, including any
      new dependency
- [ ] The implementation is filed as separate todos, with their Touches and
      ordering, and this todo builds nothing
- [ ] No ADR-07, ADR-08 or ADR-09 Decision text is edited; if the design
      contradicts one, the draft carries `**Supersedes:**` and says so
- [ ] `harness gate --full` green
