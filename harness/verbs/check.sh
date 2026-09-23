# check — may this branch merge, mechanically? Read-only, no checkout
#
#   harness check [<todo-stem>]    defaults to the current branch's todo
#   harness check --selftest       trips every code on purpose, in a throwaway repo

# A fresh branch off trunk that has already done its bookkeeping.
_ckt_branch() {
	git checkout -q -B chore/x "$HARNESS_TRUNK"
	git rm -q todo/chore-x.md
}

# Commits the case and compares "<first code or clean> <pass|stop>" to $1.
_ckt_expect() {
	git add -A
	git -c commit.gpgsign=false commit -q --no-verify -m "${2:-chore: case}"
	_ckt_out=$(harness_check chore-x chore/x "$(harness_check_touches chore-x)") && _ckt_rc=pass || _ckt_rc=stop
	_ckt_got="$(printf '%s' "${_ckt_out:-clean}" | head -1 | cut -d' ' -f1) $_ckt_rc"
	if [ "$_ckt_got" = "$1" ]; then
		printf '    ok    %s\n' "$1"
	else
		printf '    FAIL  want %s, got %s\n%s\n' "$1" "$_ckt_got" "$(printf '%s\n' "$_ckt_out" | sed 's/^/            /')"
		_ckt_bad=$((_ckt_bad + 1))
	fi
}

_ckt_selftest() {
	_ckt_bad=0
	cd "$1" || return 1
	git init -q
	git symbolic-ref HEAD "refs/heads/$HARNESS_TRUNK"
	mkdir todo docs src other
	printf -- '- **Touches:** src/*, docs/*\n' >todo/chore-x.md
	printf -- '- **Touches:** other/*\n' >todo/chore-y.md
	printf '# ADR-07: A\n\n- **Status:** Accepted\n\n## Decision\nOne.\n\n## Consequences\nSome.\n' >docs/adr-07-a.md
	printf 'rules\n' >AGENTS.md
	printf 'a\n' >src/a && printf 'k\n' >other/k
	printf 'one\ntwo\nthree\n' >src/a_test.go
	git add -A
	git -c commit.gpgsign=false commit -q -m 'chore: seed'

	_ckt_branch; printf 'b\n' >src/a; _ckt_expect 'clean pass'
	_ckt_branch; printf 'b\n' >docs/adr-07-b.md; _ckt_expect 'adr-duplicate stop'
	_ckt_branch; printf 'more\n' >>AGENTS.md; _ckt_expect 'protected-path stop'
	_ckt_branch; sed 's/^One\.$/Two./' docs/adr-07-a.md >docs/x && mv docs/x docs/adr-07-a.md; _ckt_expect 'adr-decision stop'
	_ckt_branch; printf 'Later.\n' >>docs/adr-07-a.md; _ckt_expect 'clean pass'
	_ckt_branch; printf '# ADR-DRAFT-%s: B\n' SELFTEST >docs/adr-draft-b.md; _ckt_expect 'adr-draft stop'
	_ckt_branch; git rm -q todo/chore-y.md; _ckt_expect 'todo-deleted stop'
	_ckt_branch; printf 't.Skip("x")\n' >>src/a_test.go; _ckt_expect 'skip-added stop'
	_ckt_branch; printf 'b\n' >src/a; _ckt_expect 'bad-subject stop' 'wip'
	_ckt_branch; rm src/a; ln -s a_test.go src/a; _ckt_expect 'unknown stop'
	_ckt_branch; printf 'one\n' >src/a_test.go; printf 'b\n' >src/a; _ckt_expect 'tests-shrunk pass'
	_ckt_branch; printf 'b\n' >other/b; _ckt_expect 'undeclared-path stop'
	mkdir -p "$(harness_claims_dir)"
	printf 'touches=other/*\n' >"$(harness_claim_file chore-y)"
	_ckt_branch; printf 'b\n' >other/b; _ckt_expect 'undeclared-path-collision stop'

	[ "$_ckt_bad" -eq 0 ]
}

if [ "${1:-}" = --selftest ]; then
	_tmp=$(mktemp -d)
	trap 'rm -rf "$_tmp"' EXIT
	export GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@invalid
	export GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@invalid
	printf 'check selftest\n'
	_ckt_selftest "$_tmp" || die "$EX_FAIL" "check: selftest failed"
	exit "$EX_OK"
fi

[ $# -le 1 ] || die "$EX_USAGE" "usage: harness check [<todo-stem>] | --selftest"
if [ $# -eq 1 ]; then
	_stem=${1#todo/}
	_stem=${_stem%.md}
else
	_b=$(git symbolic-ref -q --short HEAD) || die "$EX_USAGE" "check: detached HEAD — name the todo"
	_stem=$(harness_stem_of_branch "$_b")
fi

_branch=$(harness_todo_branch_from_stem "$_stem") ||
	die "$EX_USAGE" "check: '$_stem' starts with no declared prefix ($HARNESS_PREFIXES)"
git rev-parse -q --verify "refs/heads/$_branch" >/dev/null ||
	die "$EX_FAIL" "check: no branch $_branch"

_touches=$(harness_check_touches "$_stem")
[ -n "$_touches" ] || die "$EX_FAIL" "check: no Touches for $_stem on $HARNESS_TRUNK or in its claim"

harness_check "$_stem" "$_branch" "$_touches" || die "$EX_FAIL" "check: $_branch may not merge"
printf 'clean\n'
