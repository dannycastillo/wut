# dispatch — claim a todo and start an agent in its worktree
#
#   aih dispatch worker [<todo-stem>] [--agent <name>] [--detach]
#   aih dispatch reviewer [--detach]
#
# Attached, stdout is shell, so this leaves you where the agent runs:
#   eval "$(aih dispatch worker)"
# With AI_HARNESS_AGENT_CMD unset it prints the cd, and the boot prompt on stderr.
# --detach starts the agent under nohup, records it in agents/, prints its pid.

_usage="usage: aih dispatch worker [<todo-stem>] [--agent <name>] [--detach] | reviewer [--detach]"
[ $# -gt 0 ] || die "$EX_USAGE" "$_usage"
_role=$1
shift
_detach=no
_n=$#
while [ "$_n" -gt 0 ]; do
	case $1 in
	--detach) _detach=yes ;;
	*) set -- "$@" "$1" ;;
	esac
	shift
	_n=$((_n - 1))
done
[ "$_detach" = no ] || [ -n "${AI_HARNESS_AGENT_CMD:-}" ] ||
	die "$EX_USAGE" "dispatch: --detach needs AI_HARNESS_AGENT_CMD set in .ai-harness.conf"

case $_role in
worker)
	case ${1:-} in
	"" | -*) set -- --next "$@" ;;
	esac
	_wt=$("$AI_HARNESS_HOME/bin/aih" claim "$@") || exit $?
	_stem=$(basename -- "$_wt")
	_prompt="You are an AI Harness worker in this worktree. Your todo is todo/$_stem.md. \
Read AGENTS.md first, then your todo, then follow both. aih gate --full must \
be green before you finish. Do not merge and do not push: when Done when is \
satisfied, end with aih submit, then report what you did and how each box is met."
	;;
reviewer)
	[ $# -eq 0 ] || die "$EX_USAGE" "$_usage"
	_p=$(ai_harness_ig_file integrate/pending)
	[ "$(ai_harness_kv_get "$_p" phase || :)" = judge ] ||
		die "$EX_FAIL" "dispatch: nothing awaits a verdict — integrate --next first"
	_wt=$(ai_harness_trunk_worktree)
	[ "$AI_HARNESS_REPO" = "$_wt" ] ||
		die "$EX_USAGE" "dispatch: run it from the $AI_HARNESS_TRUNK checkout (${_wt:-none exists})"
	_stem=$(ai_harness_kv_get "$_p" stem)
	_prompt="You are an AI Harness reviewer in this $AI_HARNESS_TRUNK checkout. aih integrate --next \
has stopped for your judgment on $_stem; the packet is at $(ai_harness_ig_file integrate/packet). \
Read AGENTS.md first, then ai-harness/roles/reviewer.md, then the packet. Verify every box \
as the packet says, then end with exactly one aih integrate --continue command."
	;;
*) die "$EX_USAGE" "$_usage" ;;
esac

_q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

if [ "$_detach" = yes ]; then
	cd "$_wt" || die "$EX_FAIL" "dispatch: cannot cd to $_wt"
	_pid=$(ai_harness_agent_spawn "$_role" "$_stem" "$_prompt") ||
		die "$EX_FAIL" "dispatch: $_stem already has a $_role record — aih status"
	log "dispatch: $_role $_stem pid $_pid, log $(ai_harness_agent_log "$_stem" "$_role")"
	printf '%s\n' "$_pid"
elif [ -z "${AI_HARNESS_AGENT_CMD:-}" ]; then
	printf 'cd %s\n' "$(_q "$_wt")"
	log "dispatch: AI_HARNESS_AGENT_CMD is unset — start a $_role in $_wt with:"
	log "$_prompt"
elif [ -t 1 ]; then
	cd "$_wt" || die "$EX_FAIL" "dispatch: cannot cd to $_wt"
	# shellcheck disable=SC2086  # the command may carry its own arguments
	exec $AI_HARNESS_AGENT_CMD "$_prompt"
else
	printf 'cd %s && %s %s\n' "$(_q "$_wt")" "$AI_HARNESS_AGENT_CMD" "$(_q "$_prompt")"
fi
