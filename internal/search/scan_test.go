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

	query := Query{Joined: "docker ps", Split: []string{"docker", "ps"}}

	for _, user := range []bool{true, false} {
		ch := make(chan Result, 4) // buffered: scanFile sends before anyone drains

		src := snippetSource{fsys: fsys, path: "notes.txt", label: "notes.txt", user: user}
		if err := scanFile(src, query, ch); err != nil {
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

	query := Query{Joined: "loop over text files", Split: []string{"loop", "over", "text", "files"}}

	ch := make(chan Result, 4)
	src := snippetSource{fsys: fsys, path: "notes.txt", label: "notes.txt"}
	if err := scanFile(src, query, ch); err != nil {
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

	err := scanFile(src, Query{}, make(chan Result))

	var pathErr *fs.PathError
	if !errors.As(err, &pathErr) {
		t.Fatalf("scanFile: err = %v, want a *fs.PathError", err)
	}
	if pathErr.Path != src.label {
		t.Errorf("scanFile: PathError.Path = %q, want %q", pathErr.Path, src.label)
	}
}

// A chunk containing the whole query as a substring is a direct match: 1000,
// unconditionally.
func TestScanChunkDirectMatchScores1000(t *testing.T) {
	query := Query{Joined: "docker ps", Split: []string{"docker", "ps"}}
	chunk := "# list running containers\ndocker ps"

	got, ok := scanChunk(query, chunk)
	if !ok {
		t.Fatal("scanChunk: ok = false, want true")
	}
	if got.Score != 1000 {
		t.Errorf("scanChunk: Score = %d, want 1000", got.Score)
	}
}

// Short of a direct match, each query word present anywhere in the chunk adds
// 5 to a 500 base.
func TestScanChunkWordMatchScores500Plus5PerWord(t *testing.T) {
	query := Query{
		Joined: "view container missing",
		Split:  []string{"view", "container", "missing"},
	}
	chunk := "# view every container\ndocker ps -a" // "view" and "container" match, "missing" doesn't

	got, ok := scanChunk(query, chunk)
	if !ok {
		t.Fatal("scanChunk: ok = false, want true")
	}
	if want := 500 + 2*5; got.Score != want {
		t.Errorf("scanChunk: Score = %d, want %d (2 of 3 query words matched)", got.Score, want)
	}
}

func TestScanChunkNoMatchReturnsFalse(t *testing.T) {
	query := Query{Joined: "kubectl get pods", Split: []string{"kubectl", "get", "pods"}}
	chunk := "# totally unrelated\necho hi"

	if _, ok := scanChunk(query, chunk); ok {
		t.Error("scanChunk: ok = true, want false when nothing matches")
	}
}

func TestCountMatches(t *testing.T) {
	tests := []struct {
		name       string
		chunkWords []string
		queryWords []string
		want       int
	}{
		{"no overlap", []string{"a", "b"}, []string{"c", "d"}, 0},
		{"every query word present", []string{"a", "b", "c"}, []string{"a", "b"}, 2},
		{"repeated query word counts each occurrence", []string{"a"}, []string{"a", "a"}, 2},
		{"repeated chunk word counts once per query word", []string{"a", "a", "a"}, []string{"a"}, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := countMatches(tt.chunkWords, tt.queryWords); got != tt.want {
				t.Errorf("countMatches(%v, %v) = %d, want %d", tt.chunkWords, tt.queryWords, got, tt.want)
			}
		})
	}
}

// Cmd keeps real newlines, since a multi-line command (a heredoc, a for
// loop) is only still valid shell with the lines kept apart. Desc joins
// with a space instead: it renders as prose on one picker row.
func TestBuildMatchJoinsCmdWithNewlineDescWithSpace(t *testing.T) {
	chunk := "# first line\n# second line\ndocker ps\ndocker stop $(docker ps -q)"

	got := buildMatch(chunk, 777)

	if want := "# first line # second line"; got.Desc != want {
		t.Errorf("buildMatch: Desc = %q, want %q", got.Desc, want)
	}
	if want := "docker ps\ndocker stop $(docker ps -q)"; got.Cmd != want {
		t.Errorf("buildMatch: Cmd = %q, want %q", got.Cmd, want)
	}
	if got.Score != 777 {
		t.Errorf("buildMatch: Score = %d, want 777", got.Score)
	}
}
