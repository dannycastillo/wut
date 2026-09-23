# dispatch — claim a todo and start an agent in its worktree
#
#   harness dispatch worker [<todo-stem>] [--agent <name>] [--detach]
#   harness dispatch reviewer [--detach]
#
# Attached, stdout is shell, so this leaves you where the agent runs:
#   eval "$(harness dispatch worker)"
# With HARNESS_AGENT_CMD unset it prints the cd, and the boot prompt on stderr.
# --detach starts the agent under nohup, records it in agents/, prints its pid.

_usage="usage: harness dispatch worker [<todo-stem>] [--agent <name>] [--detach] | reviewer [--detach]"
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
[ "$_detach" = no ] || [ -n "${HARNESS_AGENT_CMD:-}" ] ||
	die "$EX_USAGE" "dispatch: --detach needs HARNESS_AGENT_CMD set in .harness.conf"

case $_role in
worker)
	case ${1:-} in
	"" | -*) set -- --next "$@" ;;
	esac
	_wt=$("$HARNESS_HOME/bin/harness" claim "$@") || exit $?
	_stem=$(basename -- "$_wt")
	_prompt="You are a harness worker in this worktree. Your todo is todo/$_stem.md. \
Read AGENTS.md first, then your todo, then follow both. harness gate --full must \
be green before you finish. Do not merge and do not push: when Done when is \
satisfied, end with harness submit, then report what you did and how each box is met."
	;;
reviewer)
	[ $# -eq 0 ] || die "$EX_USAGE" "$_usage"
	_p=$(harness_ig_file integrate/pending)
	[ "$(harness_kv_get "$_p" phase || :)" = judge ] ||
		die "$EX_FAIL" "dispatch: nothing awaits a verdict — integrate --next first"
	_wt=$(harness_trunk_worktree)
	[ "$HARNESS_REPO" = "$_wt" ] ||
		die "$EX_USAGE" "dispatch: run it from the $HARNESS_TRUNK checkout (${_wt:-none exists})"
	_stem=$(harness_kv_get "$_p" stem)
	_prompt="You are a harness reviewer in this $HARNESS_TRUNK checkout. harness integrate --next \
has stopped for your judgment on $_stem; the packet is at $(harness_ig_file integrate/packet). \
Read AGENTS.md first, then harness/roles/reviewer.md, then the packet. Verify every box \
as the packet says, then end with exactly one harness integrate --continue command."
	;;
*) die "$EX_USAGE" "$_usage" ;;
esac

_q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

if [ "$_detach" = yes ]; then
	cd "$_wt" || die "$EX_FAIL" "dispatch: cannot cd to $_wt"
	_pid=$(harness_agent_spawn "$_role" "$_stem" "$_prompt") ||
		die "$EX_FAIL" "dispatch: $_stem already has a $_role record — harness status"
	log "dispatch: $_role $_stem pid $_pid, log $(harness_agent_log "$_stem" "$_role")"
	printf '%s\n' "$_pid"
elif [ -z "${HARNESS_AGENT_CMD:-}" ]; then
	printf 'cd %s\n' "$(_q "$_wt")"
	log "dispatch: HARNESS_AGENT_CMD is unset — start a $_role in $_wt with:"
	log "$_prompt"
elif [ -t 1 ]; then
	cd "$_wt" || die "$EX_FAIL" "dispatch: cannot cd to $_wt"
	# shellcheck disable=SC2086  # the command may carry its own arguments
	exec $HARNESS_AGENT_CMD "$_prompt"
else
	printf 'cd %s && %s %s\n' "$(_q "$_wt")" "$HARNESS_AGENT_CMD" "$(_q "$_prompt")"
fi
