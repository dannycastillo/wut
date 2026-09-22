# claim — take one todo, on its own branch, in its own worktree
#
# Stdout is the worktree path and nothing else, so this works:
#   cd "$(harness claim fix-something)"

_stem=
_agent=${HARNESS_AGENT:-${USER:-worker}}
_dry=no
while [ $# -gt 0 ]; do
	case $1 in
	--agent)
		shift
		[ $# -gt 0 ] || die "$EX_USAGE" "claim: --agent needs a name"
		_agent=$1
		;;
	--dry-run) _dry=yes ;;
	-*) die "$EX_USAGE" "claim: unknown option: $1" ;;
	*)
		[ -z "$_stem" ] || die "$EX_USAGE" "claim: one todo at a time"
		_stem=$1
		;;
	esac
	shift
done
[ -n "$_stem" ] || die "$EX_USAGE" "usage: harness claim <todo-stem> [--agent <name>]"

# Accept todo/foo.md as readily as foo.
_stem=${_stem#todo/}
_stem=${_stem%.md}

harness_todo_validate "$_stem" || die "$EX_FAIL" "claim: $_stem did not validate"

_todo=$(harness_todo_file "$_stem")
_branch=$(harness_todo_branch_from_stem "$_stem")
_touches=$(harness_todo_field "$_todo" Touches)
_blocked=$(harness_todo_field "$_todo" "Blocked by")

# The worktree is cut from trunk, so a todo that exists only on the current
# branch would leave the worker with no todo to read.
git cat-file -e "$HARNESS_TRUNK:$_todo" 2>/dev/null ||
	die "$EX_FAIL" "claim: $_todo is not on $HARNESS_TRUNK yet, so the worktree would not have it"

# Not the full blocked-by graph, just the direct edge: an open blocker is a
# file that still exists, because a todo is deleted by the merge that finishes it.
case $_blocked in
"" | "—" | "-") ;;
*)
	_open=
	for _b in $(printf '%s' "$_blocked" | tr ',' ' '); do
		_b=${_b#todo/}
		_b=${_b%.md}
		[ -f "todo/$_b.md" ] && _open="$_open $_b"
	done
	[ -z "$_open" ] || die "$EX_FAIL" "claim: $_stem is blocked by open todos:$_open"
	;;
esac

_wt="$(harness_worktree_root)/$_stem"

if [ "$_dry" = yes ]; then
	log "claim: would claim $_stem"
	log "  branch    $_branch"
	log "  worktree  $_wt"
	log "  touches   $_touches"
	exit "$EX_OK"
fi

harness_lock_wait claim 10 ||
	die "$EX_FAIL" "claim: the claim lock is $(harness_lock_who claim)"

_bail() {
	harness_lock_release claim
	die "$EX_FAIL" "$@"
}

[ ! -f "$(harness_claim_file "$_stem")" ] ||
	_bail "claim: $_stem is already claimed — harness status"

_n=$(harness_claim_count)
[ "$_n" -lt "$HARNESS_MAX_WORKERS" ] ||
	_bail "claim: $_n claims already active, HARNESS_MAX_WORKERS is $HARNESS_MAX_WORKERS"

mkdir -p "$(harness_worktree_root)" || _bail "claim: cannot create $(harness_worktree_root)"

# This is the claim. Branch creation takes git's ref lock, so of several racers
# exactly one creates the branch and the rest fail here; the file below only
# annotates what git already decided.
git worktree add -b "$_branch" "$_wt" "$HARNESS_TRUNK" >/dev/null 2>&1 ||
	_bail "claim: $_branch already exists, so $_stem is taken (or the worktree path is)"

mkdir -p "$(harness_claims_dir)"
{
	printf 'todo=%s\n' "$_todo"
	printf 'branch=%s\n' "$_branch"
	printf 'worktree=%s\n' "$_wt"
	printf 'touches=%s\n' "$_touches"
	printf 'agent=%s\n' "$_agent"
	printf 'claimed=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	printf 'base=%s\n' "$(git rev-parse --short "$HARNESS_TRUNK")"
} >"$(harness_claim_file "$_stem")"

harness_lock_release claim

log "claim: $_stem on $_branch"
log "  touches  $_touches"
printf '%s\n' "$_wt"
