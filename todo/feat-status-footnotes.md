# feat: footnote the WHY text aih status cuts off

- **Priority:** medium
- **Branch:** feat/status-footnotes
- **Touches:** ai-harness/verbs/status.sh, ai-harness/README.md
- **Blocked by:** —

## Goal
Every WHY cell that `aih status` cuts off ends in a footnote marker, and the
full text is printed under the table.

## Why
A park's detail is the part a human acts on. It is also the part that gets cut:
on 2026-09-24 a parked row read
`protected-path: ai-harness/README.md (M);ai-harn…`, and the paths were only
readable in the `run set` footer or `aih log`.

## Notes

Target shape:

```
TODO                 PRI     STATE     WHY
feat-status-table    medium  parked    protected-path: ai-harness/README.md (M);a… [1]
feat-theme-aware…    low     held      conflicts with runnable feat-help-above-re… [2]
chore-add-ci         high    runnable

[1] protected-path: ai-harness/README.md (M);ai-harness/verbs/status.sh (M)
[2] conflicts with runnable feat-help-above-results on internal/ui/list_picker.go
lock run held by …
run set (1), started 08:37:38, …
```

- Truncation happens in the `awk` pass in `ai-harness/verbs/status.sh`, around
  `:145` (`whymax`) and `:152` (`substr(...) "…"`). Number the footnotes and
  collect them there, in the same pass, so markers and footnotes cannot
  disagree.
- Reserve room for the marker in `whymax`. With the marker, a row must still
  fit 100 columns. Size the reservation from the footnote count (`[9]` versus
  `[10]`), or reserve the widest marker for every row.
- A footnote line prints the full WHY and is not truncated. It may pass 100
  columns, because a footnote exists to show the whole text. Don't wrap it.
  Wrapping would break copying a path or a command out of it.
- Only truncated cells get a footnote. A WHY that fits gets no marker.
- Footnotes go straight under the table, before the `lock` lines and the
  `run set` footer (`ai_harness_run_status`), which keep their place.
- The existing comment on the byte-counted `…` stays true. The marker is
  ASCII, so it adds no new width problem.
- Every path in Touches is under `ai-harness/`, so `aih check` parks the branch
  as `protected-path` and it needs a hand merge. That is expected, not a
  failure.

## Done when
- [ ] Every WHY cut with `…` ends in ` [n]`, numbered from 1 in table order
- [ ] For each marker, a line `[n] <full WHY>` prints under the table
- [ ] A WHY that fits gets no marker and no footnote
- [ ] Every table row, marker included, fits in 100 columns
- [ ] With no truncated cells, no blank line or footnote block is printed
- [ ] The `lock` lines and the `run set` footer still follow, unchanged
- [ ] README's `status` description mentions the footnotes
- [ ] `aih gate --full` passes
