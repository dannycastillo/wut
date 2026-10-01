# todo/

One file per open piece of work. `ls todo/` is the backlog — if a file is
here, the work is open. Only a file directly under `todo/` counts: a
subdirectory is never the backlog, however many todos it holds.

`todo/new/` is the inbox an agent files into. Nothing there is claimed,
planned, or run until a human moves it into `todo/` by hand:

```sh
git mv todo/new/<file>.md todo/
```

A project may keep other subdirectories of its own — `todo/backlog/` or
whatever it likes — and the rule is the same for all of them.

Run `aih protocol` for the rules: filenames, `Touches`, `Blocked by`,
and how a todo is picked up and cleared. This file is only the shape and one
example; `aih plan` ignores it.

## Shape

```markdown
# <prefix>: <short title>

- **Priority:** high | medium | low
- **Touches:** paths or globs, or one of `ALL` / `NEW <glob>` / `UNKNOWN`
- **Blocked by:** other todo filenames, or `—`

## Goal
One sentence: what is true when this is done.

## Why
The reason it's worth doing. One or two lines.

## Notes
Constraints, file paths, function names, gotchas, ADRs that apply.
Everything needed to start without asking a question.

## Done when
- [ ] verifiable statement
- [ ] verifiable statement
- [ ] `aih gate` passes
```

## Example

`todo/fix-empty-desc-line.md`:

```markdown
# fix: empty description line

- **Priority:** medium
- **Touches:** lib/render.sh

## Goal
A todo with no `## Why` line renders without a blank paragraph where it
would have gone.

## Why
Spotted while writing the quickstart: an empty section leaves a visible gap
in the rendered todo.

## Notes
`lib/render.sh:41` prints the section unconditionally.

## Done when
- [ ] a todo missing `## Why` renders with no blank line in its place
- [ ] `aih gate` passes
```
