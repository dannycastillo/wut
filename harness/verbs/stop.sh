# stop — kill the loop and every agent it started; claims and trees stay
#
#   harness stop [--agents]      --agents leaves a running loop alone

[ $# -le 1 ] || die "$EX_USAGE" 'usage: harness stop [--agents]'
_loop=yes
[ "${1:-}" != --agents ] || _loop=no
[ $# -eq 0 ] || [ "$_loop" = no ] || die "$EX_USAGE" "stop: unknown option: $1"

# The loop first: its reaper would otherwise record the agents killed below
# as lost before this verb can record them as stopped.
if [ "$_loop" = yes ] && harness_lock_held run; then
	_pid=$(sed -n 's/^pid=//p' "$(harness_lock_path run)/holder" 2>/dev/null)
	if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
		kill -TERM "$_pid" 2>/dev/null || :
		sleep 1
		kill -KILL "$_pid" 2>/dev/null || :
		log "stop: killed the loop, pid $_pid"
	fi
	# Killed by this verb, not stolen: the holder is known dead.
	harness_lock_release run
	harness_event @run - stopped "by harness stop"
fi

_n=0
for _r in $(harness_agent_records); do
	harness_agent_alive "$_r" || continue
	harness_agent_kill "$_r" stopped
	log "stop: killed $(harness_kv_get "$_r" role) $(harness_kv_get "$_r" stem) pid $(harness_kv_get "$_r" pid)"
	_n=$((_n + 1))
done
harness_agents_reap
log "stop: $_n agent(s) killed; claims and worktrees are untouched"
