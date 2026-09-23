# run — work a set of todos unattended: dispatch, judge, merge, until idle
#
#   harness run [<todo-stem>...] [--all] [--detach] [--once]
#
# Stems given are remembered; a bare run reuses the last set, and --all clears
# it. --detach starts the loop under nohup and prints its pid. --once runs a
# single tick. Exit: 0 idle, 1 a stop for a human, 3 paused and drained.

_detach=no
_once=no
_all=no
_stems=
while [ $# -gt 0 ]; do
	case $1 in
	--detach) _detach=yes ;;
	--once) _once=yes ;;
	--all) _all=yes ;;
	-*) die "$EX_USAGE" "run: unknown option: $1" ;;
	*)
		_s=${1#todo/}
		_s=${_s%.md}
		harness_todo_validate "$_s" >/dev/null 2>&1 || die "$EX_USAGE" "run: no such todo: $_s"
		_stems="$_stems$_s
"
		;;
	esac
	shift
done

_trunk_wt=$(harness_trunk_worktree)
[ "$HARNESS_REPO" = "$_trunk_wt" ] ||
	die "$EX_USAGE" "run: run it from the $HARNESS_TRUNK checkout (${_trunk_wt:-none exists})"
[ -n "${HARNESS_AGENT_CMD:-}" ] || die "$EX_USAGE" "run: HARNESS_AGENT_CMD is unset in .harness.conf"
! harness_lock_held run || die "$EX_FAIL" "run: a loop is already running — $(harness_lock_who run)"

mkdir -p "$(dirname -- "$(harness_run_file set)")"
if [ "$_all" = yes ]; then
	: >"$(harness_run_file set)"
elif [ -n "$_stems" ]; then
	printf '%s' "$_stems" >"$(harness_run_file set)"
fi

if [ "$_detach" = yes ]; then
	_log="$(harness_state_dir)/log/run.log"
	mkdir -p "$(dirname -- "$_log")"
	_args=
	[ "$_once" = no ] || _args=--once
	# shellcheck disable=SC2086  # _args is a flag or empty
	_pid=$(set -m; nohup "$HARNESS_HOME/bin/harness" run $_args </dev/null >>"$_log" 2>&1 & printf '%s\n' "$!")
	log "run: loop pid $_pid, log $_log"
	printf '%s\n' "$_pid"
	exit "$EX_OK"
fi

harness_lock_acquire run || die "$EX_FAIL" "run: a loop is already running — $(harness_lock_who run)"
trap 'harness_lock_release run' EXIT
_since=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
_set=$(harness_run_set | tr '\n' ' ')
harness_event @run - started "${_set:-every todo}"
log "run: working ${_set:-every todo}"

_rc=$EX_OK
while :; do
	harness_agents_reap
	harness_run_timeouts
	harness_run_dispatch
	if _stop=$(harness_run_judge); then :; else
		log "run: $_stop"
		harness_event @run - stopped "$_stop"
		_rc=$EX_FAIL
		break
	fi
	[ "$_once" = no ] || break
	if _lost=$(harness_run_lost); then
		_stop="reviewer-lost $_lost: harness dispatch reviewer --detach, or integrate --continue --park"
		log "run: $_stop"
		harness_event @run - stopped "$_stop"
		_rc=$EX_FAIL
		break
	fi
	if harness_run_idle; then
		if [ -f "$(harness_state_dir)/PAUSED" ]; then
			harness_event @run - stopped "paused and drained"
			_rc=$EX_PAUSED
		else
			harness_event @run - idle "nothing runnable, nothing in flight"
		fi
		break
	fi
	sleep "${HARNESS_RUN_POLL:-10}"
done
harness_run_report "$_since" >&2
exit "$_rc"
