# status — what is in flight right now

_any=no
harness_agents_reap

_stems=$(harness_claim_stems)
if [ -n "$_stems" ]; then
	_any=yes
	printf 'claims (%s of %s)\n' "$(harness_claim_count)" "$HARNESS_MAX_WORKERS"
	for _s in $_stems; do
		_c=$(harness_claim_file "$_s")
		_wt=$(harness_kv_get "$_c" worktree)
		_note=
		# git is the authority; the file annotates it. A claim whose worktree is
		# gone is drift, and doctor --repair is what reconciles it.
		[ -d "$_wt" ] || _note='  ! worktree is gone — harness doctor --repair'
		printf '  %-30s %-26s %-10s%s\n' \
			"$_s" "$(harness_kv_get "$_c" branch)" "$(harness_kv_get "$_c" agent)" "$_note"
		printf '  %-30s touches: %s\n' '' "$(harness_kv_get "$_c" touches)"
	done
fi

_hdr=no
for _r in $(harness_agent_records); do
	[ "$_hdr" = yes ] || { printf 'agents\n' && _hdr=yes && _any=yes; }
	_st=$(harness_agent_state "$_r")
	_note=
	# An exit that left neither a submission nor a verdict is a worker that
	# never submitted, or a reviewer that never answered. Nothing retries either.
	_as=$(harness_kv_get "$_r" stem)
	case $_st in exited*)
		[ ! -f "$(harness_claim_file "$_as")" ] || [ -f "$(harness_ig_file submitted)/$_as" ] ||
			_note='  ! exited without finishing — inspect its log, then abandon or dispatch by hand' ;;
	esac
	printf '  %-30s %-9s pid %-7s %-14s%s\n' "$(harness_kv_get "$_r" stem)" "$(harness_kv_get "$_r" role)" \
		"$(harness_kv_get "$_r" pid)" "$_st" "$_note"
done

_p=$(harness_ig_file integrate/pending)
if [ -f "$_p" ]; then
	_any=yes
	printf 'pending  %s, phase %s' "$(harness_kv_get "$_p" stem)" "$(harness_kv_get "$_p" phase)"
	[ "$(harness_kv_get "$_p" phase)" != judge ] || printf ' — awaits a verdict: harness dispatch reviewer, or integrate --continue'
	printf '\n'
fi

_hdr=no
for _pk in "$(harness_ig_file parked)"/*; do
	[ -f "$_pk" ] || continue
	[ "$_hdr" = yes ] || { printf 'parked\n' && _hdr=yes && _any=yes; }
	printf '  %-30s %s: %s\n' "$(basename -- "$_pk")" "$(harness_kv_get "$_pk" code)" "$(harness_kv_get "$_pk" detail)"
done

for _l in "$(harness_state_dir)"/lock/*; do
	[ -d "$_l" ] || continue
	_any=yes
	_name=$(basename -- "$_l")
	printf 'lock %s %s\n' "$_name" "$(harness_lock_who "$_name")"
	harness_lock_is_stale "$_name" && printf '  ! stale — inspect, then: harness unlock %s --force\n' "$_name"
done

[ "$_any" = yes ] || log "nothing in flight"
