# Releasing

A release is a tag, a workflow run, and one formula bump in
`dannycastillo/homebrew-tap`. Nothing writes to the tap automatically.

## Checklist

1. Confirm the commit to release is on `main` and CI is green.
2. Tag and push (`X.Y.Z` is the version, e.g. `0.1.0`):

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

3. Wait for the `Release` workflow. The release carries four
   `wut_X.Y.Z_<os>_<arch>.tar.gz` files and `checksums.txt`.
4. Download `checksums.txt` and rewrite the formula (below).
5. In the tap, audit and test:

   ```sh
   brew audit --strict --new dannycastillo/tap/wut   # drop --new after the first release
   brew install --build-from-source dannycastillo/tap/wut
   brew test wut
   ```

6. Commit `Formula/wut.rb` in the tap and push.
7. `brew update && brew upgrade wut`, then `wut --version`.

## Rewriting the formula

Run from the wut repo, with the tap checked out beside it:

```sh
v=X.Y.Z
gh release download "v$v" --repo dannycastillo/wut --pattern checksums.txt --dir /tmp --clobber
awk -v v="$v" '
  NR == FNR { sum[$2] = $1; next }
  /^  version / { print "  version \"" v "\""; next }
  /url "/ {
    sub(/download\/v[^\/]*\/wut_[^_]*_/, "download/v" v "/wut_" v "_")
    n = split($2, p, "/"); file = p[n]; gsub(/"/, "", file)
    if (!(file in sum)) { print "no checksum for " file > "/dev/stderr"; exit 1 }
  }
  /sha256 "/ { sub(/"[0-9a-f]+"/, "\"" sum[file] "\"") }
  { print }
' /tmp/checksums.txt packaging/wut.rb > ../homebrew-tap/Formula/wut.rb
```

- It fails on a missing checksum instead of writing a zero hash.
- Check `git diff` in the tap: four `url` and `sha256` pairs and `version`
  change, nothing else.

## Trying the build without a tag

```sh
packaging/build-release.sh 0.0.0-snapshot dist
```

Writes the same four tarballs and `checksums.txt` into `dist/`.
