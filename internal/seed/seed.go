// Package seed holds the snippets wut ships with, compiled into the binary so
// the tool returns results the moment it is installed, before the user has
// written any snippets of their own.
//
// The embed pattern fails the build if this directory ever holds no .txt files,
// so a binary that ships with nothing to search cannot be produced by accident.
package seed

import "embed"

//go:embed *.txt
var FS embed.FS
