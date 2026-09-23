# resume — lift a pause

[ $# -eq 0 ] || die "$EX_USAGE" 'usage: aih resume'
_f="$(ai_harness_state_dir)/PAUSED"
[ -f "$_f" ] || die "$EX_OK" "resume: not paused"
rm -f "$_f"
ai_harness_event @run - resumed ""
log "resume: claims allowed again"
