# feat: audit and expand the seed snippets

- **Priority:** medium
- **Branch:** feat/expand-seed-snippets
- **Touches:** internal/seed/*.txt
- **Blocked by:** —

## Goal
The shipped seed set is roughly 200 snippets covering what a Mac developer, SRE
or platform engineer actually runs day to day, with no duplicates, one
placeholder vocabulary, and one capitalization rule.

## Why
The seed set is the entire first impression — ADR-02 exists so a freshly
installed `wut` returns something useful before the user has written a line of
their own. 133 snippets across 14 topics is a demo; it currently has no
`kubectl`, no `ssh`, no `curl`, no `find`, while shipping three near-duplicate
IaC files.

## Notes

### The format is load-bearing

Three lines per snippet, exactly: `# description`, one command line, one blank
separator. No blank line after the last snippet; single trailing newline. The
parser splits on `"\n#"` at `internal/search/scan.go:31` and `buildMatch`
(`:114-127`) concatenates any extra command line onto the previous one **with no
separator** — see `fix/multi-line-snippet-join`. Until that fix lands, a
two-line command silently produces garbage. Do not introduce one.

`internal/seed/seed.go:11` embeds `*.txt`, so a new topic file needs no code
change. The embed pattern also fails the build if the directory ever holds no
`.txt` files.

### Audit findings to resolve — these are the substance of the pass

**Duplicates.** Each one produces two picker rows for a single query:

- `tofu.txt` is `terraform.txt` with the binary renamed — all 7 descriptions
  byte-identical (`# initialize working directory`, `# preview changes`, …)
- `du -sh DIR` and `du -sh * | sort -rh | head -n 10` appear in both `disk.txt`
  and `du.txt`, with identical descriptions
- `df -h /System/Volumes/Data` in both `disk.txt` and `shell.txt`
- `# Prompt before overwriting` in both `cp.txt:13` and `mv.txt:13`

Decide whether `disk.txt` and `du.txt` are one topic, and whether tofu earns a
file or a note inside the terraform descriptions.

**Entries that are not commands.** `shell.txt:1-24` and `k9s.txt:11,14` hold
keystrokes — `cmd + right or cmd + left`, `ctl + u`, `: then RESOURCE`. The
whole point of the tool is `cmd/root.go:96` putting the selection on the
clipboard, and a keystroke pasted into a shell is nonsense. Either move them out
of the seed set or accept them knowingly. (`ctl` should be `ctrl` regardless.)

**Placeholder vocabulary.** The `SCREAMING_SNAKE` convention is consistent, the
words are not: `IMAGE` at `docker.txt:11` vs `IMAGE_NAME` at `:29` for the same
thing; `FILE` vs `FILE_1`/`FILE_2` at `mv.txt:8`; and `COPY` at `cp.txt:2`
and `:11` reads as a command word rather than a destination slot. Pick a small
vocabulary — `DIR`, `FILE`, `SRC`, `DST`, `NAME`, `IMAGE`, `BRANCH` — and apply
it. Watch for false positives: `HEAD~1` and `/System/Volumes/Data` are literals.

**Capitalization.** 82 lowercase-initial descriptions, 51 uppercase, split by
file rather than by rule: `cp`, `git`, `mv` and `tmux` are fully uppercase, nine
files fully lowercase, `shell.txt` mixed with one outlier at `:25`. Choose one
and apply it everywhere — it's the most visible inconsistency in the picker,
since descriptions sit in a column next to each other.

### Coverage to add

Candidate topics, roughly by how often they're reached for: `kubectl`, `ssh`,
`find`/`grep`, `curl`, `jq`, `brew`, `ps`/`lsof`/`kill`, `tar`/`zip`, `awk`/`sed`,
`openssl`, `dig`/`networking`, `launchctl`. Bias toward commands whose flags
nobody remembers — that's what the tool is for. `ls -la` does not need a snippet;
`tar -xzf FILE -C DIR` does.

Keep one topic per file, since `[topic]` headers inside a file were what broke
the parser before `4359aaa`.

### Scope

Existing snippets are kept, rewritten or cut on merit — this is not a rewrite
from scratch, and it is not additive-only.

## Done when
- [ ] Roughly 200 snippets total; `grep -c '^#' internal/seed/*.txt` sums to it
- [ ] No command line appears in two files
- [ ] Every snippet is exactly 3 lines (`# desc`, command, blank), last snippet
      excepted, verified by script rather than by eye
- [ ] Description capitalization follows one rule across all files
- [ ] Placeholders use one vocabulary; no placeholder reads as a command word
- [ ] The keystroke entries are resolved deliberately, either way
- [ ] `wut kubectl logs`, `wut find files`, `wut tar extract` each return
      something useful
- [ ] `go build ./...` and `go vet ./...` pass
