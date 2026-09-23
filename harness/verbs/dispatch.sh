# dispatch — claim a todo and start an agent in its worktree
#
# Stdout is shell, so this leaves you in the worktree with the agent started:
#   eval "$(harness dispatch worker)"
# With HARNESS_AGENT_CMD unset it prints the cd, and the boot prompt on stderr.

_usage="usage: harness dispatch worker [<todo-stem>] [--agent <name>]"
[ $# -gt 0 ] || die "$EX_USAGE" "$_usage"
case $1 in
worker) shift ;;
reviewer | integrator) die "$EX_USAGE" "dispatch: the $1 role does not exist yet" ;;
*) die "$EX_USAGE" "$_usage" ;;
esac

case ${1:-} in
"" | -*) set -- --next "$@" ;;
esac
_wt=$("$HARNESS_HOME/bin/harness" claim "$@") || exit $?
_stem=$(basename -- "$_wt")

_prompt="You are a harness worker in this worktree. Your todo is todo/$_stem.md. \
Read AGENTS.md first, then your todo, then follow both. harness gate --full must \
be green before you finish. Do not merge and do not push: when Done when is \
satisfied, stop and report what you did and how each box is met."

_q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

if [ -z "${HARNESS_AGENT_CMD:-}" ]; then
	printf 'cd %s\n' "$(_q "$_wt")"
	log "dispatch: HARNESS_AGENT_CMD is unset — start an agent in $_wt with:"
	log "$_prompt"
elif [ -t 1 ]; then
	cd "$_wt" || die "$EX_FAIL" "dispatch: cannot cd to $_wt"
	# shellcheck disable=SC2086  # the command may carry its own arguments
	exec $HARNESS_AGENT_CMD "$_prompt"
else
	printf 'cd %s && %s %s\n' "$(_q "$_wt")" "$HARNESS_AGENT_CMD" "$(_q "$_prompt")"
fi
