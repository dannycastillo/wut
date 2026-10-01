package search

import "testing"

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
