# ADR-01: Bubble Tea over promptui for the picker

- **Status:** Accepted
- **Superseded by:** ADR-04
- **Date:** 2026-09-17

## Context
promptui's `Select` took pre-joined strings (`fmt.Sprintf("%s %s", v.Cmd,
v.Desc)`) and a hardcoded `Size: 10`. It could not read terminal height, style
command and description separately, or run under test without a TTY.

## Decision
The picker is a Bubble Tea program in `internal/ui`, reached only through
`ui.Pick(title, []ui.Choice) (int, error)`. `cmd/` does not import Bubble Tea.

## Alternatives considered
- Stay on promptui v0.9.0 — fixed layout, joined strings. The blocker.
- Raw ANSI — full control, all of it hand-written.

## Consequences
- Sizing follows the terminal: `resize()` on `WindowSizeMsg`, capped at
  `maxListHeight`.
- `Choice{Title, Desc}` renders as two fields via `choiceDelegate`.
- Styles are theme-aware: `newStyles(darkBG)`.
- `newModel` is split from `Pick` so layout is testable without a TTY.
  `list_picker_test.go` (7 tests) depends on that split.
- Direct imports 3 → 5; module graph 7 → 20.
- 265 lines of picker to maintain, and its bugs are ours: `238d648`,
  `aeba3fa`, `42b09f7`.
- Changing picker behavior requires working in MVU.
