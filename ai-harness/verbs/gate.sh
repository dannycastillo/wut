# gate — run the project's declared checks, one result line each

_list=$AI_HARNESS_GATES
_label=full
while [ $# -gt 0 ]; do
	case $1 in
	--quick)
		_list=${AI_HARNESS_QUICK_GATES:-}
		_label=quick
		;;
	--full)
		_list=$AI_HARNESS_GATES
		_label=full
		;;
	*) die "$EX_USAGE" "gate: unknown option: $1" ;;
	esac
	shift
done

# Every declared gate, not just the subset being run: a worker should learn
# that the full gate cannot run now, rather than at submit.
ai_harness_gate_preflight ||
	die "$EX_CONFIG" "gate: the environment cannot run the declared gates"

[ -n "$_list" ] || die "$EX_CONFIG" "gate: nothing declared for --$_label"

_tmp="$(ai_harness_state_dir)/tmp"
mkdir -p "$_tmp"
_out="$_tmp/gate.$$"
_t0=$(date -u '+%s')
_done=
_failed=

for _g in $_list; do
	_locked=no
	case " ${AI_HARNESS_EXCLUSIVE_GATES:-} " in
	*" $_g "*)
		if ai_harness_lock_wait "gate-$_g" "${AI_HARNESS_GATE_LOCK_WAIT:-300}"; then
			_locked=yes
		else
			printf 'gate %-11s blocked  %s\n' "$_g" "$(ai_harness_lock_who "gate-$_g")"
			_failed=$_g
			break
		fi
		;;
	esac

	_s=$(date -u '+%s')
	# A subshell so a gate that cd's or exports cannot reach the next one.
	if (ai_harness_gate_"$_g") >"$_out" 2>&1; then
		printf 'gate %-11s ok  %ss\n' "$_g" "$(($(date -u '+%s') - _s))"
		_done="$_done $_g"
	else
		printf 'gate %-11s FAILED  %ss\n' "$_g" "$(($(date -u '+%s') - _s))"
		printf '\n'
		cat "$_out"
		printf '\n'
		_failed=$_g
	fi
	[ "$_locked" = no ] || ai_harness_lock_release "gate-$_g"
	[ -z "$_failed" ] || break
done

rm -f "$_out"

if [ -n "$_failed" ]; then
	_skipped=
	_seen=no
	for _g in $_list; do
		[ "$_g" = "$_failed" ] && _seen=yes && continue
		[ "$_seen" = yes ] && _skipped="$_skipped $_g"
	done
	[ -z "$_skipped" ] || log "gate: did not run:$_skipped"
	die "$EX_FAIL" "gate --$_label: $_failed failed ($(($(date -u '+%s') - _t0))s)"
fi

log "gate --$_label: ok ($(($(date -u '+%s') - _t0))s)"
