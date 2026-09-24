# chore: ship releases through Homebrew

- **Priority:** low
- **Branch:** chore/homebrew-release
- **Touches:** .goreleaser.yaml, .github/workflows/release.yml, README.md
- **Blocked by:** doc-add-license, chore-add-ci

## Goal
`brew install dannycastillo/tap/wut` installs a working binary, and cutting a
release is `git tag v0.2.0 && git push --tags`.

## Why
The whole pitch is "install it and try it in ten seconds." `go install` requires
a Go toolchain, which most of the audience for a CLI portfolio piece won't have
open. Homebrew is how Mac developers install things.

## Notes

### Two repos

This one gets `.goreleaser.yaml` and a release workflow. A second repo,
`dannycastillo/homebrew-tap`, holds `Formula/wut.rb`, written by goreleaser on
every tag. Nobody edits the formula by hand.

`homebrew-core` is not the target — it requires notability (roughly 75 stars)
and a review queue. A personal tap works on day one; core is a later decision if
the project gets traction.

### Manual steps only the maintainer can do

1. Create the `dannycastillo/homebrew-tap` repo, public, with a README.
2. Create a GitHub personal access token with write access to it.
3. Add it to this repo as the `HOMEBREW_TAP_GITHUB_TOKEN` secret.

The workflow can't run before those exist. Do them first, not after debugging a
red build.

### goreleaser config

- Builds: `darwin` and `linux`, `arm64` and `amd64`. `CGO_ENABLED=0`.
- `-ldflags "-s -w"`, and inject a version string — the binary should be able to
  report what it is. That means adding a `version` variable and probably a
  `--version` flag, which is a real (small) code change, not just config.
- `brews:` block pointing at the tap repo, with `license: "MIT"` — hence the
  dependency on `doc/add-license`.
- Include `LICENSE` and `THIRD_PARTY_LICENSES.md` in the release archives. The
  binary contains the dependencies' code, so their licenses ship with it.
- Run `goreleaser check` and `goreleaser release --snapshot --clean` locally
  before tagging anything. A snapshot build catches config errors without
  creating a release that has to be deleted.

`brew install goreleaser` — it is not installed on this machine.

### Workflow

Triggers on `v*` tags only, needs `contents: write` to create the release, and
`fetch-depth: 0` so goreleaser can read the tag history for the changelog.

### Versioning

Start at `v0.1.0`. Pre-1.0 is honest for a tool whose snippet format could still
change.

### README

Homebrew becomes the first install option once this works. Update it here rather
than leaving `doc/write-the-readme` describing something that doesn't exist yet.

## Done when
- [ ] The tap repo exists and `HOMEBREW_TAP_GITHUB_TOKEN` is set
- [ ] `goreleaser check` passes and a local snapshot build produces binaries for
      all four platform pairs
- [ ] A `v0.1.0` tag produces a GitHub release with archives containing the
      binary, `LICENSE` and `THIRD_PARTY_LICENSES.md`
- [ ] `Formula/wut.rb` appears in the tap repo, written by the workflow
- [ ] `brew install dannycastillo/tap/wut` then `wut docker ps` works on a
      machine with no Go toolchain
- [ ] The binary reports its version
- [ ] README lists Homebrew first
- [ ] `go build ./...` and `go vet ./...` pass
