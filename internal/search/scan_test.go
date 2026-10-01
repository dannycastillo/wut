package search

import (
	"errors"
	"io/fs"
	"testing"
	"testing/fstest"
)

// scanFile is the only place that knows which file a match came from.
func TestScanFileStampsOrigin(t *testing.T) {
	fsys := fstest.MapFS{
		"notes.txt": &fstest.MapFile{Data: []byte("# view containers\ndocker ps\n")},
	}

	terms := []string{"docker", "ps"}

	for _, user := range []bool{true, false} {
		ch := make(chan Result, 4) // buffered: scanFile sends before anyone drains

		src := snippetSource{fsys: fsys, path: "notes.txt", label: "notes.txt", user: user}
		if err := scanFile(src, terms, ch); err != nil {
			t.Fatalf("user=%v: scanFile: %v", user, err)
		}
		close(ch)

		var got []Result
		for r := range ch {
			got = append(got, r)
		}

		if len(got) != 1 {
			t.Fatalf("user=%v: %d results, want 1", user, len(got))
		}
		if got[0].FromUser != user {
			t.Errorf("user=%v: FromUser = %v, want %v", user, got[0].FromUser, user)
		}
	}
}

// A command spanning several lines — a for loop here — comes back with the
// newlines that make it valid shell still in place, not run together, and
// scanFile's chunking doesn't leave a trailing blank line behind either.
func TestScanFileJoinsMultiLineCommandWithNewline(t *testing.T) {
	fsys := fstest.MapFS{
		"notes.txt": &fstest.MapFile{Data: []byte(
			"# loop over text files\nfor f in *.txt; do\n  echo \"$f\"\ndone\n\n# next snippet\necho done\n",
		)},
	}

	terms := []string{"loop", "over", "text", "files"}

	ch := make(chan Result, 4)
	src := snippetSource{fsys: fsys, path: "notes.txt", label: "notes.txt"}
	if err := scanFile(src, terms, ch); err != nil {
		t.Fatalf("scanFile: %v", err)
	}
	close(ch)

	var got []Result
	for r := range ch {
		got = append(got, r)
	}
	if len(got) != 1 {
		t.Fatalf("%d results, want 1", len(got))
	}

	want := "for f in *.txt; do\n  echo \"$f\"\ndone"
	if got[0].Cmd != want {
		t.Errorf("scanFile: Cmd = %q, want %q", got[0].Cmd, want)
	}
}

// scanFile's error names src.path, which fsys knows nothing about outside
// itself; the rewrite swaps in the caller-facing label.
func TestScanFileRewritesPathErrorLabel(t *testing.T) {
	fsys := fstest.MapFS{} // empty: opening anything fails with fs.ErrNotExist

	src := snippetSource{fsys: fsys, path: "missing.txt", label: "seed/missing.txt"}

	err := scanFile(src, nil, make(chan Result))

	var pathErr *fs.PathError
	if !errors.As(err, &pathErr) {
		t.Fatalf("scanFile: err = %v, want a *fs.PathError", err)
	}
	if pathErr.Path != src.label {
		t.Errorf("scanFile: PathError.Path = %q, want %q", pathErr.Path, src.label)
	}
}

// Cmd keeps real newlines, since a multi-line command (a heredoc, a for
// loop) is only still valid shell with the lines kept apart. Desc joins
// with a space instead: it renders as prose on one picker row.
func TestBuildMatchJoinsCmdWithNewlineDescWithSpace(t *testing.T) {
	chunk := "# first line\n# second line\ndocker ps\ndocker stop $(docker ps -q)"

	got := buildMatch(chunk)

	if want := "# first line # second line"; got.Desc != want {
		t.Errorf("buildMatch: Desc = %q, want %q", got.Desc, want)
	}
	if want := "docker ps\ndocker stop $(docker ps -q)"; got.Cmd != want {
		t.Errorf("buildMatch: Cmd = %q, want %q", got.Cmd, want)
	}
}
