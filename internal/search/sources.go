package search

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"wut/internal/seed"
)

// snippetSource is one file of snippets. fs.FS is the common interface between
// the seed set compiled into the binary and the user's files on disk, so
// scanFile never needs to know which of the two it was handed.
type snippetSource struct {
	fsys  fs.FS
	path  string // path within fsys, which is not a path on disk for seed files
	label string // how to name this file in an error message
	user  bool   // from ~/.wut rather than the shipped seed set
}

// listFiles returns the seed snippets shipped in the binary, followed by every
// *.txt under ~/.wut. The seed set is always searched, so a user who has not
// created ~/.wut yet still gets results rather than an error.
func listFiles() ([]snippetSource, error) {
	files, err := collectTxt(seed.FS, false, func(p string) string { return "seed/" + p })
	if err != nil {
		return nil, fmt.Errorf("reading embedded seed snippets: %w", err)
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("locating home directory: %w", err)
	}

	dir := filepath.Join(home, ".wut")

	userFiles, err := collectTxt(os.DirFS(dir), true, func(p string) string {
		return filepath.Join(dir, p)
	})

	// No ~/.wut is the ordinary state of a fresh install, not a failure: the
	// seed set still answers the query. Any other error is worth reporting.
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, fmt.Errorf("reading %s: %w", dir, err)
	}

	return append(files, userFiles...), nil
}

// collectTxt walks fsys and returns every *.txt in it, labelled for error
// messages by label, which receives the path within fsys. user marks the
// results as the caller's own snippets rather than the shipped seed set.
func collectTxt(fsys fs.FS, user bool, label func(string) string) ([]snippetSource, error) {
	var found []snippetSource

	err := fs.WalkDir(fsys, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(strings.ToLower(p), ".txt") {
			return nil
		}
		found = append(found, snippetSource{fsys: fsys, path: p, label: label(p), user: user})
		return nil
	})

	return found, err
}
