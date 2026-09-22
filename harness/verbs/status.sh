# status — what is in flight right now

_any=no

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

for _l in "$(harness_state_dir)"/lock/*; do
	[ -d "$_l" ] || continue
	_any=yes
	_name=$(basename -- "$_l")
	printf 'lock %s %s\n' "$_name" "$(harness_lock_who "$_name")"
	harness_lock_is_stale "$_name" && printf '  ! stale — inspect, then: harness unlock %s --force\n' "$_name"
done

[ "$_any" = yes ] || log "nothing in flight"
