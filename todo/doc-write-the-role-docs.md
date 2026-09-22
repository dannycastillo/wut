# doc: write the worker, integrator and reviewer role docs

- **Priority:** medium
- **Branch:** doc/write-the-role-docs
- **Touches:** harness/roles/*, harness/README.md
- **Blocked by:** —

## Goal
Each role has one markdown file that is enough to work from cold, and no
platform is required in order to read it.

## Why
The role doc is the prompt. Keeping behaviour in markdown rather than in a
platform's own format is what makes the harness AI-agnostic: an adapter becomes
a pointer instead of a port.

Written from ADR-07 to ADR-09 rather than from the code, so it can run beside
the implementation units — which is also the first real test of the harness's
own premise.

## Notes

Three docs, each addressed to an agent starting with no context.

**worker.md** — the sequence: read the todo and in full every ADR it cites;
work; `gate --quick` before each commit; `refresh`; `gate --full`; `check`;
verify each **Done when** box against the diff; write the merge prose; `submit`.
When to `--escalate`. That it never touches trunk, never picks an ADR number,
and says so out loud if it must touch a path the todo did not declare.

**integrator.md** — the algorithm in order, the closed set of reason codes, and
one rule above all the others: park rather than guess. An unknown situation is a
park. The failure mode is a stalled queue, never a bad merge.

**reviewer.md** — read the diff against the **Done when** list and AGENTS.md;
the verdict file format; and what is not its job: resolving conflicts, merging,
or re-running the gate.

**README.md** — what the harness is, the three roles, the verbs by owner, how to
run several workers, and one worked example of a stop condition:
`doc-add-license` declares `AGENTS.md`, so it always parks. Without that example
the first park reads as a broken harness.

Tone is AGENTS.md's: bullets, short sentences, present tense, specifics. A role
doc that gets skimmed is a role doc that gets followed.

State the honest limit in the README rather than burying it: max parallelism on
this backlog is six and realistically three, and the harness earns its keep as a
template rather than on this repo alone.

### The harness's own conventions, which the README must state

- POSIX sh only. macOS ships bash 3.2.57, so no arrays and no `mapfile`, and a
  lifted copy may run under dash.
- No shell file over `HARNESS_SHELL_MAX_LINES` (120). Enforced by the
  `shellsize` gate. A total line budget was tried and dropped: it says nothing
  about whether any one file fits in your head, and it turns every addition
  into a negotiation.
- `shellcheck -s sh` clean, enforced by the `shellcheck` gate. Suppressions
  carry their reason inline.
- Libraries in `harness/lib/` may only define functions: `bin/harness` sources
  `lib/*.sh` in glob order, so anything running at source time runs in that
  order too.
- No verb registry. A verb is a file in `harness/verbs/`; `help` globs the
  directory. Adding one edits nothing, which is why two branches adding verbs
  do not conflict.

## Done when
- [ ] worker.md, integrator.md and reviewer.md each stand alone as a prompt
- [ ] integrator.md lists every reason code and every hard stop
- [ ] README.md covers the roles, the verbs by owner, and running N workers
- [ ] README.md carries the `doc-add-license` park as a worked example
- [ ] No role doc names a platform or a language
- [ ] `go build ./...` and `go vet ./...` pass
