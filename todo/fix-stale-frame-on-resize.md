# fix: stop the picker leaving a stale frame when the terminal shrinks

- **Priority:** high
- **Branch:** fix/stale-frame-on-resize
- **Touches:** internal/ui/list_picker.go, internal/ui/list_picker_test.go
- **Blocked by:** —

## Goal
Shrinking the terminal below the picker's height and growing it back leaves one
picker on screen, and quitting leaves none.

## Why
Today it leaves two, and quitting leaves one behind permanently. The user asked
for a list and got a dead copy of it wedged into their scrollback.

## Notes

### Repro

Reliable, 3 of 3 trials. Needs a real terminal — this cannot be reproduced from
a unit test, because it is about what the terminal does with rows the program
has already emitted.

```sh
go build -o /tmp/wut .
tmux new-session -d -s r -x 80 -y 24
tmux send-keys -t r 'PS1="$ "; clear; /tmp/wut docker container' Enter ; sleep 2
tmux resize-window -t r -x 80 -y 8  ; sleep 2   # shrink below the frame
tmux resize-window -t r -x 80 -y 24 ; sleep 2   # grow back
tmux capture-pane -p -t r | grep -c "docker exec -it CONTAINER bash"   # 2, want 1
tmux send-keys -t r q ; sleep 1
tmux capture-pane -p -t r | grep -c "docker exec -it CONTAINER bash"   # 1, want 0
```

Allow ~1.5s per step. Faster resizes get coalesced and the artifact sometimes
does not appear, which makes a tight loop look like a passing test.

After the grow-back the pane holds a partial copy of the list in rows 1-9 and
the live frame below it. `q` erases only the live frame.

### Cause

`Pick`'s erase and Bubble Tea's repaint are both cursor-relative — `\x1b[NA`
then `\x1b[J`, and `\r\x1b[NF\x1b[0J` on exit. Both count back from where the
cursor is now.

When the terminal shrinks below the frame's height the frame scrolls. Rows that
go above the viewport are in scrollback, and no relative cursor move reaches
them: `\x1b[J` erases from the cursor *down*. Growing the terminal pulls those
rows back into view, and the program — which believes it already erased its old
frame — paints a fresh one underneath.

So the duplicate is not a redraw bug in `resize()`. `resize()` is doing the
right thing; the frame it computes is correct at every size. Confirm that before
changing layout code.

### Width alone does not cause this

Swept 100→{20,24,30}→100 at heights 12, 14 and 16: no artifact in any of the
nine combinations. Rows re-truncate and restore cleanly. The trigger is the
frame being taller than the terminal, which only height produces directly.

Width can still reach it indirectly, through
`fix-help-overflows-narrow-terminals`: a help line that wraps makes the frame
taller than `lipgloss.Height` reports. Worth re-checking this once that one
lands, and worth not assuming the two are independent.

### Directions, none of them free

- **`tea.ClearScreen`** (`bubbletea/screen.go:18`) on a `WindowSizeMsg` that
  would scroll the frame. Removes the residue, at the cost of wiping scrollback
  the user did not ask you to touch. For an inline widget that is a big hammer.
- **Accept the residue, kill the duplicate.** The rows that scrolled off are
  unreachable by anything except a clear; what is fixable is painting a second
  full copy under them. Smaller blast radius, and honest about the limit.
- **Alt screen.** Solves it completely and contradicts the inline design that
  `ADR-01` chose and `ADR-04` kept — `cmd` prints its copied-command line
  directly under the frame. This one needs an ADR before any code.

Pick deliberately and say which in the commit. If it is the third, stop and
write the ADR first.

### The exit erase has the same blind spot

`Pick` erases `lipgloss.Height(fm.frame()) - 1` rows. That is the *current*
frame, so after a shrink it is correct for what is live and blind to what
scrolled. Whatever fixes the duplicate should be checked against the quit path
too — the second repro assertion above is the one that catches it.

## Done when
- [ ] After the repro's shrink and grow-back, exactly one copy of the list is
      on screen
- [ ] Quitting from that state leaves no picker rows behind
- [ ] Width-only resizes still render correctly at 20, 24 and 30 columns
- [ ] The approach is stated in the commit, and carries an ADR if it changes
      the inline design
- [ ] The repro is committed as a script or written into the todo's place in
      `demo/`, since no unit test can cover it
- [ ] `go test ./...` passes
- [ ] `go build ./...` and `go vet ./...` pass
