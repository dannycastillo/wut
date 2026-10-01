# chore: drop the redundant version line from the formula template

- **Priority:** medium
- **Branch:** chore/drop-formula-version-line
- **Touches:** packaging/wut.rb, RELEASING.md
- **Blocked by:** —

## Goal
`packaging/wut.rb` matches the formula in `dannycastillo/homebrew-tap`, so the
next release's bump passes `brew audit --strict` without a hand edit.

## Why
`brew audit --strict --new` failed the v0.1.0 formula with "`version 0.1.0`
is redundant with version scanned from URL". Brew reads the version from
`wut_0.1.0_<os>_<arch>.tar.gz` in the url. The tap copy had the line removed
by hand before the push (homebrew-tap 874a3e4); the template here still has
it, so the next bump would put it back.

## Notes
- Delete the `version "0.1.0"` line from `packaging/wut.rb`. The `test do`
  block's `version.to_s` keeps working: it reads what brew scanned from the
  url.
- In `RELEASING.md`, the awk snippet under "Rewriting the formula" has a
  `/^  version /` rule. With no such line it matches nothing; delete the rule
  and the bullet that says `version` changes in the tap diff.
- Check with `diff packaging/wut.rb
  "$(brew --repository)/Library/Taps/dannycastillo/homebrew-tap/Formula/wut.rb"`:
  the only differences should be the four `sha256` values.

## Done when
- [ ] `packaging/wut.rb` has no `version` line
- [ ] The awk snippet in `RELEASING.md` has no `version` rule, and the prose
      no longer says `version` changes on a bump
- [ ] `diff` against the tap's `Formula/wut.rb` shows only sha256 lines
- [ ] `go build ./...` and `go vet ./...` pass
