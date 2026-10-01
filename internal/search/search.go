// Package search finds the snippets matching a query and ranks them. It reads
// files and nothing else: what to report, and whether to report it at all, is
// the caller's decision.
package search

import (
	"errors"
	"strings"
	"sync"
)

type Result struct {
	Desc     string
	Cmd      string
	Score    int
	FromUser bool
	length   int  // tokens in Desc and Cmd; a shorter snippet is a more specific one
	full     bool // every query term matched
}

type Query struct {
	Phrase string   // the words as typed, for messages
	Terms  []string // what is matched: distinct, lowercased, stop words dropped
}

// NewQuery turns the command line arguments into a query.
func NewQuery(args []string) Query {
	phrase := strings.Join(args, " ")
	return Query{Phrase: phrase, Terms: queryTerms(phrase)}
}

// stopWords are the words a query can carry without meaning them. Every
// term has to match for a snippet to count as a full hit, so "show the size
// of a directory" would otherwise fall through to the partial list over
// "the" and "a". They are the most frequent words in the seed descriptions.
var stopWords = map[string]bool{
	"a": true, "an": true, "the": true, "and": true, "or": true,
	"of": true, "to": true, "in": true, "on": true, "for": true, "with": true,
	"my": true, "me": true, "i": true, "how": true, "do": true, "is": true, "it": true,
}

// queryTerms is the query as distinct tokens, so "docker-ps" and "docker ps"
// search alike and a word typed twice does not count twice. Stop words are
// dropped unless the query is nothing but stop words.
func queryTerms(phrase string) []string {
	var terms, kept []string
	seen := make(map[string]bool)
	for _, t := range tokenize(phrase) {
		if seen[t] {
			continue
		}
		seen[t] = true
		terms = append(terms, t)
		if !stopWords[t] {
			kept = append(kept, t)
		}
	}
	if len(kept) == 0 {
		return terms
	}
	return kept
}

// Find returns every match for query, ranked best first. Files it could not
// read come back as warnings; err is set only when nothing could be read.
func Find(query Query) (results []Result, warnings []error, err error) {
	files, err := listFiles()
	if err != nil {
		return nil, nil, err
	}

	return findIn(files, query)
}

// findIn is Find's fan-out, split out so it can be driven by sources a test
// controls rather than listFiles' real seed and ~/.wut.
func findIn(files []snippetSource, query Query) (results []Result, warnings []error, err error) {
	var wg sync.WaitGroup

	wg.Add(len(files))

	resultsChan := make(chan Result)
	errsChan := make(chan error, len(files))

	for _, v := range files {
		go func() {
			defer wg.Done()
			if err := scanFile(v, query.Terms, resultsChan); err != nil {
				errsChan <- err
			}
		}()
	}

	go func() {
		wg.Wait()
		close(resultsChan)
		close(errsChan)
	}()

	var finalResults []Result
	for r := range resultsChan {
		finalResults = append(finalResults, r)
	}

	var scanErrs []error
	for e := range errsChan {
		scanErrs = append(scanErrs, e)
	}

	if len(scanErrs) == len(files) {
		return nil, nil, errors.Join(scanErrs...) // nothing worked: fail
	}

	finalResults = prune(finalResults)
	rank(finalResults)

	return finalResults, scanErrs, nil // some worked: degrade
}

// prune keeps only the snippets matching every query term. Partial matches
// are the fallback, not the long tail: "git log" means the log snippets, not
// every snippet with "git" in it, but a misspelt word should still find
// something rather than nothing.
func prune(results []Result) []Result {
	var full []Result
	for _, r := range results {
		if r.full {
			full = append(full, r)
		}
	}
	if len(full) == 0 {
		return results
	}
	return full
}
