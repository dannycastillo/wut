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
			// i+1, not i+2: the "#" is kept to open the next chunk.
			return i + 1, data[0:i], nil
		}

		if atEOF {
			return len(data), data, nil
		}

		return 0, nil, nil
	})

	for scanner.Scan() {

		match, ok := scanChunk(query, scanner.Text())
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

func scanChunk(query Query, chunk string) (Result, bool) {
	if strings.Contains(chunk, query.Joined) {
		score := 1000
		return buildMatch(chunk, score), true
	}

	wordMatches := countMatches(strings.Fields(chunk), query.Split)

	if wordMatches > 0 {
		score := 500 + (wordMatches * 5)
		return buildMatch(chunk, score), true
	}

	return Result{}, false
}

func countMatches(chunkWords, queryWords []string) int {
	seen := make(map[string]bool)
	for _, item := range chunkWords {
		seen[item] = true
	}

	matchCount := 0
	for _, item := range queryWords {
		if seen[item] {
			matchCount++
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
