# doc: record the demo gifs

- **Priority:** medium
- **Branch:** doc/record-demo-gifs
- **Touches:** demo/*.tape, demo/*.gif, .gitignore
- **Blocked by:** feat-help-above-results

## Goal
`demo/` holds a short gif of the tool in use plus the script that produced it,
and re-recording is one command.

## Why
The README needs to show the picker working — a terminal UI is close to
impossible to convey in prose, and a reader decides whether to install in about
five seconds. Committing the script alongside the gif means the next UI change
re-records deterministically instead of someone screen-capturing by hand and
matching the old framing by eye.

## Notes

### Tool

Use `vhs` (`brew install vhs`). It reads a `.tape` script, drives a real
terminal, and writes a gif — same ecosystem as Bubble Tea, and the output is
reproducible because the keystrokes and timings are in the file rather than in
someone's hands.

### Blocked on the picker for a reason

`feat/slim-the-picker` removes the header, the numbering and the cursor.
Recording before it lands means recording twice.

### What to record

- **The main one:** a query, the picker opening, arrowing down, enter, and the
  `🚀 Copied to clipboard:` line. That's the whole product in about eight
  seconds.
- **Optional second:** adding a snippet to `~/.wut` and it appearing in results
  ranked above the shipped ones. Only if the README has a natural place for it.

### Recording notes

- Set an explicit `Width`, `Height`, `FontSize` and theme in the tape so the
  output doesn't depend on the recording machine.
- Keep the terminal small enough that the gif is legible inline on GitHub at
  roughly 800px, and check it at that size rather than full screen.
- Type at a human pace — `Sleep` between keystrokes. A gif that completes
  instantly reads as a screenshot.
- The picker writes to **stderr**, not stdout (`internal/ui/list_picker.go:84`),
  and erases its frame on exit (`:103-105`). Confirm the erase looks clean in
  the capture; that sequence was tuned for a live terminal.
- Use a query with a visibly useful result set. `wut docker` or `wut git log`
  beats a contrived one.
- Keep gifs under a megabyte or so. They live in the repo forever and every
  clone pays for them.

### Housekeeping

Commit both the `.tape` and the `.gif` — the gif has to be in the repo for the
README to render it on GitHub. Do not gitignore `demo/*.gif`.

## Done when
- [ ] `demo/` holds at least one `.tape` and its rendered `.gif`
- [ ] Running `vhs demo/<name>.tape` reproduces the gif from a clean checkout
- [ ] The gif shows a query, the picker, a selection, and the copy confirmation
- [ ] Terminal size, font size and theme are set explicitly in the tape
- [ ] Each gif is under ~1MB and legible at 800px wide
- [ ] The tape records the picker as it exists after `feat/slim-the-picker`
- [ ] `go build ./...` and `go vet ./...` pass
