# ADR-06: The picker closes on resize rather than repainting

- **Status:** Accepted
- **Date:** 2026-09-18

## Context
The picker is inline by ADR-01 and ADR-04: it paints into the terminal's normal
buffer, under the command that invoked it, and `cmd` prints the copied line
directly beneath. That is the experience worth keeping.

It also means the picker addresses rows relative to its own first row, and
`\x1b[J` erases only downward. Anything the terminal moves above that row is
beyond reach. A resize moves rows it has already emitted: a frame taller than
the terminal scrolls, and a narrower terminal re-wraps. Repainting then adds a
second copy underneath the stranded one.

Four attempts to repaint through it failed. Each time the picker computed the
correct frame and the screen was still wrong, because the damage was above the
row it can address. Collapsing the frame during a resize burst made it worse —
166 collapses in one drag, each erasing rows the terminal handed back as a gap
when the window grew. Closing only inside a measured margin still let residue
through, because the margin was a guess about the rest of the screen and about
how the terminal reflows, neither of which the picker can see.

Upstream has no fix: `charmbracelet/bubbletea#1808` is open and titled for the
conclusion, *ClearScreen is not enough*.

## Decision
Any real terminal resize closes the picker. It erases what it can still reach
and exits silently with status 0; the user reruns the search.

`Pick` watches `SIGWINCH` directly rather than waiting for `WindowSizeMsg`,
because closing is only as good as how early it starts.

## Alternatives considered
- **Alt screen** — fixes the class outright, and gives up the inline experience
  ADR-01 and ADR-04 chose.
- **Repaint through the resize** — tried four ways; all left residue.
- **Close only when a resize looks dangerous** — the margin cannot be derived
  from anything the picker can observe.
- **Say why on exit** — a message is one more line to erase, and nothing
  downstream could act on it. Silence leaves the terminal as it was found.

## Consequences
- Resizing mid-search loses the search. The command is one press of the up
  arrow away, which is the trade being made.
- `Update` still closes on `WindowSizeMsg`, for when that message beats the
  signal.
- The first size is exempt and an unchanged size is ignored; Bubble Tea re-sends
  the current size in some situations, and without that guard the picker would
  close as it finished drawing.
- `Update` does no work before quitting, and does not re-lay-out on the way:
  `Pick`'s erase counts back from the frame, so the frame has to keep matching
  what is on screen.
- Residue is still reachable when the terminal is already small enough that the
  frame does not fit, because rows have scrolled beyond the erase before the
  picker is told anything. The close narrows the window; it does not shut it.
- There is no `ErrResized`: a silent exit is indistinguishable from any other
  close, so the caller gets `ErrAborted`.
- The signal costs Windows support, recorded as ADR-05.
