package search

import "sort"

// rank orders the picker: the user's own snippets first, then by score, then
// by text. Origin is a sort key, not a score bonus, so it cannot be outscored.
func rank(results []Result) {
	sort.Slice(results, func(i, j int) bool {
		a, b := results[i], results[j]

		switch {
		case a.FromUser != b.FromUser:
			return a.FromUser // your snippets outrank the shipped set outright
		case a.Score != b.Score:
			return a.Score > b.Score
		case a.Cmd != b.Cmd:
			return a.Cmd < b.Cmd
		default:
			// sort.Slice is not stable and the results arrive in goroutine
			// order, so ties need a tiebreak that does not move between runs.
			return a.Desc < b.Desc
		}
	})
}
