// Scoring: how well one snippet answers the query. Ranking across snippets
// is rank.go.
package search

import (
	"strings"
	"unicode"
)

// tokenize lowercases and splits on anything that is not a letter or digit,
// so "containers," yields "containers" and "ls-remote" yields "ls", "remote".
func tokenize(s string) []string {
	return strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
}

const (
	descExact  = 6
	descPrefix = 3
	cmdExact   = 4
	cmdPrefix  = 2
	fullBonus  = 4 // per term, once every term has matched
	descPhrase = 8
	cmdPhrase  = 4
)

// score is 0 when no term matches, and full when every term does. Every
// term matched must beat any partial match however many words the partial
// hits, hence fullBonus scales with the query rather than being a constant.
func score(terms, descTokens, cmdTokens []string) (total int, full bool) {
	matched := 0

	for _, t := range terms {
		best := max(termScore(t, descTokens, descExact, descPrefix),
			termScore(t, cmdTokens, cmdExact, cmdPrefix))
		if best > 0 {
			matched++
		}
		total += best
	}

	if matched == 0 {
		return 0, false
	}

	if matched < len(terms) {
		return total, false
	}

	total += fullBonus * len(terms)

	switch {
	case containsSeq(descTokens, terms):
		total += descPhrase
	case containsSeq(cmdTokens, terms):
		total += cmdPhrase
	}

	return total, true
}

func termScore(term string, tokens []string, exact, prefix int) int {
	best := 0
	for _, tok := range tokens {
		switch {
		case tok == term:
			return exact
		case sharesStem(term, tok):
			best = prefix
		}
	}
	return best
}

// sharesStem is a stand-in for stemming: "large" matches "largest" and
// "containers" matches "container". The shorter side must be three runes or
// more, or "a" would match every word.
func sharesStem(a, b string) bool {
	short, long := a, b
	if len(short) > len(long) {
		short, long = long, short
	}
	return len(short) >= 3 && strings.HasPrefix(long, short)
}

// containsSeq reports whether terms appear in tokens consecutively, in order.
func containsSeq(tokens, terms []string) bool {
	if len(terms) == 0 {
		return false
	}
outer:
	for i := 0; i+len(terms) <= len(tokens); i++ {
		for j, t := range terms {
			if tokens[i+j] != t {
				continue outer
			}
		}
		return true
	}
	return false
}
