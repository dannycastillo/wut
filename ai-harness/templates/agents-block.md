## Working in parallel

Several agents work this backlog at once, one todo each, in separate
worktrees, and trunk is written only by `aih integrate`. The mechanics and
the verbs are in `ai-harness/README.md`; each role's sequence is in
`ai-harness/roles/`. `aih run` works a set of todos unattended.

`Touches` in a todo is a reservation on paths, and it is the only thing that
decides what runs side by side.
