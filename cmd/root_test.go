package cmd

import (
	"bytes"
	"errors"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/dannycastillo/wut/internal/search"
	"github.com/dannycastillo/wut/internal/ui"
)

// stubSeams saves run's three package-level seams and restores them after the
// test, so tests can swap in fakes without leaking state between each other.
func stubSeams(t *testing.T) {
	t.Helper()
	origFind, origPick, origClip := searchFind, uiPick, clipboardWrite
	t.Cleanup(func() {
		searchFind, uiPick, clipboardWrite = origFind, origPick, origClip
	})
}

// withStderr runs f with os.Stderr redirected to a pipe and returns what was
// written to it.
func withStderr(t *testing.T, f func()) string {
	t.Helper()

	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}

	orig := os.Stderr
	os.Stderr = w
	f()
	os.Stderr = orig
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}

	var buf bytes.Buffer
	if _, err := io.Copy(&buf, r); err != nil {
		t.Fatal(err)
	}
	return buf.String()
}

func TestRunSearchErrorPropagates(t *testing.T) {
	stubSeams(t)

	wantErr := errors.New("boom")
	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return nil, nil, wantErr
	}

	if err := run(search.Query{}); !errors.Is(err, wantErr) {
		t.Errorf("run() err = %v, want %v", err, wantErr)
	}
}

func TestRunWarningsGoToStderrAndStillSucceed(t *testing.T) {
	stubSeams(t)

	warnErr := errors.New("notes.txt: permission denied")
	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return []search.Result{{Cmd: "docker ps", Desc: "# list"}}, []error{warnErr}, nil
	}
	uiPick = func([]ui.Choice) (int, error) { return -1, ui.ErrAborted }

	var err error
	out := withStderr(t, func() { err = run(search.Query{}) })

	if err != nil {
		t.Fatalf("run() err = %v, want nil", err)
	}
	if !strings.Contains(out, warnErr.Error()) {
		t.Errorf("stderr = %q, want it to contain %q", out, warnErr.Error())
	}
}

func TestRunEmptyResultsExitsZero(t *testing.T) {
	stubSeams(t)

	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return nil, nil, nil
	}
	uiPick = func([]ui.Choice) (int, error) {
		t.Fatal("uiPick called with no results")
		return -1, nil
	}

	var err error
	out := withStderr(t, func() { err = run(search.Query{Phrase: "docker"}) })

	if err != nil {
		t.Fatalf("run() err = %v, want nil", err)
	}
	if !strings.Contains(out, "No Results Found For: docker") {
		t.Errorf("stderr = %q, want the no-results message", out)
	}
}

func TestRunErrAbortedExitsZero(t *testing.T) {
	stubSeams(t)

	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return []search.Result{{Cmd: "docker ps"}}, nil, nil
	}
	uiPick = func([]ui.Choice) (int, error) { return -1, ui.ErrAborted }
	clipboardWrite = func(string) error {
		t.Fatal("clipboard written after the picker was aborted")
		return nil
	}

	if err := run(search.Query{}); err != nil {
		t.Errorf("run() err = %v, want nil", err)
	}
}

func TestRunPickerErrorWrapped(t *testing.T) {
	stubSeams(t)

	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return []search.Result{{Cmd: "docker ps"}}, nil, nil
	}
	pickErr := errors.New("boom")
	uiPick = func([]ui.Choice) (int, error) { return -1, pickErr }

	if err := run(search.Query{}); !errors.Is(err, pickErr) {
		t.Errorf("run() err = %v, want it to wrap %v", err, pickErr)
	}
}

func TestRunClipboardErrorWrapped(t *testing.T) {
	stubSeams(t)

	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return []search.Result{{Cmd: "docker ps"}}, nil, nil
	}
	uiPick = func([]ui.Choice) (int, error) { return 0, nil }
	clipErr := errors.New("no clipboard")
	clipboardWrite = func(string) error { return clipErr }

	if err := run(search.Query{}); !errors.Is(err, clipErr) {
		t.Errorf("run() err = %v, want it to wrap %v", err, clipErr)
	}
}

// The index ui.Pick returns is read back into results, not choices, so the
// two slices have to stay in lockstep — this pins that they do.
func TestRunChoiceIndexMatchesResult(t *testing.T) {
	stubSeams(t)

	results := []search.Result{
		{Cmd: "docker ps", Desc: "# list"},
		{Cmd: "docker stop", Desc: "# stop"},
		{Cmd: "docker rm", Desc: "# remove"},
	}
	searchFind = func(search.Query) ([]search.Result, []error, error) {
		return results, nil, nil
	}

	var gotChoices []ui.Choice
	uiPick = func(choices []ui.Choice) (int, error) {
		gotChoices = choices
		return 1, nil // "docker stop"
	}

	var gotWritten string
	clipboardWrite = func(s string) error { gotWritten = s; return nil }

	if err := run(search.Query{}); err != nil {
		t.Fatalf("run() err = %v, want nil", err)
	}

	if len(gotChoices) != len(results) {
		t.Fatalf("uiPick got %d choices, want %d", len(gotChoices), len(results))
	}
	for i, r := range results {
		if gotChoices[i].Title != r.Cmd || gotChoices[i].Desc != r.Desc {
			t.Errorf("choices[%d] = %+v, want Title=%q Desc=%q", i, gotChoices[i], r.Cmd, r.Desc)
		}
	}
	if gotWritten != "docker stop" {
		t.Errorf("clipboard got %q, want %q", gotWritten, "docker stop")
	}
}
