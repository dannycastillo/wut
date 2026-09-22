# chore: add the Claude Code and Cursor adapters

- **Priority:** low
- **Branch:** chore/add-the-platform-adapters
- **Touches:** harness/adapters/*, .claude/*
- **Blocked by:** doc-write-the-role-docs

## Goal
Starting a worker on Claude Code or Cursor is a slash command or a rule, and
both read the same role doc as everything else.

## Why
Convenience only — and that is the test. If an adapter carries behaviour, the
role doc has stopped being the source of truth and the harness has stopped
being AI-agnostic.

## Notes

Each adapter is a pointer and nothing more.
`.claude/skills/harness-worker/SKILL.md` says to read `harness/roles/worker.md`
and follow it; same shape for integrator and reviewer. Cursor gets
`.cursor/rules/*.mdc` doing the same thing.

`adapters/README.md`: how to add one in about ten lines, and the note that a
platform which already reads AGENTS.md needs none, because the boot prompt is
one line by design.

If an adapter turns out to need something the role doc does not say, the fix is
to put it in the role doc.

## Done when
- [ ] Claude Code adapter: three skills, each a pointer to its role doc
- [ ] Cursor adapter: three rules, same
- [ ] No adapter contains behaviour that is not in a role doc
- [ ] `adapters/README.md` explains adding one, and when none is needed
- [ ] A worker started through the adapter and one started from the one-line
      boot prompt behave the same
- [ ] `go build ./...` and `go vet ./...` pass
