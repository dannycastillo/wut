# Gate preconditions.
#
# Libraries here may only DEFINE functions: bin/harness sources lib/*.sh in
# glob order, so anything running at source time would run in that order too.

# The tools a gate needs, or nothing when the gate declares none.
harness_gate_tools() {
	case $1 in
	# The name is interpolated into a variable name below, where an illegal
	# character expands to a neighbouring variable plus leftover text instead
	# of failing — an answer that reads as real.
	*[!a-z0-9_]*) return 1 ;;
	esac
	eval "printf '%s\n' \"\${HARNESS_GATE_TOOLS_$1:-}\""
}

# Everything standing between the declared gates and their being able to run.
# A gate that cannot run is a hard stop, not a skip: the gate is what decides
# whether a branch may merge, so one that reports green without running is
# worse than no gate at all. A project lacking a tool declares fewer gates
# rather than declaring a gate that quietly does nothing.
harness_gate_preflight() {
	_bad=0
	for _g in $HARNESS_GATES; do
		if ! _tools=$(harness_gate_tools "$_g"); then
			warn "gate '$_g': name is not [a-z0-9_]"
			_bad=1
			continue
		fi
		harness_is_defined "harness_gate_$_g" || {
			warn "gate '$_g': harness_gate_$_g is not defined in .harness.conf"
			_bad=1
		}
		if [ -z "$_tools" ]; then
			warn "gate '$_g': no HARNESS_GATE_TOOLS_$_g — declare what it needs on PATH"
			_bad=1
			continue
		fi
		for _t in $_tools; do
			harness_is_defined "$_t" || {
				warn "gate '$_g': $_t is not installed"
				_bad=1
			}
		done
	done
	[ "$_bad" -eq 0 ]
}
