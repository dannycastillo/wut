# status — what is in flight right now

_any=no
ai_harness_agents_reap

_stems=$(ai_harness_claim_stems)
if [ -n "$_stems" ]; then
	_any=yes
	_slots=$(ai_harness_claim_count)
	printf 'claims (%s of %s slots, %s holding paths only)\n' \
		"$_slots" "$AI_HARNESS_MAX_WORKERS" "$(($(printf '%s\n' "$_stems" | grep -c .) - _slots))"
	for _s in $_stems; do
		_c=$(ai_harness_claim_file "$_s")
		_wt=$(ai_harness_kv_get "$_c" worktree)
		_note=
		# git is the authority; the file annotates it. A claim whose worktree is
		# gone is drift, and doctor --repair is what reconciles it.
		[ -d "$_wt" ] || _note='  ! worktree is gone — aih doctor --repair'
		printf '  %-30s %-26s %-10s%s\n' \
			"$_s" "$(ai_harness_kv_get "$_c" branch)" "$(ai_harness_kv_get "$_c" agent)" "$_note"
		printf '  %-30s touches: %s\n' '' "$(ai_harness_kv_get "$_c" touches)"
	done
fi

_hdr=no
for _r in $(ai_harness_agent_records); do
	[ "$_hdr" = yes ] || { printf 'agents\n' && _hdr=yes && _any=yes; }
	_st=$(ai_harness_agent_state "$_r")
	_note=
	# An exit that left neither a submission nor a verdict is a worker that
	# never submitted, or a reviewer that never answered. Nothing retries either.
	_as=$(ai_harness_kv_get "$_r" stem)
	case $_st in exited*)
		[ ! -f "$(ai_harness_claim_file "$_as")" ] || [ -f "$(ai_harness_ig_file submitted)/$_as" ] ||
			_note='  ! exited without finishing — inspect its log, then abandon or dispatch by hand' ;;
	esac
	printf '  %-30s %-9s pid %-7s %-14s%s\n' "$(ai_harness_kv_get "$_r" stem)" "$(ai_harness_kv_get "$_r" role)" \
		"$(ai_harness_kv_get "$_r" pid)" "$_st" "$_note"
done

_p=$(ai_harness_ig_file integrate/pending)
if [ -f "$_p" ]; then
	_any=yes
	printf 'pending  %s, phase %s' "$(ai_harness_kv_get "$_p" stem)" "$(ai_harness_kv_get "$_p" phase)"
	[ "$(ai_harness_kv_get "$_p" phase)" != judge ] || printf ' — awaits a verdict: aih dispatch reviewer, or integrate --continue'
	printf '\n'
fi

_hdr=no
for _pk in "$(ai_harness_ig_file parked)"/*; do
	[ -f "$_pk" ] || continue
	[ "$_hdr" = yes ] || { printf 'parked\n' && _hdr=yes && _any=yes; }
	printf '  %-30s %s: %s\n' "$(basename -- "$_pk")" "$(ai_harness_kv_get "$_pk" code)" "$(ai_harness_kv_get "$_pk" detail)"
done

for _l in "$(ai_harness_state_dir)"/lock/*; do
	[ -d "$_l" ] || continue
	_any=yes
	_name=$(basename -- "$_l")
	printf 'lock %s %s\n' "$_name" "$(ai_harness_lock_who "$_name")"
	ai_harness_lock_is_stale "$_name" && printf '  ! stale — inspect, then: aih unlock %s --force\n' "$_name"
done

[ "$_any" = yes ] || log "nothing in flight"

ai_harness_run_status
