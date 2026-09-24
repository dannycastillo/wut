# chore: add the Claude Code and Cursor adapters

- **Priority:** low
- **Branch:** chore/add-the-platform-adapters
- **Touches:** ai-harness/adapters/*, .claude/*
- **Blocked by:** —

## Goal
Starting a worker on Claude Code or Cursor is a slash command or a rule, and
both read the same role doc as everything else.

## Why
Convenience only — and that is the test. If an adapter carries behaviour, the
role doc has stopped being the source of truth and the harness has stopped
being AI-agnostic.

## Notes

Each adapter is a pointer and nothing more.
`.claude/skills/ai-harness-worker/SKILL.md` says to read `ai-harness/roles/worker.md`
and follow it; same shape for the reviewer. Both role docs are in
`ai-harness/roles/`. Cursor gets
`.cursor/rules/*.mdc` doing the same thing.

The loop starts agents through `AI_HARNESS_AGENT_CMD` with a one-line prompt, so
it needs no adapter at all. Adapters are for a human starting a role by hand
in an editor session.

`adapters/README.md`: how to add one in about ten lines, and the note that a
platform which already reads AGENTS.md needs none, because the boot prompt is
one line by design.

If an adapter turns out to need something the role doc does not say, the fix is
to put it in the role doc.

## Done when
- [ ] Claude Code adapter: two skills, each a pointer to its role doc
- [ ] Cursor adapter: two rules, same
- [ ] No adapter contains behaviour that is not in a role doc
- [ ] `adapters/README.md` explains adding one, and when none is needed
- [ ] A worker started through the adapter and one started from the one-line
      boot prompt behave the same
- [ ] `go build ./...` and `go vet ./...` pass
