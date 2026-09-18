package search

import (
	"testing"
	"testing/fstest"
)

// Ranking is only as good as the flag it sorts on, and scanFile is the single
// place that knows which file a match came from. Standing both origins up with
// fstest.MapFS is the payoff of scanFile reading through fs.FS rather than
// os.Open: the seed set and ~/.wut are the same kind of thing to it.
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
