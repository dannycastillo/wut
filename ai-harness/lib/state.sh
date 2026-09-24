# Reading and writing the coordination state.
#
# State files are key=value, one per line, and are PARSED rather than sourced.
# Agents write these, and a sourced state file is somewhere to inject code.

ai_harness_kv_get() {
	[ -f "$1" ] || return 1
	sed -n "s/^$2=//p" "$1" | head -1
}

ai_harness_claims_dir() { printf '%s/claims\n' "$(ai_harness_state_dir)"; }
ai_harness_claim_file() { printf '%s/%s\n' "$(ai_harness_claims_dir)" "$1"; }

# Every claim stem, one per line. A for loop over the glob rather than ls in a
# pipe: a pipe would put the caller's counter in a subshell.
ai_harness_claim_stems() {
	for _c in "$(ai_harness_claims_dir)"/*; do
		[ -f "$_c" ] || continue
		basename -- "$_c"
	done
}

# Claims holding a worker slot: those with no worker record, or a worker still
# alive. A worker that exited holds its paths — plan reads the claim, not this
# — but runs nothing, so it does not count against AI_HARNESS_MAX_WORKERS.
# Reaps first: an exit is only in the record once reaped, and claim never
# reaps on its own.
ai_harness_claim_count() {
	ai_harness_agents_reap
	_n=0
	for _c in $(ai_harness_claim_stems); do
		_r=$(ai_harness_agent_file "$_c" worker)
		[ ! -f "$_r" ] || ai_harness_agent_alive "$_r" || continue
		_n=$((_n + 1))
	done
	printf '%s\n' "$_n"
}

# Rebuild claims/ from git, which is the authority. Drops claims whose worktree
# is gone and reconstructs claims for worktrees that have none — the window
# between `worktree add` succeeding and the claim file being written.
ai_harness_state_repair() {
	_cd=$(ai_harness_claims_dir)
	_root=$(ai_harness_worktree_root)
	_main=$(ai_harness_main_worktree)
	mkdir -p "$_cd"

	_pairs="$(ai_harness_state_dir)/tmp/worktrees.$$"
	mkdir -p "$(dirname -- "$_pairs")"
	# Detached worktrees have no branch line and are skipped: a claim always
	# has a branch, so a detached tree is somebody's scratch space.
	git worktree list --porcelain | awk '
		/^worktree /                { p = substr($0, 10) }
		/^branch refs\/heads\//     { sub(/^branch refs\/heads\//, ""); print p "\t" $0 }
	' >"$_pairs"

	_seen="$(ai_harness_state_dir)/tmp/seen.$$"
	: >"$_seen"

	_tab=$(printf '\t')
	while IFS="$_tab" read -r _p _b; do
		[ "$_p" = "$_main" ] && continue
		case $_p in
		"$_root"/*) ;;
		*) continue ;;
		esac
		_stem=$(basename -- "$_p")
		printf '%s\n' "$_stem" >>"$_seen"
		[ -f "$_cd/$_stem" ] && continue
		_todo=$(ai_harness_todo_file "$_stem")
		_touches=
		# The todo is gone from the branch once the work is finished, so read
		# the reservation from trunk, where it still stands until the merge.
		if git cat-file -e "$AI_HARNESS_TRUNK:$_todo" 2>/dev/null; then
			_touches=$(git show "$AI_HARNESS_TRUNK:$_todo" | sed -n 's/^- \*\*Touches:\*\* *//p' | head -1)
		fi
		{
			printf 'todo=%s\n' "$_todo"
			printf 'branch=%s\n' "$_b"
			printf 'worktree=%s\n' "$_p"
			printf 'touches=%s\n' "$_touches"
			printf 'agent=%s\n' "recovered"
			printf 'claimed=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
			printf 'base=%s\n' "unknown"
		} >"$_cd/$_stem"
		log "  + claims/$_stem  rebuilt from $_b"
	done <"$_pairs"

	for _c in "$_cd"/*; do
		[ -f "$_c" ] || continue
		_stem=$(basename -- "$_c")
		if ! grep -qxF "$_stem" "$_seen" 2>/dev/null; then
			rm -f "$_c"
			log "  - claims/$_stem  dropped, its worktree is gone"
		fi
	done

	rm -f "$_pairs" "$_seen"
}
