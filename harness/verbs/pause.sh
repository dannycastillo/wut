# pause — stop dispatching; what is queued still merges, what runs still runs
#
#   harness pause "<reason>"

[ $# -eq 1 ] && [ -n "$1" ] || die "$EX_USAGE" 'usage: harness pause "<reason>"'
_f="$(harness_state_dir)/PAUSED"
mkdir -p "$(dirname -- "$_f")"
printf '%s\n' "$1" >"$_f"
harness_event @run - paused "$1"
log "pause: no new claims until harness resume — $1"
