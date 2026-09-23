# pause — stop dispatching; what is queued still merges, what runs still runs
#
#   aih pause "<reason>"

[ $# -eq 1 ] && [ -n "$1" ] || die "$EX_USAGE" 'usage: aih pause "<reason>"'
_f="$(ai_harness_state_dir)/PAUSED"
mkdir -p "$(dirname -- "$_f")"
printf '%s\n' "$1" >"$_f"
ai_harness_event @run - paused "$1"
log "pause: no new claims until aih resume — $1"
