package search

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"strings"
	"unicode"
)

func scanFile(src snippetSource, query Query, ch chan<- Result) error {

	file, err := src.fsys.Open(src.path)

	if err != nil {
		// The error names src.path, which is relative to fsys and means nothing
		// to a reader. Swap in the label; Op and Err are already the right words.
		var pathErr *fs.PathError
		if errors.As(err, &pathErr) {
			pathErr.Path = src.label
			return pathErr
		}
		return fmt.Errorf("%s: %w", src.label, err)
	}

	defer func() { _ = file.Close() }()

	scanner := bufio.NewScanner(file)

	multiByteDelimiter := []byte("\n#")

	scanner.Split(func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if atEOF && len(data) == 0 {
			return 0, nil, nil
		}

		if i := bytes.Index(data, multiByteDelimiter); i >= 0 {
			// i+1, not i+2: the "#" is kept to open the next chunk.
			return i + 1, data[0:i], nil
		}

		if atEOF {
			return len(data), data, nil
		}

		return 0, nil, nil
	})

	terms := queryTerms(query)

	for scanner.Scan() {

		match, ok := scanChunk(terms, scanner.Text())
		if !ok {
			continue
		}

		match.FromUser = src.user
		ch <- match
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("reading %s: %w", src.label, err)
	}

	return nil
}

// queryTerms is the query as distinct tokens, so "docker-ps" and "docker ps"
// search alike and a word typed twice does not count twice.
func queryTerms(query Query) []string {
	var terms []string
	seen := make(map[string]bool)
	for _, t := range tokenize(query.Joined) {
		if !seen[t] {
			seen[t] = true
			terms = append(terms, t)
		}
	}
	return terms
}

// tokenize lowercases and splits on anything that is not a letter or digit,
// so "containers," yields "containers" and "ls-remote" yields "ls", "remote".
func tokenize(s string) []string {
	return strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
}

func scanChunk(terms []string, chunk string) (Result, bool) {
	result := buildMatch(chunk)

	descTokens, cmdTokens := tokenize(result.Desc), tokenize(result.Cmd)

	result.Score = score(terms, descTokens, cmdTokens)
	result.length = len(descTokens) + len(cmdTokens)

	return result, result.Score > 0
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

// score is 0 when no term matches. Every term matched must beat any partial
// match however many words the partial hits, hence fullBonus scales with
// the query rather than being a constant.
func score(terms, descTokens, cmdTokens []string) int {
	total, matched := 0, 0

	for _, t := range terms {
		best := max(termScore(t, descTokens, descExact, descPrefix),
			termScore(t, cmdTokens, cmdExact, cmdPrefix))
		if best > 0 {
			matched++
		}
		total += best
	}

	if matched == 0 {
		return 0
	}

	if matched == len(terms) {
		total += fullBonus * len(terms)

		switch {
		case containsSeq(descTokens, terms):
			total += descPhrase
		case containsSeq(cmdTokens, terms):
			total += cmdPhrase
		}
	}

	return total
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

func buildMatch(chunk string) Result {
	var result Result

	// scanFile's split leaves a trailing "\n" on every chunk but the file's
	// last: the delimiter eats the blank line that separates snippets, but
	// not the newline before it. Trimmed first so that newline never lands
	// in cmdLines as a spurious empty final line.
	lines := strings.Split(strings.TrimRight(chunk, "\n"), "\n")

	var descLines, cmdLines []string
	for _, line := range lines {
		if strings.HasPrefix(line, "#") {
			descLines = append(descLines, line)
		} else {
			cmdLines = append(cmdLines, line)
		}
	}

	// Cmd keeps real newlines: a heredoc or a multi-line for loop is only
	// still valid shell if the lines stay separated the way they were
	// written. Desc joins with a space instead: it renders as one row in
	// the picker, and a description is prose, not something that runs.
	result.Desc = strings.Join(descLines, " ")
	result.Cmd = strings.Join(cmdLines, "\n")

	return result
}
