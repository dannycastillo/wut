# stop — kill the loop and every agent it started; claims and trees stay
#
#   aih stop [--agents]      --agents leaves a running loop alone

[ $# -le 1 ] || die "$EX_USAGE" 'usage: aih stop [--agents]'
_loop=yes
[ "${1:-}" != --agents ] || _loop=no
[ $# -eq 0 ] || [ "$_loop" = no ] || die "$EX_USAGE" "stop: unknown option: $1"

# The loop first: its reaper would otherwise record the agents killed below
# as lost before this verb can record them as stopped.
if [ "$_loop" = yes ] && ai_harness_lock_held run; then
	_pid=$(sed -n 's/^pid=//p' "$(ai_harness_lock_path run)/holder" 2>/dev/null)
	if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
		kill -TERM "$_pid" 2>/dev/null || :
		sleep 1
		kill -KILL "$_pid" 2>/dev/null || :
		log "stop: killed the loop, pid $_pid"
	fi
	# Killed by this verb, not stolen: the holder is known dead.
	ai_harness_lock_release run
	ai_harness_event @run - stopped "by aih stop"
fi

_n=0
for _r in $(ai_harness_agent_records); do
	ai_harness_agent_alive "$_r" || continue
	ai_harness_agent_kill "$_r" stopped
	log "stop: killed $(ai_harness_kv_get "$_r" role) $(ai_harness_kv_get "$_r" stem) pid $(ai_harness_kv_get "$_r" pid)"
	_n=$((_n + 1))
done
ai_harness_agents_reap
log "stop: $_n agent(s) killed; claims and worktrees are untouched"
