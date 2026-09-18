package search

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"strings"
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

	defer file.Close()

	scanner := bufio.NewScanner(file)

	multiByteDelimiter := []byte("\n#")

	scanner.Split(func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if atEOF && len(data) == 0 {
			return 0, nil, nil
		}

		if i := bytes.Index(data, multiByteDelimiter); i >= 0 {
			// Move the read pointer past the chunk and the delimiter length
			return i + 1, data[0:i], nil
		}

		if atEOF {
			return len(data), data, nil
		}

		return 0, nil, nil
	})

	for scanner.Scan() {

		matches := scanChunk(query, scanner.Text())

		for _, v := range matches {
			// The one place that holds both the results and the file they came
			// from. scanChunk is about text, not where the text lives.
			v.FromUser = src.user
			ch <- v
		}

	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("reading %s: %w", src.label, err)
	}

	return nil
}

func scanChunk(query Query, chunk string) []Result {
	var matches []Result

	// Scoring System
	// Direct Match = 1000
	// Word Match = 500 + 5 per matching word

	// Direct Match
	if strings.Contains(chunk, query.Joined) {
		score := 1000
		matches = append(matches, buildMatch(chunk, score))
	} else {
		// Word Match
		wordMatches := countMatches(strings.Fields(chunk), query.Split)

		if wordMatches > 0 {
			score := 500 + (wordMatches * 5)
			matches = append(matches, buildMatch(chunk, score))
		}
	}

	return matches
}

func countMatches(slice1, slice2 []string) int {
	// Step 1: Populate a map with items from the first slice
	seen := make(map[string]bool)
	for _, item := range slice1 {
		seen[item] = true
	}

	// Step 2: Loop through the second slice and count matches
	matchCount := 0
	for _, item := range slice2 {
		if seen[item] {
			matchCount++
			// Optional: Delete the item if you only want to count unique matches
			// delete(seen, item)
		}
	}

	return matchCount
}

func buildMatch(chunk string, score int) Result {
	result := Result{
		Score: score,
	}

	lines := strings.Split(chunk, "\n")

	for _, line := range lines {
		if strings.HasPrefix(line, "#") {
			result.Desc += line
		} else {
			result.Cmd += line
		}
	}

	return result
}
