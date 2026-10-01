package search

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"strings"
)

func scanFile(src snippetSource, terms []string, ch chan<- Result) error {

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

func scanChunk(terms []string, chunk string) (Result, bool) {
	result := buildMatch(chunk)

	descTokens, cmdTokens := tokenize(result.Desc), tokenize(result.Cmd)

	result.Score, result.full = score(terms, descTokens, cmdTokens)
	result.length = len(descTokens) + len(cmdTokens)

	return result, result.Score > 0
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
