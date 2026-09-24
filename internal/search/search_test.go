package search

import "testing"

// NewQuery aliases the caller's slice rather than copying it. Pinned here
// rather than changed: cmd/root.go hands it args it doesn't reuse, so the
// aliasing is harmless in practice, and this branch is coverage, not a
// behavior change.
func TestNewQueryLowercasesArgsInPlace(t *testing.T) {
	args := []string{"Docker", "PS"}

	q := NewQuery(args)

	if args[0] != "docker" || args[1] != "ps" {
		t.Errorf("NewQuery: caller's slice = %v, want it lowercased in place", args)
	}
	if q.Joined != "docker ps" {
		t.Errorf("NewQuery: Joined = %q, want %q", q.Joined, "docker ps")
	}
	if len(q.Split) != 2 || q.Split[0] != "docker" || q.Split[1] != "ps" {
		t.Errorf("NewQuery: Split = %v, want [docker ps]", q.Split)
	}
}
