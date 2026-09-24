// Package seed holds the snippets wut ships with, compiled into the binary so
// a fresh install returns results before the user has written any.
package seed

import "embed"

// FS is the shipped snippet set. The embed pattern fails the build when this
// directory holds no .txt, so an empty seed set cannot ship by accident.
//
//go:embed *.txt
var FS embed.FS
