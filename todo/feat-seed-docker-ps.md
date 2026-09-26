# feat: ship docker ps snippets in the seed set

- **Priority:** low
- **Branch:** feat/seed-docker-ps
- **Touches:** internal/seed/docker.txt
- **Blocked by:** —

## Goal
`wut list containers` and `wut running containers` return a `docker ps` snippet.

## Why
The seed set has run, exec, logs, cp and prune for docker but nothing that lists
containers, which is the most common docker query. Search cannot rank what is
not there.

## Notes
`internal/seed/docker.txt`, same three-line shape as its neighbours. Two
snippets: `docker ps` described as listing running containers, and
`docker ps -a` for every container including stopped ones. Descriptions are
lowercase prose like the rest of the file. `internal/search/golden_test.go`
pins first results for seed queries; add a row for `list containers` once the
snippet exists.

## Done when
- [ ] `docker ps` and `docker ps -a` are in `internal/seed/docker.txt`
- [ ] `list containers` has a golden row in `internal/search/golden_test.go`
- [ ] `go build ./...` and `go vet ./...` pass
