# chore: test the seed format rules

- **Priority:** low
- **Branch:** chore/test-the-seed-format
- **Touches:** NEW internal/seed/*_test.go
- **Blocked by:** —

## Goal
`go test ./internal/seed` fails when a shipped snippet breaks a rule the seed
set now follows, so the rules outlive the audit that set them.

## Why
`feat/expand-seed-snippets` verified the set with a throwaway shell script.
The next snippet added by hand has nothing stopping it from being two command
lines, an uppercase description, a keystroke, or a placeholder outside the
vocabulary — exactly the drift that audit had to clean up.

## Notes
The rules, as applied on that branch:

- Three lines per snippet: `# description`, one command line, one blank line.
  No blank after the last snippet; single trailing newline.
- Descriptions are entirely lowercase. `NewQuery` lowercases the args and
  `scanChunk` matches case-sensitively, so an uppercase word is unsearchable.
- No command line appears twice across files, and no description does either.
- Placeholders are `SCREAMING_SNAKE`, from one vocabulary: ARCHIVE BRANCH
  COMMAND COMMIT CONTAINER CONTEXT DEPLOYMENT DIR DOMAIN DST FILE HOST ID
  IMAGE IP JUMP KEY MESSAGE N NAME NAMESPACE NODE PASSWORD PATTERN PID POD
  PORT REPLACEMENT RESOURCE SERVICE SESSION SRC TAG TOKEN TOOL TYPE URL USER
  VALUE VERSION WORKSPACE. Uppercase literals that are not placeholders:
  `HEAD~1`, `/CN=`, `.DS_Store`, `__MACOSX`, `$NF`, awk `END`, `-X POST`,
  `-iTCP`, `LISTEN`, `-HUP`, `-LO`.
- No keystrokes: every command line is something a shell runs when pasted.

Read `seed.FS` with `fs.WalkDir`, the same way `collectTxt` does. If
`fix/multi-line-snippet-join` lands first and makes multi-line commands legal,
the three-line rule becomes a seed-set choice rather than a parser constraint
and the test should say so in its failure message.

## Done when
- [ ] A test walks every embedded `*.txt` and fails on each rule above with the
      file, line and rule named
- [ ] The vocabulary lives in the test as one list, so adding a word is one edit
- [ ] `go test ./internal/seed` passes on the current set
- [ ] `go build ./...` and `go vet ./...` pass
