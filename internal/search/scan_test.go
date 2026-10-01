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

// Every query word present as a whole word, in order, is the strongest
// match a chunk can be: exact hits in the description, the full-match bonus
// and the phrase bonus all stack.
func TestScanChunkPhraseInDescScoresHighest(t *testing.T) {
	terms := []string{"running", "containers"}
	chunk := "# list running containers\ndocker ps"

	got, ok := scanChunk(terms, chunk)
	if !ok {
		t.Fatal("scanChunk: ok = false, want true")
	}
	if want := 2*descExact + 2*fullBonus + descPhrase; got.Score != want {
		t.Errorf("scanChunk: Score = %d, want %d", got.Score, want)
	}
}

// A query word found only inside another word is not a hit: "tar" must not
// pull in "start". Only a shared stem of three or more letters counts, and
// then for less than an exact word.
func TestScanChunkWordBoundaries(t *testing.T) {
	terms := []string{"tar"}

	if _, ok := scanChunk(terms, "# start a service\nbrew services start NAME"); ok {
		t.Error("scanChunk: matched \"tar\" inside \"start\"")
	}

	got, ok := scanChunk(terms, "# archive a directory\ntar -czf NAME.tar.gz DIR")
	if !ok {
		t.Fatal("scanChunk: ok = false, want true for an exact command word")
	}
	if want := cmdExact + fullBonus + cmdPhrase; got.Score != want {
		t.Errorf("scanChunk: Score = %d, want %d", got.Score, want)
	}

	got, ok = scanChunk([]string{"large"}, "# find files larger than 100 mb\nfind DIR -size +100M")
	if !ok {
		t.Fatal("scanChunk: ok = false, want true for a shared stem")
	}
	if want := descPrefix + fullBonus; got.Score != want {
		t.Errorf("scanChunk: Score = %d, want %d", got.Score, want)
	}
}

// Punctuation and case are not part of a word: "containers," matches
// "containers", and a description written in capitals still matches a
// lowercased query.
func TestScanChunkIgnoresCaseAndPunctuation(t *testing.T) {
	terms := []string{"ssh", "prod"}
	chunk := "# SSH into Prod, carefully\nssh me@prod"

	got, ok := scanChunk(terms, chunk)
	if !ok {
		t.Fatal("scanChunk: ok = false, want true")
	}
	if want := 2*descExact + 2*fullBonus; got.Score != want {
		t.Errorf("scanChunk: Score = %d, want %d", got.Score, want)
	}
}

// Any one word matching is enough to score, but a chunk hitting every word
// outranks one hitting more words of a longer query, and only it is full.
func TestScorePartialMatchNeverBeatsFullMatch(t *testing.T) {
	terms := []string{"size", "of", "directory"}

	full, isFull := score(terms, tokenize("# check size of a directory"), tokenize("du -sh DIR"))
	partial, partialFull := score(terms, tokenize("# create a gzipped archive of a directory"), tokenize("tar -czf NAME.tar.gz DIR"))
	ofOnly, ofOnlyFull := score(terms, tokenize("# print the second column of a csv"), tokenize("awk -F, '{print $2}' FILE"))

	if full <= partial || partial <= ofOnly || ofOnly <= 0 {
		t.Errorf("score: full %d, partial %d, one word %d; want strictly descending and all > 0", full, partial, ofOnly)
	}
	if !isFull || partialFull || ofOnlyFull {
		t.Errorf("score: full = %v, %v, %v; want only the chunk with every word", isFull, partialFull, ofOnlyFull)
	}
}

func TestScanChunkNoMatchReturnsFalse(t *testing.T) {
	terms := []string{"kubectl", "get", "pods"}
	chunk := "# totally unrelated\necho hi"

	if _, ok := scanChunk(terms, chunk); ok {
		t.Error("scanChunk: ok = true, want false when nothing matches")
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
