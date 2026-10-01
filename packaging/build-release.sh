#!/bin/sh
# Usage: packaging/build-release.sh <version> [outdir]
# Builds the four release tarballs and checksums.txt. release.yml runs this,
# and so can you: packaging/build-release.sh 0.0.0-snapshot dist
set -eu

version=${1:?usage: build-release.sh <version> [outdir]}
out=${2:-dist}
root=$(cd "$(dirname "$0")/.." && pwd)

rm -rf "$out"
mkdir -p "$out"
out=$(cd "$out" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

for target in darwin/arm64 darwin/amd64 linux/arm64 linux/amd64; do
	os=${target%/*}
	arch=${target#*/}
	name=wut_${version}_${os}_${arch}
	mkdir -p "$stage/$name"
	(cd "$root" && CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath \
		-ldflags "-s -w -X main.version=$version" -o "$stage/$name/wut" .)
	cp "$root/LICENSE" "$root/THIRD_PARTY_LICENSES.md" "$stage/$name/"
	tar -C "$stage" -czf "$out/$name.tar.gz" "$name"
done

cd "$out"
sha256sum ./*.tar.gz | sed 's| \./| |' >checksums.txt
