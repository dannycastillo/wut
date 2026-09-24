package search

import (
	"testing"
	"testing/fstest"
)

// scanFile is the only place that knows which file a match came from.
func TestScanFileStampsOrigin(t *testing.T) {
	fsys := fstest.MapFS{
		"notes.txt": &fstest.MapFile{Data: []byte("# view containers\ndocker ps\n")},
	}

	query := Query{Joined: "docker ps", Split: []string{"docker", "ps"}}

	for _, user := range []bool{true, false} {
		ch := make(chan Result, 4) // buffered: scanFile sends before anyone drains

		src := snippetSource{fsys: fsys, path: "notes.txt", label: "notes.txt", user: user}
		if err := scanFile(src, query, ch); err != nil {
			t.Fatalf("user=%v: scanFile: %v", user, err)
		}
		close(ch)

		var got []Result
		for r := range ch {
			got = append(got, r)
		}

		if len(got) != 1 {
			t.Fatalf("user=%v: %d results, want 1", user, len(got))
		}
		if got[0].FromUser != user {
			t.Errorf("user=%v: FromUser = %v, want %v", user, got[0].FromUser, user)
		}
	}
}
