# abandon — give a claim back, freeing its todo and its paths

_stem=
_keep=no
_force=no
while [ $# -gt 0 ]; do
	case $1 in
	--keep-branch) _keep=yes ;;
	--force) _force=yes ;;
	-*) die "$EX_USAGE" "abandon: unknown option: $1" ;;
	*) _stem=$1 ;;
	esac
	shift
done
[ -n "$_stem" ] || die "$EX_USAGE" "usage: harness abandon <todo-stem> [--keep-branch] [--force]"
_stem=${_stem#todo/}
_stem=${_stem%.md}

_c=$(harness_claim_file "$_stem")
[ -f "$_c" ] || die "$EX_FAIL" "abandon: $_stem is not claimed"
_branch=$(harness_kv_get "$_c" branch)
_wt=$(harness_kv_get "$_c" worktree)

if [ -d "$_wt" ]; then
	# Plain remove refuses when the worktree is dirty, which is exactly when
	# abandoning silently would throw away work someone still wants.
	if [ "$_force" = yes ]; then
		git worktree remove --force "$_wt" || die "$EX_FAIL" "abandon: could not remove $_wt"
	else
		git worktree remove "$_wt" ||
			die "$EX_FAIL" "abandon: $_wt has uncommitted work — inspect it, then --force"
	fi
fi
git worktree prune

if [ "$_keep" = no ]; then
	if ! git branch -d "$_branch" >/dev/null 2>&1; then
		if [ "$_force" = yes ]; then
			git branch -D "$_branch" >/dev/null 2>&1 ||
				warn "abandon: could not delete $_branch"
		else
			warn "abandon: $_branch holds unmerged commits — kept. --force deletes it"
		fi
	fi
fi

rm -f "$_c"
harness_agents_clear "$_stem"
harness_event "$_stem" - abandoned "$_branch"
log "abandon: $_stem released"
