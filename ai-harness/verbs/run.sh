# run — work a set of todos unattended: dispatch, judge, merge, until idle
#
#   aih run [<todo-stem>...] [--all] [--detach] [--once]
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
		ai_harness_todo_validate "$_s" >/dev/null 2>&1 || die "$EX_USAGE" "run: no such todo: $_s"
		_stems="$_stems$_s
"
		;;
	esac
	shift
done

_trunk_wt=$(ai_harness_trunk_worktree)
[ "$AI_HARNESS_REPO" = "$_trunk_wt" ] ||
	die "$EX_USAGE" "run: run it from the $AI_HARNESS_TRUNK checkout (${_trunk_wt:-none exists})"
[ -n "${AI_HARNESS_AGENT_CMD:-}" ] || die "$EX_USAGE" "run: AI_HARNESS_AGENT_CMD is unset in .ai-harness.conf"
! ai_harness_lock_held run || die "$EX_FAIL" "run: a loop is already running — $(ai_harness_lock_who run)"

mkdir -p "$(dirname -- "$(ai_harness_run_file set)")"
if [ "$_all" = yes ]; then
	: >"$(ai_harness_run_file set)"
elif [ -n "$_stems" ]; then
	printf '%s' "$_stems" >"$(ai_harness_run_file set)"
fi

if [ "$_detach" = yes ]; then
	_log="$(ai_harness_state_dir)/log/run.log"
	mkdir -p "$(dirname -- "$_log")"
	_args=
	[ "$_once" = no ] || _args=--once
	# shellcheck disable=SC2086  # _args is a flag or empty
	_pid=$(set -m; nohup "$AI_HARNESS_HOME/bin/aih" run $_args </dev/null >>"$_log" 2>&1 & printf '%s\n' "$!")
	log "run: loop pid $_pid, log $_log"
	printf '%s\n' "$_pid"
	exit "$EX_OK"
fi

ai_harness_lock_acquire run || die "$EX_FAIL" "run: a loop is already running — $(ai_harness_lock_who run)"
trap 'ai_harness_lock_release run' EXIT
_since=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
_set=$(ai_harness_run_set | tr '\n' ' ')
ai_harness_event @run - started "${_set:-every todo}"
log "run: working ${_set:-every todo}"

_rc=$EX_OK
while :; do
	ai_harness_agents_reap
	ai_harness_run_timeouts
	ai_harness_run_dispatch
	if _stop=$(ai_harness_run_judge); then :; else
		log "run: $_stop"
		ai_harness_event @run - stopped "$_stop"
		_rc=$EX_FAIL
		break
	fi
	[ "$_once" = no ] || break
	if _lost=$(ai_harness_run_lost); then
		_stop="reviewer-lost $_lost: aih dispatch reviewer --detach, or integrate --continue --park"
		log "run: $_stop"
		ai_harness_event @run - stopped "$_stop"
		_rc=$EX_FAIL
		break
	fi
	if ai_harness_run_idle; then
		if [ -f "$(ai_harness_state_dir)/PAUSED" ]; then
			ai_harness_event @run - stopped "paused and drained"
			_rc=$EX_PAUSED
		else
			ai_harness_event @run - idle "nothing runnable, nothing in flight"
		fi
		break
	fi
	sleep "${AI_HARNESS_RUN_POLL:-10}"
done
ai_harness_run_report "$_since" >&2
exit "$_rc"
