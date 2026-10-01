package search

import (
	"strings"
	"testing"
	"testing/fstest"
)

// The phrase is the words as typed, for the no-results message; the caller's
// slice is left alone.
func TestNewQueryKeepsPhraseAsTyped(t *testing.T) {
	args := []string{"Docker", "PS"}

	q := NewQuery(args)

	if q.Phrase != "Docker PS" {
		t.Errorf("NewQuery: Phrase = %q, want %q", q.Phrase, "Docker PS")
	}
	if args[0] != "Docker" {
		t.Errorf("NewQuery: caller's slice = %v, want it untouched", args)
	}
}

// A word typed twice searches once, a hyphenated query splits like a
// hyphenated snippet does, and the words that carry no meaning are dropped
// unless they are all there is.
func TestNewQueryTerms(t *testing.T) {
	tests := []struct {
		args []string
		want []string
	}{
		{[]string{"Docker-PS", "docker"}, []string{"docker", "ps"}},
		{[]string{"show", "the", "size", "of", "a", "directory"}, []string{"show", "size", "directory"}},
		{[]string{"the", "a"}, []string{"the", "a"}},
	}
	for _, tt := range tests {
		got := NewQuery(tt.args).Terms
		if strings.Join(got, " ") != strings.Join(tt.want, " ") {
			t.Errorf("NewQuery(%v).Terms = %v, want %v", tt.args, got, tt.want)
		}
	}
}

// When every source fails to open, errors.Join(scanErrs...) must not silently
// collapse to nil: findIn has to report a non-nil err rather than degrade.
func TestFindInReturnsErrorWhenEverySourceFails(t *testing.T) {
	fsys := fstest.MapFS{} // empty: opening anything fails with fs.ErrNotExist

	files := []snippetSource{
		{fsys: fsys, path: "a.txt", label: "a.txt"},
		{fsys: fsys, path: "b.txt", label: "b.txt"},
	}

	results, warnings, err := findIn(files, NewQuery([]string{"docker", "ps"}))

	if err == nil {
		t.Fatal("findIn: err = nil, want non-nil when every source fails")
	}
	if results != nil {
		t.Errorf("findIn: results = %v, want nil", results)
	}
	if warnings != nil {
		t.Errorf("findIn: warnings = %v, want nil", warnings)
	}
}

// A snippet matching every query word hides the ones matching only some:
// "git log" means the log snippets, not every git snippet. With no full
// match the partial ones stand in, so a misspelt word still finds something.
func TestFindInPrunesPartialMatchesWhenAnyFullMatch(t *testing.T) {
	fsys := fstest.MapFS{
		"git.txt": &fstest.MapFile{Data: []byte(
			"# show the git log\ngit log --oneline\n\n# git status\ngit status\n\n# git diff\ngit diff\n",
		)},
	}
	files := []snippetSource{{fsys: fsys, path: "git.txt", label: "git.txt"}}

	results, _, err := findIn(files, NewQuery([]string{"git", "log"}))
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 || results[0].Cmd != "git log --oneline" {
		t.Errorf("findIn: results = %v, want only the full match", order(results))
	}

	results, _, err = findIn(files, NewQuery([]string{"git", "lgo"}))
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 3 {
		t.Errorf("findIn: %d results, want all 3 partial matches when nothing matches fully", len(results))
	}
}
