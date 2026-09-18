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
}

type Query struct {
	Joined string
	Split  []string
}

// NewQuery normalises raw command line arguments into a query.
func NewQuery(args []string) Query {
	// 'args' captures all arbitrary positional arguments
	for i := range args {
		args[i] = strings.ToLower(args[i])
	}

	return Query{
		Joined: strings.Join(args, " "),
		Split:  args,
	}
}

// Find returns every match for query, ranked best first.
//
// Files that could not be read come back as warnings: a file it could not open
// is a fact, and whether that fact deserves a line on stderr belongs to the
// caller. An error means nothing could be read at all.
func Find(query Query) (results []Result, warnings []error, err error) {
	files, err := listFiles()
	if err != nil {
		return nil, nil, err
	}

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

	// 3. Close the channel once all children are completely done
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

	// Some files worked, so any errors are the caller's to report or ignore.
	return finalResults, scanErrs, nil
}
