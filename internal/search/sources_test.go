package search

import (
	"testing"
	"testing/fstest"
)

// listFiles is left untested: its only untested branch not covered by
// collectTxt is the fs.ErrNotExist tolerance around a real os.UserHomeDir(),
// and testing that means either extracting the directory lookup or hitting
// the real home directory. Neither earns its keep for one branch.

func TestCollectTxt(t *testing.T) {
	fsys := fstest.MapFS{
		"a.txt":        &fstest.MapFile{},
		"nested/B.TXT": &fstest.MapFile{},
		"skip.md":      &fstest.MapFile{},
	}

	got, err := collectTxt(fsys, true, func(p string) string { return "label:" + p })
	if err != nil {
		t.Fatalf("collectTxt: %v", err)
	}

	byPath := make(map[string]snippetSource, len(got))
	for _, s := range got {
		byPath[s.path] = s
	}

	if len(got) != 2 {
		t.Fatalf("collectTxt: got %d files, want 2: %+v", len(got), got)
	}

	for _, path := range []string{"a.txt", "nested/B.TXT"} {
		s, ok := byPath[path]
		if !ok {
			t.Errorf("collectTxt: missing %q", path)
			continue
		}
		if !s.user {
			t.Errorf("collectTxt(%q): user = false, want true", path)
		}
		if want := "label:" + path; s.label != want {
			t.Errorf("collectTxt(%q): label = %q, want %q", path, s.label, want)
		}
	}
}
