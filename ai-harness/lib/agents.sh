# Agents the harness started, and the events every verb leaves behind.
#
# A record under agents/ is the at-most-once guard: while agents/<stem>.<role>
# exists, nothing dispatches that stem again. It is removed exactly where the
# claim is, and nowhere else. Logs under log/ are never removed.

ai_harness_agents_dir() { printf '%s/agents\n' "$(ai_harness_state_dir)"; }
ai_harness_agent_file() { printf '%s/%s.%s\n' "$(ai_harness_agents_dir)" "$1" "$2"; }
ai_harness_agent_log() { printf '%s/log/%s.%s.log\n' "$(ai_harness_state_dir)" "$1" "$2"; }

# One line in one printf: O_APPEND keeps a short write whole, so two verbs
# logging at once cannot interleave.
ai_harness_event() {
	_ev_f="$(ai_harness_state_dir)/events"
	mkdir -p "$(dirname -- "$_ev_f")"
	printf '%s %s %s %s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" "${2:--}" "$3" \
		"$(printf '%s' "$4" | tr '\n' ' ')" >>"$_ev_f"
}

# Start $AI_HARNESS_AGENT_CMD detached in the current directory, with $3 as its
# one argument, as role $1 for stem $2. Prints the pid.
#
# What each piece defends against, because none of it is optional:
#   nohup        the terminal hanging up. macOS has no setsid.
#   set -m       a TERM to the parent's process group: under job control the
#                job gets a group of its own. Without it, killing the session
#                that ran dispatch kills every agent it started.
#   </dev/null   a job in its own group reading the terminal stops on SIGTTIN.
#   the wrapper  a detached process's exit status is unreadable from any other
#                shell, so the wrapper writes it to a file itself.
#   PATH         the prompt says aih; the agent must find this tree's copy
#                whether or not the machine has a launcher.
ai_harness_agent_spawn() {
	_sp_rec=$(ai_harness_agent_file "$2" "$1")
	_sp_log=$(ai_harness_agent_log "$2" "$1")
	[ ! -f "$_sp_rec" ] || return 1
	mkdir -p "$(dirname -- "$_sp_rec")" "$(dirname -- "$_sp_log")"
	rm -f "$_sp_rec.exit"
	# shellcheck disable=SC2086,SC2016  # the command may carry its own arguments; the wrapper's shell expands the quotes
	_sp_pid=$(set -m; PATH="$AI_HARNESS_HOME/bin:$PATH" nohup sh -c 'l=$1; shift; "$@" >"$l" 2>&1; printf "%s\n" "$?" >"$0.exit"' \
		"$_sp_rec" "$_sp_log" $AI_HARNESS_AGENT_CMD "$3" </dev/null >/dev/null 2>&1 & printf '%s\n' "$!")
	{
		printf 'role=%s\nstem=%s\npid=%s\n' "$1" "$2" "$_sp_pid"
		printf 'cmd=%s\ncwd=%s\n' "$AI_HARNESS_AGENT_CMD" "$PWD"
		printf 'started=%s\nepoch=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(date -u '+%s')"
		printf 'log=%s\n' "$_sp_log"
	} >"$_sp_rec"
	ai_harness_event "$2" "$1" dispatched "pid $_sp_pid"
	printf '%s\n' "$_sp_pid"
}

# Every record path, one per line, exit files excluded.
ai_harness_agent_records() {
	for _ar_r in "$(ai_harness_agents_dir)"/*; do
		[ -f "$_ar_r" ] || continue
		case $_ar_r in *.exit) continue ;; esac
		printf '%s\n' "$_ar_r"
	done
}

# Fold each finished agent's exit into its record, once, with an event. A pid
# that no longer answers and left no exit file was killed outright or outlived
# a reboot; it is recorded as lost rather than guessed at.
ai_harness_agents_reap() {
	# A reviewer's own exit lands after the merge it made cleared its record.
	for _rp_x in "$(ai_harness_agents_dir)"/*.exit; do
		[ -f "$_rp_x" ] && [ ! -f "${_rp_x%.exit}" ] && rm -f "$_rp_x"
	done
	for _rp_r in $(ai_harness_agent_records); do
		[ -z "$(ai_harness_kv_get "$_rp_r" exit)" ] || continue
		if [ -f "$_rp_r.exit" ]; then
			_rp_c=$(cat "$_rp_r.exit")
		elif kill -0 "$(ai_harness_kv_get "$_rp_r" pid)" 2>/dev/null; then
			continue
		elif [ -f "$_rp_r.exit" ]; then
			_rp_c=$(cat "$_rp_r.exit")
		else
			_rp_c=lost
		fi
		printf 'exit=%s\nended=%s\n' "$_rp_c" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >>"$_rp_r"
		ai_harness_event "$(ai_harness_kv_get "$_rp_r" stem)" "$(ai_harness_kv_get "$_rp_r" role)" exited "$_rp_c"
	done
}

ai_harness_agent_alive() { [ -f "$1" ] && [ -z "$(ai_harness_kv_get "$1" exit)" ]; }

# "alive <age>s" or "exited <code>", after a reap.
ai_harness_agent_state() {
	_as_x=$(ai_harness_kv_get "$1" exit)
	if [ -n "$_as_x" ]; then
		printf 'exited %s\n' "$_as_x"
	else
		printf 'alive %ss\n' "$(( $(date -u '+%s') - $(ai_harness_kv_get "$1" epoch) ))"
	fi
}

ai_harness_agents_clear() { rm -f "$(ai_harness_agents_dir)/$1".*; }
