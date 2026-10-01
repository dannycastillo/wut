# wut

[![CI](https://github.com/dannycastillo/wut/actions/workflows/ci.yml/badge.svg)](https://github.com/dannycastillo/wut/actions/workflows/ci.yml)

Search your own command-line notes from the terminal and copy the result to
the clipboard.

## Install

Needs Go 1.26 or newer.

### Homebrew

Coming once `chore/homebrew-release` lands.

### go install

```sh
go install github.com/dannycastillo/wut@latest
```

Needs a published tag; `v0.1.0` doesn't exist yet.

This puts `wut` on `$GOBIN` (or `$GOPATH/bin` if `$GOBIN` isn't set) — make
sure that's on your `$PATH`.

### Build from source

```sh
git clone https://github.com/dannycastillo/wut.git
cd wut
go build -o wut .
```

Move the resulting `wut` binary anywhere on your `$PATH`.

## Usage

```sh
wut directory size
```

`wut` searches every snippet for your words and opens a picker with the
matches ranked best first:

- `↑`/`↓` (or `k`/`j`) move the highlight
- `enter` copies the highlighted command to the clipboard and exits
- `q`, `esc`, or `ctrl+c` closes the picker without copying anything

## Adding your own snippets

Drop a `.txt` file into `~/.wut/` — any name, and as many files as you like.
Each snippet is three lines: a `#` description, the command, and a blank
line:

```
# ssh into the staging box
ssh me@staging.example.com

# tail the app logs
kubectl logs -f deploy/app
```

Get this shape wrong — no blank line, no leading `#` — and the snippet is
silently parsed wrong instead of raising an error, so match it exactly.

Your own snippets always rank above the shipped ones, so they show up first
when they match.

## What ships

Around 200 snippets across git, docker, kubectl, ssh, tar and two dozen other
topics, embedded in the binary — `wut` returns results with no setup.

See `docs/` for the architecture decisions behind how it's built.

## Developing

```sh
go test ./...
```

See `AGENTS.md` for how work in this repo is organized.

## License

MIT — see [LICENSE](LICENSE). Third-party notices for the modules `wut` links
statically are in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).
