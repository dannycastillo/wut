# The loop's mechanics: one tick, re-derived from files and git each time.
# Nothing here remembers anything between calls, so a killed loop and a
# restarted one make the same decisions from the same state.

harness_run_file() { printf '%s/run/%s\n' "$(harness_state_dir)" "$1"; }

# The requested stems, one per line; an empty file means every todo. It is the
# one thing a restart would otherwise lose, so it lives on disk.
harness_run_set() { cat "$(harness_run_file set)" 2>/dev/null || :; }
harness_run_in_set() {
	_rs_set=$(harness_run_set)
	[ -z "$_rs_set" ] || printf '%s\n' "$_rs_set" | grep -qxF -- "$1"
}

# Every process under $1, deepest last, from one ps snapshot. Taken before any
# kill: a dead parent's children reparent to init and fall out of the tree.
harness_proc_tree() {
	_pt_ps=$(ps -A -o pid=,ppid=)
	_pt_out=$1
	_pt_q=$1
	while [ -n "$_pt_q" ]; do
		_pt_next=
		for _pt_p in $_pt_q; do
			_pt_next="$_pt_next $(printf '%s\n' "$_pt_ps" | awk -v p="$_pt_p" '$2 == p { print $1 }' | tr '\n' ' ')"
		done
		_pt_q=$(printf '%s' "$_pt_next" | tr -s ' ' | sed 's/^ //; s/ $//')
		_pt_out="$_pt_out $_pt_q"
	done
	printf '%s\n' "$_pt_out" | tr -s ' '
}

# Kill an agent's whole tree and record $2 as its exit. The wrapper dies first
# and the exit file is written at once: the wrapper is what would otherwise
# write it, and a reaper running meanwhile would record a dead pid as lost.
harness_agent_kill() {
	_ak_pid=$(harness_kv_get "$1" pid)
	_ak_tree=$(harness_proc_tree "$_ak_pid")
	kill -TERM "$_ak_pid" 2>/dev/null || :
	printf '%s\n' "$2" >"$1.exit"
	# shellcheck disable=SC2086  # a list of pids
	kill -TERM $_ak_tree 2>/dev/null || :
	sleep 1
	for _ak_p in $_ak_tree; do kill -KILL "$_ak_p" 2>/dev/null || :; done
}

harness_run_timeouts() {
	_rt_now=$(date -u '+%s')
	for _rt_r in $(harness_agent_records); do
		harness_agent_alive "$_rt_r" || continue
		[ $((_rt_now - $(harness_kv_get "$_rt_r" epoch))) -gt "${HARNESS_AGENT_TIMEOUT:-3600}" ] || continue
		harness_agent_kill "$_rt_r" timeout
		log "run: $(harness_kv_get "$_rt_r" stem) $(harness_kv_get "$_rt_r" role) ran past HARNESS_AGENT_TIMEOUT and was killed"
	done
	harness_agents_reap
}

# The next runnable stem in the set that has never been dispatched, or nothing.
harness_run_next() {
	for _rn_s in $(harness_plan | awk -F'\t' '$1 == "run" { print $2 }'); do
		harness_run_in_set "$_rn_s" || continue
		[ ! -f "$(harness_agent_file "$_rn_s" worker)" ] || continue
		printf '%s\n' "$_rn_s"
		return 0
	done
	return 1
}

harness_run_dispatch() {
	[ ! -f "$(harness_state_dir)/PAUSED" ] || return 0
	while [ "$(harness_claim_count)" -lt "$HARNESS_MAX_WORKERS" ]; do
		_rd_s=$(harness_run_next) || return 0
		"$HARNESS_HOME/bin/harness" dispatch worker "$_rd_s" --agent "${HARNESS_AGENT:-loop}" --detach >/dev/null || {
			log "run: dispatch of $_rd_s failed; not retried this tick"
			return 0
		}
	done
}

# Prints a stop reason and fails when the loop must exit; otherwise advances
# the queue by one step at most.
harness_run_judge() {
	_rj_p=$(harness_ig_file integrate/pending)
	if [ -f "$_rj_p" ]; then
		_rj_stem=$(harness_kv_get "$_rj_p" stem)
		_rj_r=$(harness_agent_file "$_rj_stem" reviewer)
		if [ -f "$_rj_r" ]; then
			harness_agent_alive "$_rj_r" && return 0
			# Exited with the verdict still pending: it is never respawned. A
			# human may dispatch reviewer again, or --park it.
			[ -f "$_rj_r.lost" ] && return 0
			: >"$_rj_r.lost"
			harness_event "$_rj_stem" reviewer lost "exited $(harness_kv_get "$_rj_r" exit) with the judgment pending"
			log "run: reviewer-lost $_rj_stem — harness dispatch reviewer --detach, or integrate --continue --park"
			return 0
		fi
		[ "$(harness_kv_get "$_rj_p" phase)" = judge ] || {
			printf 'integrate stopped mid-%s on %s; the pending file needs a human\n' "$(harness_kv_get "$_rj_p" phase)" "$_rj_stem"
			return 1
		}
		"$HARNESS_HOME/bin/harness" dispatch reviewer --detach >/dev/null || log "run: could not dispatch a reviewer for $_rj_stem"
		return 0
	fi
	[ -n "$(harness_ig_oldest)" ] || return 0
	_rj_rc=0
	"$HARNESS_HOME/bin/harness" integrate --next >/dev/null 2>&1 || _rj_rc=$?
	case $_rj_rc in
	"$EX_JUDGE") "$HARNESS_HOME/bin/harness" dispatch reviewer --detach >/dev/null || log "run: could not dispatch a reviewer" ;;
	"$EX_OK") ;;
	*)
		_rj_t=$(harness_ig_file parked/@trunk)
		[ ! -f "$_rj_t" ] || { printf 'park @trunk %s: %s\n' "$(harness_kv_get "$_rj_t" code)" "$(harness_kv_get "$_rj_t" detail)" && return 1; }
		;;
	esac
}

# A claim the loop should still wait on: its worker has not been dispatched by
# this harness, or is alive, or has submitted. One that exited without
# submitting is a human's, and waiting on it would never end.
harness_run_waiting() {
	for _rw_s in $(harness_claim_stems); do
		_rw_r=$(harness_agent_file "$_rw_s" worker)
		[ -f "$_rw_r" ] || return 0
		harness_agent_alive "$_rw_r" && return 0
		[ ! -f "$(harness_ig_file submitted)/$_rw_s" ] || return 0
	done
	return 1
}

# The pending stem whose reviewer was lost, if that is the case. Nothing will
# move it but a human, so the loop stops on it rather than waiting.
harness_run_lost() {
	_rl_p=$(harness_ig_file integrate/pending)
	[ -f "$_rl_p" ] || return 1
	_rl_s=$(harness_kv_get "$_rl_p" stem)
	[ -f "$(harness_agent_file "$_rl_s" reviewer).lost" ] && printf '%s\n' "$_rl_s"
}

harness_run_idle() {
	[ ! -f "$(harness_ig_file integrate/pending)" ] || return 1
	[ -z "$(harness_ig_oldest)" ] || return 1
	! harness_run_waiting || return 1
	[ -f "$(harness_state_dir)/PAUSED" ] || ! harness_run_next >/dev/null || return 1
}

# What happened since $1 (an ISO time), and what in the set is still held.
harness_run_report() {
	printf 'run: since %s\n' "$1"
	awk -v t="$1" '$1 >= t && ($4 == "merged" || $4 == "parked" || $4 == "lost" || ($4 == "exited" && $5 != "0")) {
		d = ""; for (i = 5; i <= NF; i++) d = d (i > 5 ? " " : "") $i
		printf "  %-10s %-34s %s\n", $4, $2, d }' "$(harness_state_dir)/events" 2>/dev/null || :
	for _rr_s in $(harness_run_set); do
		[ -f "$(harness_todo_file "$_rr_s")" ] || continue
		[ -f "$(harness_claim_file "$_rr_s")" ] && continue
		_rr_why=$(harness_plan | awk -F'\t' -v s="$_rr_s" '$1 == "hold" && $2 == s { print $3 }')
		[ -z "$_rr_why" ] || printf '  %-10s %-34s %s\n' held "$_rr_s" "$_rr_why"
	done
}
