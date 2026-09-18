package search

import "testing"

// res builds a Result carrying only the fields ranking reads.
func res(cmd string, score int, fromUser bool) Result {
	return Result{Cmd: cmd, Desc: "# " + cmd, Score: score, FromUser: fromUser}
}

// order renders a ranked slice as the sequence of commands the picker shows.
func order(results []Result) []string {
	out := make([]string, len(results))
	for i, r := range results {
		out[i] = r.Cmd
	}
	return out
}

// Snippets the user wrote outrank the shipped set outright — a direct match in
// seed scores 1000 and a word match in the user's own file scores 505, and the
// user's still comes first. That inversion is the requirement, not a scoring
// bug: a snippet someone wrote down is the one they meant.
func TestUserSnippetsOutrankSeed(t *testing.T) {
	results := []Result{
		res("docker ps", 1000, false),
		res("docker ps --format table", 505, true),
	}

	rank(results)

	if got, want := results[0].Cmd, "docker ps --format table"; got != want {
		t.Errorf("first = %q, want %q", got, want)
	}
}

// Within one origin the picker runs highest score first. Score was written by
// buildMatch and read by nothing at all before this.
func TestHigherScoreWins(t *testing.T) {
	results := []Result{
		res("word match", 505, false),
		res("direct match", 1000, false),
		res("better word match", 520, false),
	}

	rank(results)

	want := []string{"direct match", "better word match", "word match"}
	for i, got := range order(results) {
		if got != want[i] {
			t.Errorf("position %d = %q, want %q", i, got, want[i])
		}
	}
}

// Results reach the coordinator in goroutine-completion order, which is
// nondeterministic, and sort.Slice is not stable — so equal scores have to
// break on something that does not move between runs. Every permutation of the
// same matches must rank to the identical list, or the same query shows a
// different order each time it is run.
func TestSameInputRanksIdentically(t *testing.T) {
	base := []Result{
		res("git status", 500, false),
		res("git diff", 500, false),
		res("git add -A", 500, true),
		res("git commit", 1000, false),
		res("git log", 500, true),
	}

	// Both user snippets first and alphabetical between themselves, then the
	// seed snippets by score, alphabetical where the scores tie.
	want := []string{"git add -A", "git log", "git commit", "git diff", "git status"}

	for _, perm := range [][]int{
		{0, 1, 2, 3, 4},
		{4, 3, 2, 1, 0},
		{2, 0, 4, 1, 3},
		{3, 1, 0, 4, 2},
	} {
		shuffled := make([]Result, len(perm))
		for i, p := range perm {
			shuffled[i] = base[p]
		}

		rank(shuffled)

		for i, got := range order(shuffled) {
			if got != want[i] {
				t.Errorf("permutation %v: position %d = %q, want %q", perm, i, got, want[i])
			}
		}
	}
}
