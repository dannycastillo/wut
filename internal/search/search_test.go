package search

import (
	"testing"
	"testing/fstest"
)

// NewQuery aliases the caller's slice rather than copying it. Pinned here
// rather than changed: cmd/root.go hands it args it doesn't reuse, so the
// aliasing is harmless in practice, and this branch is coverage, not a
// behavior change.
func TestNewQueryLowercasesArgsInPlace(t *testing.T) {
	args := []string{"Docker", "PS"}

	q := NewQuery(args)

	if args[0] != "docker" || args[1] != "ps" {
		t.Errorf("NewQuery: caller's slice = %v, want it lowercased in place", args)
	}
	if q.Joined != "docker ps" {
		t.Errorf("NewQuery: Joined = %q, want %q", q.Joined, "docker ps")
	}
	if len(q.Split) != 2 || q.Split[0] != "docker" || q.Split[1] != "ps" {
		t.Errorf("NewQuery: Split = %v, want [docker ps]", q.Split)
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

	results, warnings, err := findIn(files, Query{Joined: "docker ps", Split: []string{"docker", "ps"}})

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
