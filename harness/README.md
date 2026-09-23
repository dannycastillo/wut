# harness

One todo, one branch, one worktree. Trunk is written only by a merge.

The harness lets several agents work one repo's backlog at once without
landing in the same file. It is plain POSIX sh plus git, and nothing else.
The repo's rules stay in `AGENTS.md`; the harness enforces them mechanically.
Design: ADR-10 (a shell loop schedules two roles), ADR-08 (ADR numbering),
ADR-09 (the gate lives in config).

## Status

Partly built. `harness help` lists what your copy has.

- **Built:** `claim`, `abandon`, `path`, `status`, `gate`, `doctor`, `unlock`,
  `help`, `plan`, `dispatch`, `submit`, `check`, `integrate`, and both role
  docs in `harness/roles/`.
- **Not built yet:** `run`, `pause`, `resume`, `log`, and detached dispatch.
  `chore-add-the-agent-registry` and `chore-add-the-run-loop` carry them.
- Until `chore-retire-the-human-merge-gate` lands, `AGENTS.md` still says a
  human merges every branch. `integrate` is what that human runs.

## Setup

Each worktree runs its own copy of the harness, so use a shell function rather
than a fixed `PATH` entry:

```sh
harness() { "$(git rev-parse --show-toplevel)/harness/bin/harness" "$@"; }
harness doctor --selftest
```

- `doctor` checks the state dir, trunk, the worktree root and every declared
  gate's tools. It changes nothing unless given `--repair`.
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
|            | `run`, `pause`, `resume`, `log` * | works a set of todos unattended; stops it; restarts it; reads history |
| anyone     | `help`                      | lists the verbs in this copy                                  |

Exit codes: `0` ok, `1` failed, `2` usage, `3` paused, `4` the environment
cannot run the gate, `10` judgment needed.

## Running N workers

Until `run` lands, a human starts each worker:

```sh
harness plan                               # what can run now, and why the rest cannot
eval "$(harness dispatch worker)"          # claims the top runnable todo, starts the agent
harness status                             # what is claimed, by whom, touching what
```

`dispatch` starts `$HARNESS_AGENT_CMD` with a one-line boot prompt that ends
with `harness submit`. With the command unset, it prints the `cd` and the
prompt for you to run yourself.

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
after it, and a dirty trunk checkout.

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
`claims/`, `lock/`, `tmp/`.

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
