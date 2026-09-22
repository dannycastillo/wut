# doctor — check the harness's assumptions before anything is able to mutate
#
# Assertions only. What the harness can do and how to invoke it is harness help.

_selftest=no
_repair=no
while [ $# -gt 0 ]; do
	case $1 in
	--print-state-dir)
		harness_state_dir
		exit "$EX_OK"
		;;
	--selftest) _selftest=yes ;;
	--repair) _repair=yes ;;
	*) die "$EX_USAGE" "doctor: unknown option: $1" ;;
	esac
	shift
done

if [ "$_repair" = yes ]; then
	log 'reconciling claims against git worktree list'
	harness_state_repair
	log 'repair: done'
fi

_fails=0
_row() { printf '  %-13s %s\n' "$1" "$2"; }
_bad() {
	printf '  %-13s %s\n' "$1" "$2"
	_fails=$((_fails + 1))
}

_row project "$HARNESS_PROJECT ($HARNESS_REPO)"

_state=$(harness_state_dir)
mkdir -p "$_state" 2>/dev/null || :
if [ -d "$_state" ] && [ -w "$_state" ]; then
	_row "state dir" "$_state"
else
	_bad "state dir" "$_state (not a writable directory)"
fi

_trunk_wt=$(harness_trunk_worktree)
if [ -z "$_trunk_wt" ]; then
	# Only integrate needs trunk checked out, and it checks for itself. Every
	# other verb works fine while the main worktree sits on a branch.
	_row trunk "$HARNESS_TRUNK is not checked out anywhere — integrate cannot run"
else
	_dirty=$(git -C "$_trunk_wt" status --porcelain | wc -l | tr -d ' ')
	if [ "$_dirty" -eq 0 ]; then
		_row trunk "$HARNESS_TRUNK at $_trunk_wt"
	else
		_row trunk "$HARNESS_TRUNK at $_trunk_wt ($_dirty uncommitted — integrate would park)"
	fi
fi

_wt_root=$(harness_worktree_root)
if [ -d "$_wt_root" ]; then
	if [ -w "$_wt_root" ]; then
		_row "worktree root" "$_wt_root"
	else
		_bad "worktree root" "$_wt_root (not writable)"
	fi
elif [ -w "$(dirname -- "$_wt_root")" ]; then
	_row "worktree root" "$_wt_root (will be created on first claim)"
else
	_bad "worktree root" "$(dirname -- "$_wt_root") is not writable"
fi

# One preflight, shared with the gate verb: doctor is advisory, so the same
# assertion has to sit in front of the thing that actually runs the gates.
if _pf=$(harness_gate_preflight 2>&1); then
	_row gates "$HARNESS_GATES (all runnable)"
else
	_row gates "$HARNESS_GATES"
	# Fed by redirect, not a pipe. A pipe would run the loop in a subshell and
	# the _fails increments would be discarded with it.
	while IFS= read -r _line; do
		if [ -n "$_line" ]; then
			_bad preflight "${_line#harness: }"
		fi
	done <<PF
$_pf
PF
fi

_orphan=
for _g in ${HARNESS_QUICK_GATES:-} ${HARNESS_EXCLUSIVE_GATES:-}; do
	case " $HARNESS_GATES " in
	*" $_g "*) ;;
	*) _orphan="$_orphan $_g" ;;
	esac
done
if [ -n "$_orphan" ]; then
	_bad "gate subsets" "not in HARNESS_GATES:$_orphan"
else
	_row "gate subsets" "quick: ${HARNESS_QUICK_GATES:-none}   exclusive: ${HARNESS_EXCLUSIVE_GATES:-none}"
fi

_row worktrees "$(git worktree list | wc -l | tr -d ' ') (including the main one)"
_row push "${HARNESS_PUSH:-no}"

if [ "$_selftest" = yes ]; then
	printf '\n  selftest (HEAD, not the working tree)\n'
	_tmp=$(mktemp -d)
	_wt="$_tmp/linked"
	if git worktree add --detach "$_wt" HEAD >/dev/null 2>&1; then
		if [ -x "$_wt/harness/bin/harness" ]; then
			_here=$(harness_state_dir)
			_there=$(cd "$_wt" && ./harness/bin/harness doctor --print-state-dir) ||
				_there="(the linked worktree's harness failed)"
			if [ "$_here" = "$_there" ]; then
				_row "  state dir" "identical from a linked worktree"
			else
				_bad "  state dir" "root: $_here / linked: $_there"
			fi
		else
			_bad "  worktree" "harness/ is not committed on HEAD yet"
		fi
		git worktree remove --force "$_wt" >/dev/null 2>&1 ||
			_bad "  cleanup" "could not remove $_wt"
		git worktree prune
	else
		_bad "  worktree" "could not create a throwaway worktree"
	fi
	rm -rf "$_tmp"
fi

printf '\n'
if [ "$_fails" -eq 0 ]; then
	log "doctor: ok"
else
	die "$EX_FAIL" "doctor: $_fails problem(s)"
fi
