package seed

import (
	"fmt"
	"io/fs"
	"regexp"
	"strings"
	"testing"
)

// vocabulary is the one placeholder wordlist a SCREAMING_SNAKE token in a
// command line must come from. Add a word here to allow it everywhere.
var vocabulary = map[string]bool{
	"ARCHIVE": true, "BRANCH": true, "COMMAND": true, "COMMIT": true,
	"CONTAINER": true, "CONTEXT": true, "DEPLOYMENT": true, "DIR": true,
	"DOMAIN": true, "DST": true, "FILE": true, "HOST": true, "ID": true,
	"IMAGE": true, "IP": true, "JUMP": true, "KEY": true, "MESSAGE": true,
	"N": true, "NAME": true, "NAMESPACE": true, "NODE": true,
	"PASSWORD": true, "PATTERN": true, "PID": true, "POD": true,
	"PORT": true, "REPLACEMENT": true, "RESOURCE": true, "SERVICE": true,
	"SESSION": true, "SRC": true, "TAG": true, "TOKEN": true, "TOOL": true,
	"TYPE": true, "URL": true, "USER": true, "VALUE": true, "VERSION": true,
	"WORKSPACE": true,
}

// nonPlaceholderLiterals are uppercase, SCREAMING_SNAKE-shaped words that show
// up in real commands without being a placeholder: git's HEAD, openssl's /CN=,
// awk's $NF and END, curl's -X POST and -LO, lsof's LISTEN, kill's -HUP, and
// zip's __MACOSX exclusion.
var nonPlaceholderLiterals = map[string]bool{
	"CN": true, "END": true, "HEAD": true, "HUP": true, "LISTEN": true,
	"LO": true, "NF": true, "POST": true, "__MACOSX": true,
}

// A candidate placeholder token is SCREAMING_SNAKE-shaped: starting with an
// uppercase letter or underscore, two characters or more so that a one-letter
// flag like -D or -X never has to be listed as an exception.
var screamingToken = regexp.MustCompile(`^[A-Z_][A-Z0-9_]*$`)

var wordToken = regexp.MustCompile(`\w+`)

// keystrokeWord catches the modifier names a key chord is written with, e.g.
// "ctrl + b" or "cmd + shift + p" — see e0470f9's removal of shell.txt,
// k9s.txt, tmux.txt and zed.txt's keystroke entries.
var keystrokeWord = regexp.MustCompile(`(?i)\b(ctrl|ctl|cmd|alt|option|shift|meta|esc|escape)\b`)

// bareKeyToken catches a command line that is nothing but a one- or
// two-character token, like the "d" or "0" keypresses that same commit cut.
// No real command in the set is this short; "!!" survives because "!" is not
// alphanumeric.
var bareKeyToken = regexp.MustCompile(`^[A-Za-z0-9]{1,2}$`)

// TestSeedFormat walks every embedded snippet file the same way collectTxt
// does and checks it against every rule feat/expand-seed-snippets applied by
// hand with a throwaway script (e0470f9). See
// todo/chore-test-the-seed-format.md for the rules as written down.
func TestSeedFormat(t *testing.T) {
	seenCommands := map[string]string{}
	seenDescriptions := map[string]string{}

	err := fs.WalkDir(FS, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".txt") {
			return nil
		}

		content, err := fs.ReadFile(FS, path)
		if err != nil {
			return err
		}

		checkFile(t, path, string(content), seenCommands, seenDescriptions)
		return nil
	})
	if err != nil {
		t.Fatalf("walking seed.FS: %v", err)
	}
}

func checkFile(t *testing.T, path, content string, seenCommands, seenDescriptions map[string]string) {
	t.Helper()

	if content == "" {
		t.Errorf("%s: empty file", path)
		return
	}

	if !strings.HasSuffix(content, "\n") || strings.HasSuffix(content, "\n\n") {
		t.Errorf("%s: must end with exactly one trailing newline and no blank line after the last snippet", path)
	}

	lines := strings.Split(strings.TrimSuffix(content, "\n"), "\n")

	for i := 0; i < len(lines); {
		descLine, descLineNum := lines[i], i+1

		if !strings.HasPrefix(descLine, "#") {
			t.Errorf("%s:%d: expected a \"# description\" line, got %q", path, descLineNum, descLine)
			i++
			continue
		}

		desc := strings.TrimSpace(strings.TrimPrefix(descLine, "#"))
		if strings.ToLower(desc) != desc {
			t.Errorf("%s:%d: description %q is not entirely lowercase", path, descLineNum, desc)
		}
		if prev, ok := seenDescriptions[desc]; ok {
			t.Errorf("%s:%d: description %q duplicates %s", path, descLineNum, desc, prev)
		} else {
			seenDescriptions[desc] = fmt.Sprintf("%s:%d", path, descLineNum)
		}

		if i+1 >= len(lines) {
			t.Errorf("%s:%d: description has no command line after it", path, descLineNum)
			return
		}
		cmdLine, cmdLineNum := lines[i+1], i+2

		if cmdLine == "" || strings.HasPrefix(cmdLine, "#") {
			t.Errorf("%s:%d: expected a command line, got %q", path, cmdLineNum, cmdLine)
			i++
			continue
		}
		checkCommand(t, path, cmdLineNum, cmdLine, seenCommands)

		if i+2 >= len(lines) {
			// Last snippet in the file: no blank line required after it.
			return
		}

		switch next := lines[i+2]; {
		case next == "":
			i += 3
		case strings.HasPrefix(next, "#"):
			t.Errorf("%s:%d: missing blank line before the next snippet", path, i+3)
			i += 2
		default:
			// Today scanFile (internal/search/scan.go) splits snippets on
			// "\n#", so a second command line for one snippet is a parser
			// constraint, not a seed-set choice — see
			// todo/fix-multi-line-snippet-join.md.
			t.Errorf("%s:%d: a second command line in one snippet; the three-line shape is a parser constraint until fix/multi-line-snippet-join lands, got %q", path, i+3, next)
			i += 2
		}
	}
}

func checkCommand(t *testing.T, path string, line int, cmd string, seenCommands map[string]string) {
	t.Helper()

	if prev, ok := seenCommands[cmd]; ok {
		t.Errorf("%s:%d: command %q duplicates %s", path, line, cmd, prev)
	} else {
		seenCommands[cmd] = fmt.Sprintf("%s:%d", path, line)
	}

	if keystrokeWord.MatchString(cmd) || bareKeyToken.MatchString(strings.TrimSpace(cmd)) {
		t.Errorf("%s:%d: %q looks like a keystroke, not something a shell runs when pasted", path, line, cmd)
	}

	for _, tok := range wordToken.FindAllString(cmd, -1) {
		if len(tok) < 2 || !screamingToken.MatchString(tok) {
			continue
		}
		if vocabulary[tok] || nonPlaceholderLiterals[tok] {
			continue
		}
		t.Errorf("%s:%d: %q is not in the placeholder vocabulary and not a known literal", path, line, tok)
	}
}
