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

// A user word match at 505 beats a seed direct match at 1000. That inversion is
// the requirement: a snippet someone wrote down is the one they meant.
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

// Within one origin and score, the snippet with fewer words is the more
// specific one and comes first.
func TestShorterSnippetBreaksTie(t *testing.T) {
	long := res("find DIR -type f -size +100M -exec ls -lh {} +", 27, false)
	long.length = 20
	short := res("find DIR -type f -size +100M", 27, false)
	short.length = 12

	results := []Result{long, short}

	rank(results)

	if got, want := results[0].Cmd, short.Cmd; got != want {
		t.Errorf("first = %q, want %q", got, want)
	}
}

// Within one origin, highest score first.
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

// Results arrive in goroutine order and sort.Slice is not stable, so every
// permutation of the same matches must rank to the identical list.
func TestSameInputRanksIdentically(t *testing.T) {
	base := []Result{
		res("git status", 500, false),
		res("git diff", 500, false),
		res("git add -A", 500, true),
		res("git commit", 1000, false),
		res("git log", 500, true),
	}

	// User snippets first, then seed by score, alphabetical within each tie.
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
