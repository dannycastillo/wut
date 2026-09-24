# integrate — merge the oldest submission, stopping once for a verdict
#
#   aih integrate --next [--wait]         mechanics, then a judgment packet, exit 10
#   aih integrate --continue --verdict pass | --reject "<box>" | --park <code> --detail "<what>"

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
[ -n "$_mode" ] || die "$EX_USAGE" "usage: aih integrate --next [--wait] | --continue <verdict>"

_trunk_wt=$(ai_harness_trunk_worktree)
[ "$AI_HARNESS_REPO" = "$_trunk_wt" ] ||
	die "$EX_USAGE" "integrate: run it from the $AI_HARNESS_TRUNK checkout (${_trunk_wt:-none exists})"

_pending=$(ai_harness_ig_file integrate/pending)
_green=$(ai_harness_ig_file integrate/green)
_q=$(ai_harness_ig_file submitted)
mkdir -p "$(dirname -- "$_pending")" "$(ai_harness_ig_file tmp)"

# Before the queue is consulted: a hand-merged claim has nothing queued, and
# this is the verb a human runs after merging.
if [ "$_mode" = next ] && ai_harness_lock_acquire integrate; then
	ai_harness_ig_landed_sweep
	ai_harness_lock_release integrate
fi
while [ "$_mode" = next ] && [ -z "$(ai_harness_ig_oldest)" ]; do
	[ "$_wait" = yes ] || die "$EX_OK" "integrate: nothing submitted"
	sleep "${AI_HARNESS_INTEGRATE_POLL:-10}"
done

ai_harness_lock_wait integrate 10 || die "$EX_FAIL" "integrate: the integrate lock is $(ai_harness_lock_who integrate)"
trap 'ai_harness_lock_release integrate' EXIT
if [ "$_mode" = next ] && [ -f "$_pending" ]; then
	die "$EX_FAIL" "integrate: $(ai_harness_kv_get "$_pending" stem) awaits a verdict — integrate --continue"
fi

if [ "$_mode" = next ]; then
	ai_harness_ig_landed_sweep
	_stem=$(ai_harness_ig_oldest)
	[ -n "$_stem" ] || die "$EX_OK" "integrate: nothing submitted"
	_branch=$(ai_harness_kv_get "$_q/$_stem" branch)
	ai_harness_ig_trunk_ok
	rm -f "$(ai_harness_ig_file parked/@trunk)"
	_esc=$(ai_harness_kv_get "$_q/$_stem" escalate || :)
	[ -z "$_esc" ] || ai_harness_ig_stop "$_stem" escalated "$_esc"
	[ "$(git rev-parse -q --verify "refs/heads/$_branch" || :)" = "$(ai_harness_kv_get "$_q/$_stem" head)" ] ||
		ai_harness_ig_stop "$_stem" moved "$_branch is not at the commit it was submitted at — resubmit"

	printf 'stem=%s\nbranch=%s\nhead=%s\ntrunk=%s\nphase=check\n' "$_stem" "$_branch" \
		"$(ai_harness_kv_get "$_q/$_stem" head)" "$(git rev-parse HEAD)" >"$_pending"
	_found=$(ai_harness_check "$_stem" "$_branch" "$(ai_harness_check_touches "$_stem")") ||
		ai_harness_ig_stop "$_stem" "${_found%% *}" "$(printf '%s\n' "$_found" | sed 's/^[^ ]* //' | paste -sd ';' -)"
	ai_harness_ig_set check clean

	# Before the merge: a red trunk would otherwise be blamed on this branch.
	if [ "$(cat "$_green" 2>/dev/null || :)" != "$(git rev-parse HEAD)" ]; then
		ai_harness_ig_gate ||
			ai_harness_ig_gate_stop @trunk gate-red-trunk "$AI_HARNESS_TRUNK at $(git rev-parse --short HEAD) is red before any merge"
		git rev-parse HEAD >"$_green"
	fi
	ai_harness_ig_set phase judge
	# To a file as well: a reviewer started later reads it from there.
	ai_harness_ig_packet "$_stem" "$_branch" | tee "$(ai_harness_ig_file integrate/packet)"
	exit "$EX_JUDGE"
fi

[ -f "$_pending" ] || die "$EX_USAGE" "integrate: nothing is pending — integrate --next first"
_stem=$(ai_harness_kv_get "$_pending" stem)
_branch=$(ai_harness_kv_get "$_pending" branch)
_pre=$(ai_harness_kv_get "$_pending" trunk)
case $_verdict:$_arg in
reject:?*) ai_harness_ig_park "$_stem" rejected "$_arg" && exit "$EX_OK" ;;
park:?*)
	ai_harness_code_known "$_arg" || die "$EX_USAGE" "integrate: '$_arg' is not a code:$(ai_harness_codes | tr '\n' ' ')"
	[ -n "$_detail" ] || die "$EX_USAGE" "integrate: --park needs --detail \"<what>\""
	ai_harness_ig_park "$_stem" "$_arg" "$_detail" && exit "$EX_OK"
	;;
verdict:pass) ai_harness_ig_set verdict pass ;;
*) die "$EX_USAGE" "integrate: --continue takes --verdict pass, --reject \"<box>\" or --park <code>" ;;
esac
{ [ "$(ai_harness_kv_get "$_pending" phase)" = judge ] && [ "$(ai_harness_kv_get "$_pending" check || :)" = clean ]; } ||
	die "$EX_FAIL" "integrate: pass refused — $_stem has no completed check; --park it or --reject it"

ai_harness_ig_trunk_ok
[ "$(git rev-parse HEAD)" = "$_pre" ] || ai_harness_ig_stop @trunk moved "$AI_HARNESS_TRUNK moved after the packet — integrate --next again"
[ "$(git rev-parse -q --verify "refs/heads/$_branch" || :)" = "$(ai_harness_kv_get "$_pending" head)" ] ||
	ai_harness_ig_stop "$_stem" moved "$_branch moved after the packet — resubmit"

# This script runs from trunk's own tree, which the merge rewrites. check's
# ai-harness/** stop is what keeps the merge from rewriting this file mid-run.
if ! git merge -q --no-ff --no-commit "$_branch" >&2; then
	git merge --abort 2>/dev/null || git reset -q --hard "$_pre"
	ai_harness_ig_stop "$_stem" merge-conflict "$_branch does not merge onto $AI_HARNESS_TRUNK — rebase and resubmit"
fi
if ! ai_harness_ig_gate; then
	git reset -q --hard "$_pre"
	ai_harness_ig_gate_stop "$_stem" gate-red-merge "both sides green, the merge red: a semantic conflict. $_branch is intact"
fi
_msg="$(ai_harness_ig_file tmp)/merge.$$"
ai_harness_ig_message "$_stem" "$_branch" >"$_msg"
if ! git commit -q -F "$_msg"; then
	git reset -q --hard "$_pre"
	ai_harness_ig_stop "$_stem" merge-refused "git commit refused the merge — a hook?"
fi
rm -f "$_msg" "$_pending" "$(ai_harness_ig_file integrate/packet)"
git rev-parse HEAD >"$_green"
ai_harness_event "$_stem" - merged "$(git rev-parse --short HEAD)"
printf 'merged %s as %s\n' "$_branch" "$(git rev-parse --short HEAD)"
ai_harness_ig_cleanup "$_stem" "$_branch"
