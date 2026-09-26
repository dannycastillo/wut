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
	length   int // tokens in Desc and Cmd; a shorter snippet is a more specific one
}

type Query struct {
	Joined string
	Split  []string
}

// NewQuery normalises raw command line arguments into a query.
func NewQuery(args []string) Query {
	for i := range args {
		args[i] = strings.ToLower(args[i])
	}

	return Query{
		Joined: strings.Join(args, " "),
		Split:  args,
	}
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
			if err := scanFile(v, query, resultsChan); err != nil {
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

	rank(finalResults)

	return finalResults, scanErrs, nil // some worked: degrade
}
