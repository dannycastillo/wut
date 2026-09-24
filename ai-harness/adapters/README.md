# Adapters

An adapter is how a human starts a role by hand in an editor session: a slash
command or a rule that says *read the role doc and follow it*. Each one is a
pointer to `ai-harness/roles/<role>.md` and nothing more.

The loop never uses one. `dispatch` and `run` start agents through
`AI_HARNESS_AGENT_CMD` with a one-line boot prompt, and that is the whole
contract.

## The test

An adapter carries no behaviour. If starting a role through an adapter needs
something the role doc does not say, the fix goes in the role doc, never in
the adapter. Otherwise the role doc stops being the source of truth and the
harness stops being AI-agnostic.

The check: a worker started through the adapter and one started from the boot
prompt read the same three things, `AGENTS.md`, the todo and the role doc, and
so behave the same.

## Layout

One directory per platform, laid out as it lands in a repo root:

| Directory     | Installs to | Starts a role by                          |
| ------------- | ----------- | ----------------------------------------- |
| `claude-code` | `.claude/`  | `/ai-harness-worker`, `/ai-harness-reviewer` |
| `cursor`      | `.cursor/`  | `@ai-harness-worker`, `@ai-harness-reviewer` |

Installing is a copy. `install.sh` does it; by hand:

```sh
cp -R ai-harness/adapters/claude-code/. .claude/
```

The copy under `ai-harness/adapters/` is the source and the one under the dot
directory is what the platform reads. `diff -r` between the two is the drift
check.

## When none is needed

A platform that reads `AGENTS.md` on its own needs no adapter: paste the boot
prompt `dispatch` prints with `AI_HARNESS_AGENT_CMD` unset. It is one line by
design, so a platform nobody has written an adapter for is a supported path,
not a degraded one.

## Adding one

1. Make `adapters/<platform>/`, mirroring that platform's dot directory.
2. Add one file per role, in whatever shape the platform reads as a command
   or rule. The body is the pointer: *You are an AI Harness `<role>`. Read
   `ai-harness/roles/<role>.md` and follow it.*
3. Give it whatever frontmatter the platform needs to be started by hand and
   not by the model on its own.
4. Add the directory to the table above.
5. Start each role through it once, and confirm it does what the boot prompt
   does. Anything it needed beyond the pointer belongs in the role doc.
