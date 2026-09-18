# AGENTS.md

Working agreements for this repo. Minimal on purpose — sections get added when
we hit something actually worth writing down, not in anticipation.

## Git workflow

### Branch for everything

`main` is only ever written by a merge. Never commit to it directly, not even a
one-line fix or a typo. If you find yourself on `main` with uncommitted work,
create the branch first, then commit — the work moves with you.

### Four prefixes, nothing else

| Prefix  | Use for                                                 |
| ------- | ------------------------------------------------------- |
| `feat`  | new behavior someone using the tool can observe          |
| `fix`   | correcting behavior that was wrong                       |
| `doc`   | documentation only, including this file                  |
| `chore` | deps, build, tooling, `.gitignore` — no behavior change  |

If a change doesn't fit one of these, it's doing two things — split it until
each piece fits.

### Naming

- **Branch:** `<prefix>/<short-kebab-description>` — `feat/pane-resize`
- **Commit subject:** `<prefix>: <imperative summary>` — `fix: stop the exit erase eating a line`

Imperative mood ("stop", "add", "align") because a commit describes what
applying it *does* to the tree, not what you did yesterday. The branch prefix
and its commits' prefixes normally match; when they don't, the branch takes the
prefix of its most significant change.

### Before every commit

```sh
go build ./...
go vet ./...
```

Both must pass. Don't commit over a failure — fix it or report it. Say in your
summary that they ran and what they said, so the check is visible rather than
assumed.

### Merging is Danny's call

When a branch is finished:

1. Show what's on it:
   ```sh
   git log --oneline main..HEAD
   git diff main...HEAD
   ```
2. **Stop.** Wait for explicit approval in chat.
3. Only after approval:
   ```sh
   git switch main
   git merge --no-ff <branch>
   git push origin main
   git branch -d <branch>
   ```

`--no-ff` forces a merge commit even when `main` hasn't moved. A fast-forward
would splice the branch's commits into `main` as a flat line and lose the fact
that they shipped as one unit; the merge commit keeps that grouping, so
`git log --first-parent main` reads as a list of changes rather than a list of
keystrokes.

Never push a branch, merge, or force-push anything without being asked.
