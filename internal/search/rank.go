package search

import "sort"

// rank orders the picker: the user's own snippets first, then by score,
// then by text so that the same query gives the same order every run.
//
// Precedence is a sort key rather than a score bonus. A bonus large enough to
// outrank seed today is a number that quietly stops being large enough if the
// scoring in scanChunk changes; a comparator branch cannot be outscored.
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
