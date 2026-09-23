# harness

One todo, one branch, one worktree. Trunk is written only by a merge.

The harness lets several agents work one repo's backlog at once without
landing in the same file. It is plain POSIX sh plus git, and nothing else.
The repo's rules stay in `AGENTS.md`; the harness enforces them mechanically.
Design: ADR-10 (a shell loop schedules two roles), ADR-08 (ADR numbering),
ADR-09 (the gate lives in config).

## Status

Partly built. `harness help` lists what your copy has.

- Every verb in the tables below is built, and both role docs exist.
- `AGENTS.md` names the two roles and no language. Trunk is written only by
  `integrate`; the hooks refuse anything else unless `HARNESS_ALLOW_TRUNK=1`.
- Not yet lifted into another repo: `install.sh` and the adapters are open
  todos.

## Setup

Each worktree runs its own copy of the harness, so use a shell function rather
than a fixed `PATH` entry:

```sh
harness() { "$(git rev-parse --show-toplevel)/harness/bin/harness" "$@"; }
harness doctor --selftest
```

- `doctor` checks the state dir, trunk, the worktree root, every declared
  gate's tools, the hooks, and the `AGENTS.md` block's checksum. It changes
  nothing unless given `--repair`, which rebuilds claims from git and installs
  the hooks as symlinks into the shared hooks directory.
- A human merging by hand runs `HARNESS_ALLOW_TRUNK=1 git merge --no-ff`. The
  hook says so when it refuses.
- A harness invoked from another worktree's tree refuses to run. It would read
  the wrong `.harness.conf`.

## The two roles

A different session plays each role. The session that writes a diff never
reviews it. Each role ends its work by running one verb, and the verb does
every write to shared state: no agent runs `git merge`.

| Role     | Does                                                                  | Never                                          |
| -------- | --------------------------------------------------------------------- | ---------------------------------------------- |
| worker   | claims one todo, works it in its own worktree, rebases, `submit`s     | merges, or edits outside its `Touches`         |
| reviewer | verifies a packet's **Done when**, then `integrate --continue`s       | rebases a branch, resolves a conflict, or cleans trunk |

A human owns everything the two roles stop on: parks, stale locks, pauses.

## Verbs, by owner

`*` marks a verb that is not built yet.

| Owner      | Verb                        | Does                                                          |
| ---------- | --------------------------- | ------------------------------------------------------------- |
| worker     | `claim <todo>`              | cuts the branch and worktree from trunk; prints the path      |
|            | `path <todo>`               | prints a claim's worktree, for `cd "$(harness path <todo>)"`  |
|            | `gate --quick` / `--full`   | runs the declared checks, one line each                       |
|            | `submit`                    | requires a clean tree and a green `gate --full`, then queues  |
|            | `abandon <todo>`            | gives the claim back; keeps a dirty tree unless `--force`     |
| reviewer   | `check`                     | read-only diff check: paths against `Touches`, hard stops     |
|            | `integrate`                 | baseline gate, packet, merge, post-merge gate; or park        |
| human      | `status`                    | claims and locks in flight                                    |
|            | `doctor [--repair]`         | asserts the setup; `--repair` rebuilds claims from git        |
|            | `unlock <name> --force`     | releases a lock whose holder is dead                          |
|            | `plan`, `dispatch`          | says what can run and why; claims one and starts an agent     |
|            | `log [<todo>]`              | events and merge trailers, one timeline                       |
|            | `run [<todo>...]`           | works a set of todos unattended, until idle or a stop         |
|            | `pause`, `resume`           | stops new claims; queued work still merges; lifts it          |
|            | `stop [--agents]`           | kills the loop and every agent; claims and trees stay         |
| anyone     | `help`                      | lists the verbs in this copy                                  |

Exit codes: `0` ok, `1` failed, `2` usage, `3` paused, `4` the environment
cannot run the gate, `10` judgment needed.

## Running N workers

`run` is a shell loop, not an agent (ADR-10). It holds no state: every tick it
reaps exited agents, kills any past `HARNESS_AGENT_TIMEOUT`, dispatches
workers up to `HARNESS_MAX_WORKERS` from `plan`, and moves the queue one step:
`integrate --next`, then a detached reviewer for the packet. It exits when
nothing is runnable and nothing is in flight, or on a stop a human owns.

```sh
harness run fix-a fix-b --detach           # remembers the set; a bare run reuses it
harness run --all --detach                 # every todo
harness status                             # claims, agents, pending, parks
harness log                                # what happened
harness pause "trunk needs a look"         # no new claims; queued work still merges
harness stop                               # kill the loop and every agent
```

- Killing the loop kills nothing else. Agents finish and submit; a restarted
  loop finds their submissions and carries on.
- Dispatch is at most once. A worker that exits without submitting, a park and
  a reject are terminal until a human acts: `abandon` to run it again, or
  resubmit from its worktree.
- A reviewer that exits with the judgment pending is reported `lost` and never
  respawned. `harness dispatch reviewer --detach` starts another by hand.
- A park on `@trunk` stops the loop. Trunk is a human's to fix.

By hand, one worker at a time:

```sh
harness plan                               # what can run now, and why the rest cannot
eval "$(harness dispatch worker)"          # claims the top runnable todo, starts the agent
harness status                             # what is claimed, by whom, touching what
```

`dispatch` starts `$HARNESS_AGENT_CMD` with a one-line boot prompt that ends
with `harness submit`. With the command unset, it prints the `cd` and the
prompt for you to run yourself. `--detach` starts it under `nohup` in its own
process group, so it outlives the shell that started it, and records it:

```sh
harness dispatch worker --detach           # prints the pid
harness dispatch reviewer --detach         # after an integrate --next that exited 10
harness status                             # agents, alive or exited, and how long
harness log fix-something                  # everything that happened to one todo
```

A headless agent needs whatever flag its CLI takes to act without prompting.
That flag goes in `HARNESS_AGENT_CMD`, not in the harness.

- `HARNESS_MAX_WORKERS` caps active claims. `claim` refuses past it.
- Two racers on one todo: git's ref lock lets exactly one create the branch.
- Two todos with overlapping `Touches`: `claim` refuses the second while the
  first is active, and `plan` names the path they meet on.
- Gates in `HARNESS_EXCLUSIVE_GATES` hold a global resource. A lock serializes
  them across every worktree, so parallel workers queue instead of colliding.
- A crashed worker keeps its claim. `harness abandon <todo>` releases it.

## Stop conditions, and one worked example

A merge is automatic only when every check passes. Anything else **parks**: the
branch stays intact, the queue moves on, and a human decides. A park is the
harness working, not failing.

`doc-add-license` always parks. Its todo:

```
- **Touches:** LICENSE, THIRD_PARTY_LICENSES.md, AGENTS.md
```

- It must edit `AGENTS.md` to remove a personal name, so it declares it.
- `AGENTS.md` is a hard stop in `check`. Declaring it in `Touches` does not
  lift that; it only reserves the file against other workers.
- So `check` reports `protected-path` and the branch parks, every time.
- Reason: `AGENTS.md` holds the rules every agent obeys. An agent that edits
  the rules must not also be able to merge the edit.
- Resolution: a human reads the diff and merges it by hand.

Other hard stops, all by design: `harness/**`, `.harness.conf`, a
`HARNESS_PROTECTED` path missing from `Touches`, an added test skip, a commit
subject outside the four prefixes, a red trunk before the merge, a red gate
after it, a dirty trunk checkout, and after numbering, an `ADR-DRAFT` token
that survived or two ADRs with one number.

A draft ADR (`docs/adr-draft-<kebab>.md`, ADR-08) is numbered by `integrate`
after the merge and before the post-merge gate, inside the lock. The number
is recomputed from the files present, which is what makes two drafts landing
in either order safe.

## Configuration

Everything project-specific lives in `.harness.conf` at the repo root, sourced
as POSIX sh. Nothing under `harness/` knows the project's language.

```sh
HARNESS_PROJECT="wut"
HARNESS_TRUNK="main"
HARNESS_WORKTREE_ROOT="../wut-command-worktrees"   # relative to the main worktree
HARNESS_PREFIXES="feat fix doc chore"
HARNESS_MAX_WORKERS=3

HARNESS_GATES="build vet fmt test shellcheck shellsize"
HARNESS_QUICK_GATES="build vet"
HARNESS_EXCLUSIVE_GATES="test"

harness_gate_build() { go build ./...; }
HARNESS_GATE_TOOLS_build="go"
```

- A gate is a function named `harness_gate_<name>` plus a
  `HARNESS_GATE_TOOLS_<name>` list of what it needs on `PATH`.
- A declared gate whose tool is missing stops the run with exit `4`. It is
  never skipped. A project without a tool declares fewer gates.
- `.harness.conf` is a hard stop in `check`. An agent cannot loosen the
  gate and merge the change.

## State

Coordination state lives in `$(git rev-parse --git-common-dir)/harness/`:
`claims/`, `lock/`, `tmp/`, `submitted/`, `parked/`, `integrate/`, `agents/`,
`log/` and `events`.

- `agents/<todo>.<role>` records a detached agent: pid, command, start, log,
  and once it ends, its exit code. While the record exists nothing dispatches
  that todo again. It goes when the claim goes: a merge, or `abandon`.
- `log/` holds each agent's output and is never cleaned by the harness.
- `events` is one line per thing that happened. `harness log` joins it with
  the merge trailers, which are the durable record.

- One copy, shared by every worktree. Git never tracks it.
- Git is the authority; the files annotate it.
  `rm -rf .git/harness && harness doctor --repair` is safe.
- A stale lock is reported, never stolen. `harness unlock` is manual on purpose.
- The durable record will be the merge commits' `Harness-*` trailers.

## Conventions for the harness's own code

- **POSIX sh only.** macOS ships bash 3.2.57, so no arrays and no `mapfile`,
  and a lifted copy may run under dash.
- **No shell file over `HARNESS_SHELL_MAX_LINES` (400).** The `shellsize` gate
  enforces it. A total line budget was tried and dropped: it says nothing about
  whether any one file fits in your head, and it turns every addition into a
  negotiation.
- **`shellcheck -s sh` clean.** The `shellcheck` gate enforces it. Each
  suppression carries its reason inline.
- **Libraries only define functions.** `bin/harness` sources `lib/*.sh` in glob
  order, so anything that runs at source time runs in that order too.
- **No verb registry.** A verb is a file in `harness/verbs/`, and `help` globs
  the directory. Adding a verb edits nothing, so two branches adding verbs do
  not conflict. Line 1 of a verb file is `# <verb> — <description>`, which is
  what `help` prints.

## The honest limit

- On this repo's backlog, max parallelism is six todos, and realistically
  three. Shared files, an `ALL` barrier and `Blocked by` chains serialize the
  rest.
- The backlog empties in a few sessions. The harness does not pay for itself
  on this repo alone.
- It earns its keep as a template: lifted into other repos, with this one as
  the test fixture.
