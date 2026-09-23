# resume — lift a pause

[ $# -eq 0 ] || die "$EX_USAGE" 'usage: harness resume'
_f="$(harness_state_dir)/PAUSED"
[ -f "$_f" ] || die "$EX_OK" "resume: not paused"
rm -f "$_f"
harness_event @run - resumed ""
log "resume: claims allowed again"
