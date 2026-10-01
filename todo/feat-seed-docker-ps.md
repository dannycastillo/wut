# feat: ship docker ps snippets in the seed set

- **Priority:** low
- **Branch:** feat/seed-docker-ps
- **Touches:** internal/seed/docker.txt, internal/search/golden_test.go
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
lowercase prose like the rest of the file.

`internal/search/golden_test.go` pins first results for seed queries. It
already pins `running containers` to `docker exec -it CONTAINER bash`, which
is the wrong answer this todo exists to fix. Flip that row to `docker ps` and
add one for `list containers`. Check `wut running containers` by hand too:
the description must outrank `docker exec`'s "open a shell in a running
container", which shares two of the words.

## Done when
- [ ] `docker ps` and `docker ps -a` are in `internal/seed/docker.txt`
- [ ] `running containers` and `list containers` both have golden rows in
      `internal/search/golden_test.go` whose first result is `docker ps`
- [ ] `go build ./...` and `go vet ./...` pass
