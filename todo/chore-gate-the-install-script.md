# chore: gate the install script like the rest of the harness

- **Priority:** low
- **Branch:** chore/gate-the-install-script
- **Touches:** .ai-harness.conf
- **Blocked by:** —

## Goal
This repo's `shellcheck` and `shellsize` gates cover `ai-harness/install.sh`.

## Why
The config template every installed repo gets lists `install.sh` in both
gates. This repo's own `.ai-harness.conf` predates the file and does not, so
the fixture is the one place the installer can regress unchecked.

## Notes
`.ai-harness.conf` is a hard stop in `check`, so this parks and a human
merges it. Add `ai-harness/install.sh` to the file lists in
`ai_harness_gate_shellcheck` and `ai_harness_gate_shellsize`; nothing else
changes. `ai-harness/templates/ai-harness.conf` already has the shape.

## Done when
- [ ] `aih gate --full` runs shellcheck and shellsize over `ai-harness/install.sh`
- [ ] `aih gate --full` green
