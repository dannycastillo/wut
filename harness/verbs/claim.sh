# claim — take one todo, on its own branch, in its own worktree
#
# Stdout is the worktree path and nothing else, so this works:
#   cd "$(harness claim fix-something)"

_stem=
_agent=${HARNESS_AGENT:-${USER:-worker}}
_dry=no
_next=no
_scratch=no
while [ $# -gt 0 ]; do
	case $1 in
	--agent)
		[ $# -gt 1 ] || die "$EX_USAGE" "claim: --agent needs a name"
		_agent=$2 && shift
		;;
	--dry-run) _dry=yes ;;
	--next) _next=yes ;;
	--scratch) _scratch=yes ;;
	-*) die "$EX_USAGE" "claim: unknown option: $1" ;;
	*)
		[ -z "$_stem" ] || die "$EX_USAGE" "claim: one todo at a time"
		_stem=$1
		;;
	esac
	shift
done
case $_stem$_next$_scratch in
?*nono | yesno | noyes) ;;
*) die "$EX_USAGE" "usage: harness claim <todo-stem> | --next | --scratch [--agent <name>] [--dry-run]" ;;
esac

# A scratch tree is detached, which is what keeps doctor --repair from mistaking
# it for a claim. It reserves nothing, so no lock, pause or barrier applies.
if [ "$_scratch" = yes ]; then
	_wt="$(harness_worktree_root)/scratch-$(printf '%s' "$_agent" | tr -c 'A-Za-z0-9_-' '-')"
	git worktree add --detach "$_wt" "$HARNESS_TRUNK" >/dev/null 2>&1 ||
		die "$EX_FAIL" "claim: could not create $_wt — it may already exist"
	log "claim: scratch worktree at $HARNESS_TRUNK, reserving nothing"
	printf '%s\n' "$_wt"
	exit "$EX_OK"
fi

# Held from before --next picks until the claim file exists, so the Touches
# check below sees every claim that could beat this one to a path.
if [ "$_dry" = no ]; then
	harness_lock_wait claim 10 ||
		die "$EX_FAIL" "claim: the claim lock is $(harness_lock_who claim)"
fi
_bail() {
	[ "$_dry" = yes ] || harness_lock_release claim
	die "$@"
}
_st=$(harness_state_dir)
[ ! -f "$_st/PAUSED" ] || _bail "$EX_PAUSED" "claim: paused — $(cat "$_st/PAUSED")"

if [ "$_next" = yes ]; then
	_stem=$(harness_plan | awk -F'\t' '$1 == "run" { print $2; exit }')
	[ -n "$_stem" ] || _bail "$EX_FAIL" "claim: nothing is runnable — harness plan says why"
fi

# Accept todo/foo.md as readily as foo.
_stem=${_stem#todo/}
_stem=${_stem%.md}

harness_todo_validate "$_stem" || _bail "$EX_FAIL" "claim: $_stem did not validate"

_todo=$(harness_todo_file "$_stem")
_branch=$(harness_todo_branch_from_stem "$_stem")
_touches=$(harness_todo_field "$_todo" Touches)

_barrier=$(cat "$_st/BARRIER" 2>/dev/null) || _barrier=
[ -z "$_barrier" ] || [ "$_barrier" = "$_stem" ] ||
	_bail "$EX_PAUSED" "claim: barrier — draining for $_barrier, see $_st/BARRIER"

# The worktree is cut from trunk, so a todo that exists only on the current
# branch would leave the worker with no todo to read.
git cat-file -e "$HARNESS_TRUNK:$_todo" 2>/dev/null ||
	_bail "$EX_FAIL" "claim: $_todo is not on $HARNESS_TRUNK yet, so the worktree would not have it"

_open=$(harness_open_blockers "$_todo")
[ -z "$_open" ] || _bail "$EX_FAIL" "claim: $_stem is blocked by open todos: $_open"
[ ! -f "$(harness_claim_file "$_stem")" ] ||
	_bail "$EX_FAIL" "claim: $_stem is already claimed — harness status"

# Different todos, so different branches: git's ref lock cannot see this race.
_tc=$(harness_touches_norm "$_touches")
for _s in $(harness_claim_stems); do
	_w=$(harness_touches_meet "$_tc" "$(harness_touches_norm "$(harness_kv_get "$(harness_claim_file "$_s")" touches)")") &&
		_bail "$EX_FAIL" "claim: $_stem's Touches meet active claim $_s on $_w"
done

_n=$(harness_claim_count)
[ "$_n" -lt "$HARNESS_MAX_WORKERS" ] ||
	_bail "$EX_FAIL" "claim: $_n claims already active, HARNESS_MAX_WORKERS is $HARNESS_MAX_WORKERS"

_wt="$(harness_worktree_root)/$_stem"

if [ "$_dry" = yes ]; then
	printf 'claim: would claim %s\n  branch    %s\n  worktree  %s\n  touches   %s\n' "$_stem" "$_branch" "$_wt" "$_touches" >&2
	exit "$EX_OK"
fi

# This is the claim. Branch creation takes git's ref lock, so of several racers
# exactly one creates the branch and the rest fail here; the file below only
# annotates what git already decided.
git worktree add -b "$_branch" "$_wt" "$HARNESS_TRUNK" >/dev/null 2>&1 ||
	_bail "$EX_FAIL" "claim: $_branch already exists, so $_stem is taken (or the worktree path is)"

mkdir -p "$(harness_claims_dir)"
printf 'todo=%s\nbranch=%s\nworktree=%s\ntouches=%s\nagent=%s\nclaimed=%s\nbase=%s\n' \
	"$_todo" "$_branch" "$_wt" "$_touches" "$_agent" \
	"$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(git rev-parse --short "$HARNESS_TRUNK")" \
	>"$(harness_claim_file "$_stem")"

[ "$_barrier" != "$_stem" ] || rm -f "$_st/BARRIER"
harness_lock_release claim

printf 'claim: %s on %s\n  touches  %s\n' "$_stem" "$_branch" "$_touches" >&2
printf '%s\n' "$_wt"
