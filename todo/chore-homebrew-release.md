# chore: ship prebuilt binaries through Homebrew

- **Priority:** high
- **Branch:** chore/homebrew-release
- **Touches:** .github/workflows/release.yml, main.go, cmd/root.go, README.md, RELEASING.md, packaging/*
- **Blocked by:** —

## Goal
`brew install dannycastillo/tap/wut` installs a prebuilt binary on a machine
with no Go toolchain, and a release is a tag plus one formula bump in the tap.

## Why
The pitch is "install it and try it in ten seconds". `go install` needs Go, a
source formula makes brew install Go, and a binary formula needs neither.
Building the binaries here, not in the tap, keeps them useful outside
Homebrew and keeps the tap as dumb as it is for ai-harness.

## Notes

### Same process as ai-harness

`dannycastillo/homebrew-tap` already exists and holds `Formula/ai-harness.rb`.
Its release flow is the model: tag → CI attaches assets to a GitHub Release →
a human copies the formula into the tap with the new urls and shas. No
goreleaser, no token, no automation that writes to the tap. The only
difference is that the assets are four binary tarballs instead of one source
tarball.

### Precondition: the repo must be public

Brew downloads release assets anonymously. Nobody, the maintainer included,
can `brew install` from a private repo's Releases. Making the repo public is
the maintainer's call and comes before the first tag.

### Version flag

Cobra gives `--version` for free from `rootCmd.Version`. Declare
`var version = "dev"` in `main.go` and pass it to `cmd.Execute`, so the
ldflags target is `-X main.version=...` and does not change when
`chore-fix-go-mod-module-path` renames the module. The tag is the version;
there is no `VERSION` file to keep in sync.

### Release workflow

`.github/workflows/release.yml`, on `v*` tags, `permissions: contents: write`,
one `ubuntu-latest` job. Cross-compile the four pairs with `CGO_ENABLED=0`
(verified: all four build today, about 5 MB each with `-s -w`):

- darwin/arm64, darwin/amd64, linux/arm64, linux/amd64
- `-trimpath -ldflags "-s -w -X main.version=${GITHUB_REF_NAME#v}"`
- archive `wut_<version>_<os>_<arch>.tar.gz` holding `wut`, `LICENSE` and
  `THIRD_PARTY_LICENSES.md`; the binary links the dependencies, so their
  notices ship with it
- one `checksums.txt` from `sha256sum *.tar.gz`, the file the formula bump
  reads from
- `gh release create "$GITHUB_REF_NAME" *.tar.gz checksums.txt --generate-notes`

`.github/workflows/*` is in `AI_HARNESS_PROTECTED`, so `aih integrate` parks
this branch and the maintainer merges it by hand. Expected, not a failure.

### Formula

`packaging/wut.rb` lives in this repo for review, like
`packaging/ai-harness.rb` in ai-harness. A release copies it into the tap as
`Formula/wut.rb` with the four `url` and `sha256` pairs filled in. Shape:
`on_macos` / `on_linux` each wrapping `on_arm` / `on_intel`, `version`
declared once, `def install; bin.install "wut"; end`, and a `test do` that
asserts `wut --version` prints the version. Run `brew audit --strict wut` and
`brew test wut` by hand before pushing the bump; the tap's scaffolded CI only
runs on pull requests there.

### RELEASING.md

At the repo root (ADRs are the only thing in `docs/`). The maintainer's
checklist, modelled on ai-harness's: make sure the tag's commit is on `main`,
tag, wait for `release.yml`, download `checksums.txt`, update the four pairs in
the tap, audit, test, push, `brew upgrade wut`. Include the few lines of shell
that rewrite the formula from `checksums.txt`, since four hashes typed by hand
is where a bump goes wrong.

### README

Homebrew replaces the "Coming once `chore/homebrew-release` lands" placeholder
and is listed first. One line: `brew install dannycastillo/tap/wut`. Brew taps
`dannycastillo/homebrew-tap` on its own from the qualified name; no separate
`brew tap` step.

### Versioning

Start at `v0.1.0`. Pre-1.0 is honest for a tool whose snippet format could
still change.

### Not blocked on the module path

`chore-fix-go-mod-module-path` is independent: brew builds nothing, so
`module wut` does not matter here. Running it first is nicer, since the first
tag then also works for `go install`, but it is not required.

## Done when
- [ ] `wut --version` prints the injected version, and `dev` when built plainly
- [ ] `.github/workflows/release.yml` builds the four tarballs and
      `checksums.txt` and attaches them to a release on a `v*` tag
- [ ] A snapshot of the same build steps runs locally and produces all four
- [ ] `packaging/wut.rb` is committed with the four-pair shape above
- [ ] `RELEASING.md` exists at the root with the checklist and the bump snippet
- [ ] README lists Homebrew first, placeholder gone
- [ ] `go build ./...` and `go vet ./...` pass

Maintainer, after the merge and once the repo is public:
- [ ] `v0.1.0` tagged; the release carries four tarballs and `checksums.txt`
- [ ] `Formula/wut.rb` in the tap points at them; `brew audit --strict` and
      `brew test` pass
- [ ] `brew install dannycastillo/tap/wut` then `wut docker ps` works on a
      machine with no Go toolchain
