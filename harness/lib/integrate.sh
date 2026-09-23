# The integrator's mechanics. Everything here is deterministic, so that the
# agent's verdict is the only judgment a merge contains.

harness_ig_file() { printf '%s/%s\n' "$(harness_state_dir)" "$1"; }

harness_ig_set() {
	_ig_f=$(harness_ig_file integrate/pending)
	{ grep -v "^$1=" "$_ig_f" 2>/dev/null || :; } >"$_ig_f.tmp"
	printf '%s=%s\n' "$1" "$2" >>"$_ig_f.tmp"
	mv "$_ig_f.tmp" "$_ig_f"
}

harness_ig_oldest() {
	for _ig_e in "$(harness_ig_file submitted)"/*; do
		[ -f "$_ig_e" ] || continue
		case $_ig_e in *.body) continue ;; esac
		printf '%s %s\n' "$(harness_kv_get "$_ig_e" epoch || :)" "$(basename -- "$_ig_e")"
	done | sort -n | head -1 | cut -d' ' -f2
}

# Prints "<code> <detail>" and fails when trunk cannot take a merge. MERGE_HEAD
# comes first: a hook-blocked merge leaves it staged rather than aborted, and
# that tree is dirty too, so status alone would misname it.
harness_ig_trunk_ready() {
	if git rev-parse -q --verify MERGE_HEAD >/dev/null; then
		printf 'merge-in-progress MERGE_HEAD is set in %s\n' "$HARNESS_REPO"
		return 1
	fi
	if [ -n "$(git status --porcelain)" ]; then
		printf 'dirty-trunk %s has uncommitted changes — the harness does not clean it\n' "$HARNESS_REPO"
		return 1
	fi
	if _ig_up=$(git rev-parse -q --verify --abbrev-ref "$HARNESS_TRUNK@{upstream}" 2>/dev/null); then
		_ig_behind=$(git rev-list --count "$HARNESS_TRUNK..$_ig_up")
		if [ "$_ig_behind" -gt 0 ]; then
			printf 'trunk-diverged %s is %s commit(s) behind %s\n' "$HARNESS_TRUNK" "$_ig_behind" "$_ig_up"
			return 1
		fi
	fi
}

# A parked item leaves the queue with its branch, worktree and claim exactly as
# they were. A @trunk park is trunk's fault, so the submission stays queued.
# The park= lines are the item's whole park history: submit carries them into
# the resubmission, and the merge writes them as Harness-Parked trailers.
harness_ig_park() {
	_ig_pd=$(harness_ig_file parked)
	_ig_sub="$(harness_ig_file submitted)/$1"
	_ig_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
	mkdir -p "$_ig_pd"
	{
		printf 'code=%s\n' "$2"
		printf 'detail=%s\n' "$3"
		printf 'parked=%s\n' "$_ig_at"
		[ "$1" = @trunk ] || cat "$_ig_sub" 2>/dev/null || :
		[ "$1" = @trunk ] || printf 'park=%s %s %s: %s\n' "$_ig_at" \
			"$(harness_kv_get "$_ig_sub" head | cut -c1-12)" "$2" "$(printf '%s' "$3" | tr '\n' ' ')"
	} >"$_ig_pd/$1"
	[ "$1" = @trunk ] || rm -f "$_ig_sub" "$_ig_sub.body"
	rm -f "$(harness_ig_file integrate/pending)"
	printf 'park %s %s: %s\n' "$1" "$2" "$3"
}

# The helpers below end the run: sourced verbs share one shell, so exit here
# exits the verb, and its EXIT trap releases the lock.
harness_ig_trunk_ok() {
	_ig_why=$(harness_ig_trunk_ready) && return 0
	harness_ig_park @trunk "${_ig_why%% *}" "${_ig_why#* }"
	exit "$EX_FAIL"
}
harness_ig_stop() {
	harness_ig_park "$@"
	exit "$EX_FAIL"
}
harness_ig_gate() {
	_ig_rc=0
	"$HARNESS_HOME/bin/harness" gate --full >&2 || _ig_rc=$?
	[ "$_ig_rc" -eq 0 ]
}
harness_ig_gate_stop() {
	[ "$_ig_rc" -ne "$EX_CONFIG" ] || harness_ig_stop @trunk gate-config "the gate cannot run on this machine — harness doctor"
	harness_ig_stop "$@"
}

# Unforced on purpose: each refuses on unmerged work or a dirty tree, which is
# exactly when cleanup should stop.
harness_ig_cleanup() {
	_ig_wt=$(harness_kv_get "$(harness_claim_file "$1")" worktree || harness_kv_get "$(harness_ig_file submitted)/$1" worktree || :)
	if [ -d "$_ig_wt" ] && ! git worktree remove "$_ig_wt"; then
		harness_ig_stop "$1" cleanup-refused "$_ig_wt is not clean and was left in place; the merge stands"
	fi
	git branch -d "$2" >/dev/null || harness_ig_stop "$1" cleanup-refused "git branch -d $2 refused; the merge stands"
	rm -f "$(harness_claim_file "$1")" "$(harness_ig_file submitted)/$1" "$(harness_ig_file submitted)/$1.body"
}
