# The loop's mechanics: one tick, re-derived from files and git each time.
# Nothing here remembers anything between calls, so a killed loop and a
# restarted one make the same decisions from the same state.

ai_harness_run_file() { printf '%s/run/%s\n' "$(ai_harness_state_dir)" "$1"; }

# The requested stems, one per line; an empty file means every todo. It is the
# one thing a restart would otherwise lose, so it lives on disk.
ai_harness_run_set() { cat "$(ai_harness_run_file set)" 2>/dev/null || :; }

# The plan for the set alone: a todo nobody asked for must not hold one in it.
ai_harness_run_plan() {
	_rp_set=$(ai_harness_run_set)
	# shellcheck disable=SC2086  # a list of stems
	ai_harness_plan $_rp_set
}

# Every process under $1, deepest last, from one ps snapshot. Taken before any
# kill: a dead parent's children reparent to init and fall out of the tree.
ai_harness_proc_tree() {
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
ai_harness_agent_kill() {
	_ak_pid=$(ai_harness_kv_get "$1" pid)
	_ak_tree=$(ai_harness_proc_tree "$_ak_pid")
	kill -TERM "$_ak_pid" 2>/dev/null || :
	printf '%s\n' "$2" >"$1.exit"
	# shellcheck disable=SC2086  # a list of pids
	kill -TERM $_ak_tree 2>/dev/null || :
	sleep 1
	for _ak_p in $_ak_tree; do kill -KILL "$_ak_p" 2>/dev/null || :; done
}

ai_harness_run_timeouts() {
	_rt_now=$(date -u '+%s')
	for _rt_r in $(ai_harness_agent_records); do
		ai_harness_agent_alive "$_rt_r" || continue
		[ $((_rt_now - $(ai_harness_kv_get "$_rt_r" epoch))) -gt "${AI_HARNESS_AGENT_TIMEOUT:-3600}" ] || continue
		ai_harness_agent_kill "$_rt_r" timeout
		log "run: $(ai_harness_kv_get "$_rt_r" stem) $(ai_harness_kv_get "$_rt_r" role) ran past AI_HARNESS_AGENT_TIMEOUT and was killed"
	done
	ai_harness_agents_reap
}

# The next runnable stem in the set that has never been dispatched, or nothing.
ai_harness_run_next() {
	for _rn_s in $(ai_harness_run_plan | awk -F'\t' '$1 == "run" { print $2 }'); do
		[ ! -f "$(ai_harness_agent_file "$_rn_s" worker)" ] || continue
		printf '%s\n' "$_rn_s"
		return 0
	done
	return 1
}

# Prints a stop reason and fails once a stem's dispatch has failed twice; the
# error is on stderr both times. Counts live under run/ and a new loop resets them.
ai_harness_run_dispatch() {
	[ ! -f "$(ai_harness_state_dir)/PAUSED" ] || return 0
	while [ "$(ai_harness_claim_count)" -lt "$AI_HARNESS_MAX_WORKERS" ]; do
		_rd_s=$(ai_harness_run_next) || return 0
		"$AI_HARNESS_HOME/bin/aih" dispatch worker "$_rd_s" --agent "${AI_HARNESS_AGENT:-loop}" --detach >/dev/null && continue
		_rd_f=$(ai_harness_run_file "failed.$_rd_s")
		_rd_n=$(($(cat "$_rd_f" 2>/dev/null || echo 0) + 1))
		printf '%s\n' "$_rd_n" >"$_rd_f"
		[ "$_rd_n" -lt 2 ] || { printf 'dispatch of %s failed twice; its error is above\n' "$_rd_s" && return 1; }
		log "run: dispatch of $_rd_s failed; retried next tick"
		return 0
	done
}

# Prints a stop reason and fails when the loop must exit; otherwise advances
# the queue by one step at most.
ai_harness_run_judge() {
	if ai_harness_lock_acquire integrate; then
		ai_harness_ig_landed_sweep
		ai_harness_lock_release integrate
	fi
	_rj_p=$(ai_harness_ig_file integrate/pending)
	if [ -f "$_rj_p" ]; then
		_rj_stem=$(ai_harness_kv_get "$_rj_p" stem)
		_rj_r=$(ai_harness_agent_file "$_rj_stem" reviewer)
		if [ -f "$_rj_r" ]; then
			ai_harness_agent_alive "$_rj_r" && return 0
			# Exited with the verdict still pending: it is never respawned. A
			# human may dispatch reviewer again, or --park it.
			[ -f "$_rj_r.lost" ] && return 0
			: >"$_rj_r.lost"
			ai_harness_event "$_rj_stem" reviewer lost "exited $(ai_harness_kv_get "$_rj_r" exit) with the judgment pending"
			log "run: reviewer-lost $_rj_stem — aih dispatch reviewer --detach, or integrate --continue --park"
			return 0
		fi
		[ "$(ai_harness_kv_get "$_rj_p" phase)" = judge ] || {
			printf 'integrate stopped mid-%s on %s; the pending file needs a human\n' "$(ai_harness_kv_get "$_rj_p" phase)" "$_rj_stem"
			return 1
		}
		"$AI_HARNESS_HOME/bin/aih" dispatch reviewer --detach >/dev/null || log "run: could not dispatch a reviewer for $_rj_stem"
		return 0
	fi
	[ -n "$(ai_harness_ig_oldest)" ] || return 0
	_rj_rc=0
	"$AI_HARNESS_HOME/bin/aih" integrate --next >/dev/null 2>&1 || _rj_rc=$?
	case $_rj_rc in
	"$EX_JUDGE") "$AI_HARNESS_HOME/bin/aih" dispatch reviewer --detach >/dev/null || log "run: could not dispatch a reviewer" ;;
	"$EX_OK") ;;
	*)
		_rj_t=$(ai_harness_ig_file parked/@trunk)
		[ ! -f "$_rj_t" ] || { printf 'park @trunk %s: %s\n' "$(ai_harness_kv_get "$_rj_t" code)" "$(ai_harness_kv_get "$_rj_t" detail)" && return 1; }
		;;
	esac
}

# A claim the loop should still wait on: its worker has not been dispatched by
# this harness, or is alive, or has submitted. One that exited without
# submitting is a human's, and waiting on it would never end.
ai_harness_run_waiting() {
	for _rw_s in $(ai_harness_claim_stems); do
		_rw_r=$(ai_harness_agent_file "$_rw_s" worker)
		[ -f "$_rw_r" ] || return 0
		ai_harness_agent_alive "$_rw_r" && return 0
		[ ! -f "$(ai_harness_ig_file submitted)/$_rw_s" ] || return 0
	done
	return 1
}

# Claims that will never merge on their own: a worker this harness dispatched
# exited without submitting, or a park. Named again at idle, so that exit 0
# cannot mean either.
ai_harness_run_unfinished() {
	_ru_out=
	for _ru_s in $(ai_harness_claim_stems); do
		_ru_pk=$(ai_harness_ig_file parked)/$_ru_s
		if [ -f "$_ru_pk" ]; then
			_ru_out="$_ru_out; $_ru_s parked $(ai_harness_kv_get "$_ru_pk" code)"
			continue
		fi
		_ru_r=$(ai_harness_agent_file "$_ru_s" worker)
		[ -f "$_ru_r" ] || continue
		ai_harness_agent_alive "$_ru_r" && continue
		[ ! -f "$(ai_harness_ig_file submitted)/$_ru_s" ] || continue
		_ru_out="$_ru_out; $_ru_s worker exited $(ai_harness_kv_get "$_ru_r" exit) without submitting"
	done
	[ -n "$_ru_out" ] || return 1
	printf 'unfinished: %s — aih status\n' "${_ru_out#; }"
}

# The pending stem whose reviewer was lost, if that is the case. Nothing will
# move it but a human, so the loop stops on it rather than waiting.
ai_harness_run_lost() {
	_rl_p=$(ai_harness_ig_file integrate/pending)
	[ -f "$_rl_p" ] || return 1
	_rl_s=$(ai_harness_kv_get "$_rl_p" stem)
	[ -f "$(ai_harness_agent_file "$_rl_s" reviewer).lost" ] && printf '%s\n' "$_rl_s"
}

ai_harness_run_idle() {
	[ ! -f "$(ai_harness_ig_file integrate/pending)" ] || return 1
	[ -z "$(ai_harness_ig_oldest)" ] || return 1
	! ai_harness_run_waiting || return 1
	[ -f "$(ai_harness_state_dir)/PAUSED" ] || ! ai_harness_run_next >/dev/null || return 1
}

# HH:MM:SS of an ISO time.
ai_harness_run_clock() {
	_rc_t=${1#*T}
	printf '%s\n' "${_rc_t%Z}"
}

# What became of one stem in the set, as "<state> <detail>", given the plan.
ai_harness_run_state() {
	_rs_c=$(ai_harness_claim_file "$1")
	_rs_w=$(ai_harness_agent_file "$1" worker)
	if [ -f "$_rs_c" ]; then
		if [ -f "$(ai_harness_ig_file parked)/$1" ]; then
			printf 'parked %s\n' "$(ai_harness_kv_get "$(ai_harness_ig_file parked)/$1" code)"
		elif [ -f "$(ai_harness_ig_file submitted)/$1" ]; then
			printf 'submitted\n'
		elif [ ! -f "$_rs_w" ]; then
			printf 'claimed\n'
		elif ai_harness_agent_alive "$_rs_w"; then
			printf 'running\n'
		else
			printf 'exited %s\n' "$(ai_harness_kv_get "$_rs_w" exit)"
		fi
	elif [ -f "$(ai_harness_todo_file "$1")" ]; then
		_rs_why=$(printf '%s\n' "$2" | awk -F'\t' -v s="$1" '$1 == "hold" && $2 == s { print $3 }')
		if [ -n "$_rs_why" ]; then printf 'held %s\n' "$_rs_why"; else printf 'queued\n'; fi
	else
		_rs_e=$(awk -v s="$1" '$2 == s && ($4 == "merged" || $4 == "landed") { e = $4 " " $5 } END { if (e) print e }' \
			"$(ai_harness_state_dir)/events" 2>/dev/null)
		printf '%s\n' "${_rs_e:-gone}"
	fi
}

# The last run's set, one line per todo with its state, under the loop's start
# and end. Nothing when no set is on disk. The loop's final report is this
# same function, so status and the report cannot disagree.
ai_harness_run_status() {
	[ -f "$(ai_harness_run_file set)" ] || return 0
	_ru_ev="$(ai_harness_state_dir)/events"
	_ru_last=$(awk '$2 == "@run" && $4 == "started" { n = NR; t = $1 } END { if (n) print n, t }' "$_ru_ev" 2>/dev/null)
	_ru_n=${_ru_last%% *}
	_ru_end=$(awk -v n="${_ru_n:-0}" 'NR > n && $2 == "@run" && ($4 == "stopped" || $4 == "idle") {
		d = ""; for (i = 5; i <= NF; i++) d = d (i > 5 ? " " : "") $i; e = $4 " " $1 " " d }
		END { if (e) print e }' "$_ru_ev" 2>/dev/null)
	_ru_plan=$(ai_harness_run_plan)
	_ru_set=$(ai_harness_run_set)
	if [ -n "$_ru_set" ]; then
		_ru_count=$(printf '%s\n' "$_ru_set" | grep -c .)
	else
		_ru_count='every todo'
		_ru_set=$({
			printf '%s\n' "$_ru_plan" | cut -f2
			awk -v n="${_ru_n:-0}" 'NR > n && ($4 == "merged" || $4 == "landed") { print $2 }' "$_ru_ev" 2>/dev/null
		} | awk 'NF && !seen[$0]++')
	fi

	printf 'run set (%s)' "$_ru_count"
	[ -z "$_ru_last" ] || printf ', started %s' "$(ai_harness_run_clock "${_ru_last#* }")"
	if [ -n "$_ru_end" ]; then
		_ru_kind=${_ru_end%% *}
		_ru_rest=${_ru_end#* }
		_ru_when=${_ru_rest%% *}
		_ru_why=${_ru_rest#"$_ru_when"}
		_ru_why=${_ru_why# }
		# The loop's own exit codes, read back from the only place it recorded
		# them (verbs/run.sh). A stop by aih stop killed it, so it had none.
		case $_ru_kind:$_ru_why in
		idle:*) _ru_rc=" rc $EX_OK:" ;;
		stopped:'paused and drained') _ru_rc=" rc $EX_PAUSED:" ;;
		stopped:'by aih stop') _ru_rc= ;;
		*) _ru_rc=" rc $EX_FAIL:" ;;
		esac
		printf ', %s %s%s %s' "$_ru_kind" "$(ai_harness_run_clock "$_ru_when")" "$_ru_rc" "$_ru_why"
	elif ai_harness_lock_held run && [ "$(sed -n 's/^pid=//p' "$(ai_harness_lock_path run)/holder" 2>/dev/null)" != "$$" ]; then
		printf ', running'
	elif [ -n "$_ru_last" ]; then
		printf ', no stop recorded'
	fi
	printf '\n'
	for _ru_s in $_ru_set; do
		_ru_st=$(ai_harness_run_state "$_ru_s" "$_ru_plan")
		_ru_w=${_ru_st%% *}
		_ru_d=${_ru_st#"$_ru_w"}
		_ru_d=${_ru_d# }
		if [ -n "$_ru_d" ]; then
			printf '  %-34s %-10s %s\n' "$_ru_s" "$_ru_w" "$_ru_d"
		else
			printf '  %-34s %s\n' "$_ru_s" "$_ru_w"
		fi
	done
}

# The loop's final report. $1, the loop's start time, is what the events
# already hold; the header names it from there.
ai_harness_run_report() { ai_harness_run_status; }
