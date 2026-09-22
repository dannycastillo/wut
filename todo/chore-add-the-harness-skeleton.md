# chore: add the harness skeleton and its read-only verbs

- **Priority:** high
- **Branch:** chore/add-the-harness-skeleton
- **Touches:** harness/bin/*, harness/lib/*, harness/verbs/*, .harness.conf
- **Blocked by:** —

## Goal
`harness doctor`, `harness status` and `harness path` run, and `doctor` proves
the coordination layer's assumptions before anything is able to mutate the repo.

## Why
ADR-07 puts coordination state in a directory that is shared between worktrees
and untrackable by git. That property is the basis of the whole design and it
fails silently when it is wrong, so the first thing built is the part that
checks it.

## Notes

### Layout

- `harness/bin/harness` — entrypoint. Resolves a verb to `harness/verbs/<verb>.sh`
  and sources it.
- `harness/lib/common.sh` — state directory, trunk discovery, exit codes, logging
- `harness/lib/state.sh` — `key=value` read/write, reconcile from git
- `harness/verbs/{doctor,status,path}.sh`

**No verb registry.** Adding a verb adds a file and edits nothing, so two
branches adding verbs do not conflict. The units after this one are sequenced on
that property, so it is load-bearing rather than tidy.

### The state directory

`$(git rev-parse --git-common-dir)/harness`, normalized to absolute — it comes
back relative (`.git`) from the root and absolute from a linked worktree.

Never `--git-dir` or `--git-path`: both are per-worktree for this name, and all
three spellings return `.git` from the root, so the mistake passes every test
run from the root and only breaks once a second worktree exists. That earns a
comment in `common.sh` under the Comments rule — it is precisely the kind of
line a reader would otherwise "simplify".

### doctor

Asserts the state directory resolves identically from the root and from a linked
worktree; trunk is found via `git worktree list --porcelain`; every
`HARNESS_GATES` function is defined; the worktree root is writable.

`--repair` rebuilds `claims/` from `git worktree list` and drops entries whose
worktree is gone. Git is the authority; the files annotate it.

### Shell

POSIX sh. macOS ships bash 3.2 — no arrays, no `mapfile`. `sh -n` every file.

### Not in scope

No verb that writes to the repo; claiming is the next unit. `.harness.conf` is
written with this repo's real gate per ADR-09, but nothing runs it yet.

## Done when
- [ ] `harness doctor` passes from the repo root and from a linked worktree, and
      reports the same absolute state directory in both
- [ ] `harness doctor --repair` rebuilds a deleted state directory from
      `git worktree list`, losing nothing but the journal
- [ ] `harness status` and `harness path` work, and no verb mutates the repo
- [ ] Adding a verb requires no edit to `harness/bin/harness`
- [ ] `.harness.conf` declares this repo's gate per ADR-09
- [ ] `sh -n` passes on every shell file, and `shellcheck -s sh` if installed
- [ ] `go build ./...` and `go vet ./...` pass
