package search

import (
	"strings"
	"testing"

	"wut/internal/seed"
)

// The shipped snippets are the fixture: for each query, the first row the
// picker shows is the one a user means. A scoring change that moves any of
// these is a ranking regression, whatever the new numbers are.
func TestSeedQueriesRankExpectedFirst(t *testing.T) {
	files, err := collectTxt(seed.FS, false, func(p string) string { return "seed/" + p })
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		query string
		first string
	}{
		{"directory size", "du -sh DIR"},
		{"size of directory", "du -sh DIR"},
		{"find large files", "find DIR -type f -size +100M"},
		{"running containers", "docker exec -it CONTAINER bash"},
		{"delete branch", "git branch -D BRANCH"},
		{"kill port", "kill -9 $(lsof -t -i :PORT)"},
		{"git log", "git log --oneline --graph --decorate"},
		{"Docker-Exec", "docker exec -it CONTAINER bash"},
	}
	for _, tt := range tests {
		t.Run(tt.query, func(t *testing.T) {
			results, _, err := findIn(files, NewQuery(strings.Fields(tt.query)))
			if err != nil {
				t.Fatal(err)
			}
			if len(results) == 0 {
				t.Fatalf("no results, want %q first", tt.first)
			}
			if got := results[0].Cmd; got != tt.first {
				t.Errorf("first = %q, want %q", got, tt.first)
			}
		})
	}
}

// A single short word matches whole words only: "tar" finds tar, not
// "start", and "ls" does not find "else's".
func TestSeedSingleWordMatchesWholeWords(t *testing.T) {
	files, err := collectTxt(seed.FS, false, func(p string) string { return "seed/" + p })
	if err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		query   string
		absent  string
		present string
	}{
		{"tar", "start", "tar "},
		{"ls", "force-with-lease", "ls-remote"},
	}
	for _, tt := range tests {
		t.Run(tt.query, func(t *testing.T) {
			results, _, err := findIn(files, NewQuery([]string{tt.query}))
			if err != nil {
				t.Fatal(err)
			}

			found := false
			for _, r := range results {
				if strings.Contains(r.Cmd, tt.absent) {
					t.Errorf("%q matched %q", tt.query, r.Cmd)
				}
				if strings.Contains(r.Cmd, tt.present) {
					found = true
				}
			}
			if !found {
				t.Errorf("%q found no command containing %q", tt.query, tt.present)
			}
		})
	}
}
