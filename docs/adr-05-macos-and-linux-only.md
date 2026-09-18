# ADR-05: macOS and Linux only

- **Status:** Accepted
- **Date:** 2026-09-18

## Context
The picker closes itself when the terminal is resized, because an inline
program cannot erase rows the terminal has moved above its first row. Closing
is only as good as how early it notices.

Bubble Tea's `WindowSizeMsg` is not early enough: it costs two trips through the
event loop and an ioctl in between, and `tea.go` calls `renderer.resize` — which
repaints — before the model sees the message. Handling `SIGWINCH` directly is
the earliest the picker can know.

Windows has no `SIGWINCH`. `syscall.SIGWINCH` does not compile there.

## Decision
`wut` targets `darwin` and `linux`. The build does not compile on Windows, and
that is deliberate rather than an oversight.

## Alternatives considered
- **A build-tagged no-op for Windows** — compiles everywhere and leaves Windows
  with the slower path and more residue, with nothing on screen to say why.
- **Drop the signal and rely on `WindowSizeMsg`** — portable, and gives up the
  only means of acting before the renderer repaints into a terminal that has
  already moved.
- **Alt screen instead** — sidesteps resize entirely and contradicts ADR-01 and
  ADR-04, which chose an inline picker.

## Consequences
- `internal/ui` imports `syscall` and uses `SIGWINCH` directly, with no build
  tags to keep in sync.
- `GOOS=windows go build ./...` fails at compile. A contributor learns the scope
  from the compiler rather than from a subtly worse picker.
- `chore/homebrew-release` already plans `darwin` and `linux` across `arm64` and
  `amd64` — four pairs, unchanged by this.
- CI needs macOS and Linux runners only.
- Reversing this means restoring a Windows resize path, not just a build tag:
  the picker would need a different way to learn about resizes there.
