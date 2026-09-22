# unlock — release a lock a dead process left behind
#
# Deliberately manual. Nothing in the harness steals a lock: a tool that
# decides on its own that another process has died will eventually decide it
# about a process that is still working.

_name=
_force=no
while [ $# -gt 0 ]; do
	case $1 in
	--force) _force=yes ;;
	-*) die "$EX_USAGE" "unlock: unknown option: $1" ;;
	*) _name=$1 ;;
	esac
	shift
done
[ -n "$_name" ] || die "$EX_USAGE" "usage: harness unlock <name> --force"

harness_lock_held "$_name" || die "$EX_FAIL" "unlock: '$_name' is not held"
log "lock '$_name' $(harness_lock_who "$_name")"
[ "$_force" = yes ] ||
	die "$EX_USAGE" "unlock: confirm with --force once you know that holder is gone"
harness_lock_release "$_name"
log "unlock: '$_name' released"
