# integrate — merge the oldest submission, stopping once for a verdict
#
#   harness integrate --next [--wait]         mechanics, then a judgment packet, exit 10
#   harness integrate --continue --verdict pass | --reject "<box>" | --park <code> --detail "<what>"

_mode=
_wait=no
_verdict=
_arg=
_detail=
while [ $# -gt 0 ]; do
	case $1 in
	--next | --continue) _mode=${1#--} ;;
	--wait) _wait=yes ;;
	--verdict | --reject | --park | --detail)
		[ $# -gt 1 ] || die "$EX_USAGE" "integrate: $1 needs a value"
		if [ "$1" = --detail ]; then
			_detail=$2
		else
			[ -z "$_verdict" ] || die "$EX_USAGE" "integrate: exactly one of --verdict, --reject, --park"
			_verdict=${1#--}
			_arg=$2
		fi
		shift
		;;
	*) die "$EX_USAGE" "integrate: unknown argument: $1" ;;
	esac
	shift
done
[ -n "$_mode" ] || die "$EX_USAGE" "usage: harness integrate --next [--wait] | --continue <verdict>"

_trunk_wt=$(harness_trunk_worktree)
[ "$HARNESS_REPO" = "$_trunk_wt" ] ||
	die "$EX_USAGE" "integrate: run it from the $HARNESS_TRUNK checkout (${_trunk_wt:-none exists})"

_pending=$(harness_ig_file integrate/pending)
_green=$(harness_ig_file integrate/green)
_q=$(harness_ig_file submitted)
mkdir -p "$(dirname -- "$_pending")" "$(harness_ig_file tmp)"

while [ "$_mode" = next ] && [ -z "$(harness_ig_oldest)" ]; do
	[ "$_wait" = yes ] || die "$EX_OK" "integrate: nothing submitted"
	sleep "${HARNESS_INTEGRATE_POLL:-10}"
done

harness_lock_wait integrate 10 || die "$EX_FAIL" "integrate: the integrate lock is $(harness_lock_who integrate)"
trap 'harness_lock_release integrate' EXIT
if [ "$_mode" = next ] && [ -f "$_pending" ]; then
	die "$EX_FAIL" "integrate: $(harness_kv_get "$_pending" stem) awaits a verdict — integrate --continue"
fi

if [ "$_mode" = next ]; then
	_stem=$(harness_ig_oldest)
	_branch=$(harness_kv_get "$_q/$_stem" branch)
	harness_ig_trunk_ok
	rm -f "$(harness_ig_file parked/@trunk)"
	_esc=$(harness_kv_get "$_q/$_stem" escalate || :)
	[ -z "$_esc" ] || harness_ig_stop "$_stem" escalated "$_esc"
	[ "$(git rev-parse -q --verify "refs/heads/$_branch" || :)" = "$(harness_kv_get "$_q/$_stem" head)" ] ||
		harness_ig_stop "$_stem" moved "$_branch is not at the commit it was submitted at — resubmit"

	printf 'stem=%s\nbranch=%s\nhead=%s\ntrunk=%s\nphase=check\n' "$_stem" "$_branch" \
		"$(harness_kv_get "$_q/$_stem" head)" "$(git rev-parse HEAD)" >"$_pending"
	_found=$(harness_check "$_stem" "$_branch" "$(harness_check_touches "$_stem")") ||
		harness_ig_stop "$_stem" "${_found%% *}" "$(printf '%s\n' "$_found" | sed 's/^[^ ]* //' | paste -sd ';' -)"
	harness_ig_set check clean

	# Before the merge: a red trunk would otherwise be blamed on this branch.
	if [ "$(cat "$_green" 2>/dev/null || :)" != "$(git rev-parse HEAD)" ]; then
		harness_ig_gate ||
			harness_ig_gate_stop @trunk gate-red-trunk "$HARNESS_TRUNK at $(git rev-parse --short HEAD) is red before any merge"
		git rev-parse HEAD >"$_green"
	fi
	harness_ig_set phase judge
	harness_ig_packet "$_stem" "$_branch"
	exit "$EX_JUDGE"
fi

[ -f "$_pending" ] || die "$EX_USAGE" "integrate: nothing is pending — integrate --next first"
_stem=$(harness_kv_get "$_pending" stem)
_branch=$(harness_kv_get "$_pending" branch)
_pre=$(harness_kv_get "$_pending" trunk)
case $_verdict:$_arg in
reject:?*) harness_ig_park "$_stem" rejected "$_arg" && exit "$EX_OK" ;;
park:?*)
	harness_code_known "$_arg" || die "$EX_USAGE" "integrate: '$_arg' is not a code:$(harness_codes | tr '\n' ' ')"
	[ -n "$_detail" ] || die "$EX_USAGE" "integrate: --park needs --detail \"<what>\""
	harness_ig_park "$_stem" "$_arg" "$_detail" && exit "$EX_OK"
	;;
verdict:pass) ;;
*) die "$EX_USAGE" "integrate: --continue takes --verdict pass, --reject \"<box>\" or --park <code>" ;;
esac
{ [ "$(harness_kv_get "$_pending" phase)" = judge ] && [ "$(harness_kv_get "$_pending" check || :)" = clean ]; } ||
	die "$EX_FAIL" "integrate: pass refused — $_stem has no completed check; --park it or --reject it"

harness_ig_trunk_ok
[ "$(git rev-parse HEAD)" = "$_pre" ] || harness_ig_stop @trunk moved "$HARNESS_TRUNK moved after the packet — integrate --next again"
[ "$(git rev-parse -q --verify "refs/heads/$_branch" || :)" = "$(harness_kv_get "$_pending" head)" ] ||
	harness_ig_stop "$_stem" moved "$_branch moved after the packet — resubmit"

# This script runs from trunk's own tree, which the merge rewrites. check's
# harness/** stop is what keeps the merge from rewriting this file mid-run.
if ! git merge -q --no-ff --no-commit "$_branch" >&2; then
	git merge --abort 2>/dev/null || git reset -q --hard "$_pre"
	harness_ig_stop "$_stem" merge-conflict "$_branch does not merge onto $HARNESS_TRUNK — rebase and resubmit"
fi
if ! harness_ig_gate; then
	git reset -q --hard "$_pre"
	harness_ig_gate_stop "$_stem" gate-red-merge "both sides green, the merge red: a semantic conflict. $_branch is intact"
fi
_msg="$(harness_ig_file tmp)/merge.$$"
harness_ig_message "$_stem" "$_branch" >"$_msg"
if ! git commit -q -F "$_msg"; then
	git reset -q --hard "$_pre"
	harness_ig_stop "$_stem" merge-refused "git commit refused the merge — a hook?"
fi
rm -f "$_msg" "$_pending"
git rev-parse HEAD >"$_green"
printf 'merged %s as %s\n' "$_branch" "$(git rev-parse --short HEAD)"
harness_ig_cleanup "$_stem" "$_branch"
