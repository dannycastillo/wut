# status — one table, a row per todo, then locks and the run set

ai_harness_agents_reap

_tab=$(printf '\t')

# Seconds since an agent started, as "Ns", "Nm" or "NhNm".
_age() {
	_a=$1
	if [ "$_a" -lt 60 ]; then
		printf '%ss\n' "$_a"
	elif [ "$_a" -lt 3600 ]; then
		printf '%sm\n' "$((_a / 60))"
	else
		printf '%sh%sm\n' "$((_a / 3600))" "$(((_a % 3600) / 60))"
	fi
}

# "pid <pid>, <age>" for a live agent record.
_agent_why() {
	printf 'pid %s, %s' "$(ai_harness_kv_get "$1" pid)" "$(_age $(($(date -u '+%s') - $(ai_harness_kv_get "$1" epoch))))"
}

_plan=$(ai_harness_plan)

# Every row worth showing: every open todo, plus anything still claimed even
# if its file already left todo/ on the way to landing. A todo that merged and
# cleared its claim has neither, so it drops out here rather than duplicating
# the run set footer below.
_stems=$(
	{
		for _f in todo/*.md; do
			[ -f "$_f" ] && basename -- "$_f" .md
		done
		ai_harness_claim_stems
	} | awk '!seen[$0]++'
)

_rows=
for _s in $_stems; do
	_f=$(ai_harness_todo_file "$_s")
	_pri=
	[ ! -f "$_f" ] || _pri=$(ai_harness_todo_field "$_f" Priority)
	[ -n "$_pri" ] || _pri=-

	_c=$(ai_harness_claim_file "$_s")
	if [ -f "$_c" ]; then
		_grp=0
		_wnote=
		[ -d "$(ai_harness_kv_get "$_c" worktree)" ] || _wnote='; ! worktree is gone — aih doctor --repair'

		_pk="$(ai_harness_ig_file parked)/$_s"
		_pend=$(ai_harness_ig_file integrate/pending)
		_sub="$(ai_harness_ig_file submitted)/$_s"
		if [ -f "$_pk" ]; then
			_state=parked
			_why="$(ai_harness_kv_get "$_pk" code): $(ai_harness_kv_get "$_pk" detail)$_wnote"
		elif [ -f "$_pend" ] && [ "$(ai_harness_kv_get "$_pend" stem)" = "$_s" ]; then
			_rv=$(ai_harness_agent_file "$_s" reviewer)
			if [ -f "$_rv" ] && ai_harness_agent_alive "$_rv"; then
				_state=reviewer
				_why="$(_agent_why "$_rv")$_wnote"
			else
				_state=pending
				_why="phase $(ai_harness_kv_get "$_pend" phase)"
				[ "$(ai_harness_kv_get "$_pend" phase)" != judge ] ||
					_why="$_why — awaits a verdict: aih dispatch reviewer, or integrate --continue"
				_why="$_why$_wnote"
			fi
		elif [ -f "$_sub" ]; then
			_state=submitted
			_why="awaiting integrate --next$_wnote"
		else
			_w=$(ai_harness_agent_file "$_s" worker)
			if [ ! -f "$_w" ]; then
				_state=claimed
				_why="${_wnote#; }"
			elif ai_harness_agent_alive "$_w"; then
				_state=worker
				_why="$(_agent_why "$_w")$_wnote"
			else
				_state=exited
				_why="! exited $(ai_harness_kv_get "$_w" exit) — inspect its log, then abandon or dispatch by hand$_wnote"
			fi
		fi
	else
		_line=$(printf '%s\n' "$_plan" | awk -F'\t' -v s="$_s" '($1 == "run" || $1 == "hold") && $2 == s { print $1"\t"$3 }')
		_kind=${_line%%"$_tab"*}
		_reason=${_line#*"$_tab"}
		case $_kind in
		run)
			_grp=1
			_state=runnable
			_why=
			;;
		hold)
			_grp=3
			case $_reason in
			"invalid: "*)
				_state=invalid
				_why=${_reason#"invalid: "}
				;;
			"blocked by "*)
				_state=blocked
				_why="by ${_reason#"blocked by "}"
				;;
			"branch "*"exists unclaimed"*)
				_state=stuck
				_why=$_reason
				;;
			*)
				_grp=2
				_state=held
				_why=$_reason
				;;
			esac
			;;
		*)
			_grp=3
			_state=queued
			_why=
			;;
		esac
	fi

	case $_pri in high) _prn=1 ;; medium) _prn=2 ;; low) _prn=3 ;; *) _prn=4 ;; esac
	_rows="$_rows$_grp$_tab$_prn$_tab$_s$_tab$_pri$_tab$_state$_tab$_why
"
done

# One awk pass: size TODO/PRI/STATE from the data, then print with WHY
# truncated to keep every line at or under 100 columns.
printf '%s' "$_rows" | sort -k1,1n -k2,2n -k3,3 | cut -f3- | awk -F'\t' -v max=100 '
{
	stem[NR] = $1; pri[NR] = $2; state[NR] = $3; why[NR] = $4
	if (length($1) > w1) w1 = length($1)
	if (length($2) > w2) w2 = length($2)
	if (length($3) > w3) w3 = length($3)
	n = NR
}
END {
	if (w1 < 4) w1 = 4
	if (w2 < 3) w2 = 3
	if (w3 < 5) w3 = 5
	whymax = max - w1 - w2 - w3 - 6
	if (whymax < 4) whymax = 4
	printf "%-*s  %-*s  %-*s  %s\n", w1, "TODO", w2, "PRI", w3, "STATE", "WHY"
	for (i = 1; i <= n; i++) {
		w = why[i]
		# "…" is 3 bytes: reserve all 3 so a byte-counting `wc -L` agrees with a
		# display-column count that this codebase cannot assume is locale-aware.
		if (length(w) > whymax) w = substr(w, 1, whymax - 3) "…"
		printf "%-*s  %-*s  %-*s  %s\n", w1, stem[i], w2, pri[i], w3, state[i], w
	}
}
'

for _l in "$(ai_harness_state_dir)"/lock/*; do
	[ -d "$_l" ] || continue
	_name=$(basename -- "$_l")
	printf 'lock %s %s\n' "$_name" "$(ai_harness_lock_who "$_name")"
	ai_harness_lock_is_stale "$_name" && printf '  ! stale — inspect, then: aih unlock %s --force\n' "$_name"
done

ai_harness_run_status
