# Locks. mkdir is the primitive: it is atomic on every filesystem the harness
# runs on, and it carries a directory to put the holder's identity in.
#
# A stale lock is reported, never stolen. An aih that steals locks is one
# nobody can trust to have finished what it started.

AI_HARNESS_LOCK_STALE_SECONDS=${AI_HARNESS_LOCK_STALE_SECONDS:-1800}

ai_harness_lock_path() { printf '%s/lock/%s\n' "$(ai_harness_state_dir)" "$1"; }

ai_harness_lock_acquire() {
	_lp=$(ai_harness_lock_path "$1")
	mkdir -p "$(dirname -- "$_lp")" || return 1
	mkdir "$_lp" 2>/dev/null || return 1
	# After the mkdir, not before: mkdir is the atomic step, so the lock is
	# already held and a reader that arrives mid-write sees a partial holder
	# rather than an unheld lock.
	{
		printf 'pid=%s\n' "$$"
		printf 'host=%s\n' "$(uname -n)"
		printf 'verb=%s\n' "${AI_HARNESS_VERB:-unknown}"
		printf 'since=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
		printf 'epoch=%s\n' "$(date -u '+%s')"
	} >"$_lp/holder" 2>/dev/null || :
}

ai_harness_lock_release() {
	_lp=$(ai_harness_lock_path "$1")
	rm -f "$_lp/holder"
	rmdir "$_lp" 2>/dev/null || :
}

ai_harness_lock_held() { [ -d "$(ai_harness_lock_path "$1")" ]; }

# One line describing who holds it and for how long. Age comes from the epoch
# the holder wrote, because turning an ISO timestamp back into seconds needs
# date -d on GNU and date -j -f on BSD, and neither is portable.
ai_harness_lock_who() {
	_lp=$(ai_harness_lock_path "$1")
	_h="$_lp/holder"
	if [ ! -f "$_h" ]; then
		printf 'held, by nothing identifiable (interrupted before it could say)\n'
		return 0
	fi
	_pid=$(sed -n 's/^pid=//p' "$_h")
	_verb=$(sed -n 's/^verb=//p' "$_h")
	_host=$(sed -n 's/^host=//p' "$_h")
	_since=$(sed -n 's/^since=//p' "$_h")
	_epoch=$(sed -n 's/^epoch=//p' "$_h")
	_age=
	if [ -n "$_epoch" ]; then
		_age=" ($(( $(date -u '+%s') - _epoch ))s)"
	fi
	printf 'held by %s pid %s on %s since %s%s\n' \
		"${_verb:-?}" "${_pid:-?}" "${_host:-?}" "${_since:-?}" "$_age"
}

ai_harness_lock_is_stale() {
	_epoch=$(sed -n 's/^epoch=//p' "$(ai_harness_lock_path "$1")/holder" 2>/dev/null)
	[ -n "$_epoch" ] || return 1
	[ $(( $(date -u '+%s') - _epoch )) -gt "$AI_HARNESS_LOCK_STALE_SECONDS" ]
}

# Wait briefly, then give up. Used where contention is normal and short: two
# agents claiming different todos in the same second should both succeed.
ai_harness_lock_wait() {
	_name=$1
	_limit=${2:-10}
	_waited=0
	while ! ai_harness_lock_acquire "$_name"; do
		if [ "$_waited" -ge "$_limit" ]; then
			# The caller reports the holder; staleness is the part it cannot know.
			ai_harness_lock_is_stale "$_name" &&
				warn "lock '$_name' looks stale — inspect it, then: aih unlock $_name"
			return 1
		fi
		sleep 1
		_waited=$((_waited + 1))
	done
}
