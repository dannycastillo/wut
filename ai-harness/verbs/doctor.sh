# doctor — check the harness's assumptions before anything is able to mutate
#
# Assertions only. What the harness can do and how to invoke it is aih help.

_selftest=no
_repair=no
while [ $# -gt 0 ]; do
	case $1 in
	--print-state-dir)
		ai_harness_state_dir
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
	ai_harness_state_repair
	log 'repair: done'
fi

_fails=0
_row() { printf '  %-13s %s\n' "$1" "$2"; }
_bad() {
	printf '  %-13s %s\n' "$1" "$2"
	_fails=$((_fails + 1))
}

_row project "$AI_HARNESS_PROJECT ($AI_HARNESS_REPO)"

_state=$(ai_harness_state_dir)
mkdir -p "$_state" 2>/dev/null || :
if [ -d "$_state" ] && [ -w "$_state" ]; then
	_row "state dir" "$_state"
else
	_bad "state dir" "$_state (not a writable directory)"
fi

_trunk_wt=$(ai_harness_trunk_worktree)
if [ -z "$_trunk_wt" ]; then
	# Only integrate needs trunk checked out, and it checks for itself. Every
	# other verb works fine while the main worktree sits on a branch.
	_row trunk "$AI_HARNESS_TRUNK is not checked out anywhere — integrate cannot run"
else
	_dirty=$(git -C "$_trunk_wt" status --porcelain | wc -l | tr -d ' ')
	if [ "$_dirty" -eq 0 ]; then
		_row trunk "$AI_HARNESS_TRUNK at $_trunk_wt"
	else
		_row trunk "$AI_HARNESS_TRUNK at $_trunk_wt ($_dirty uncommitted — integrate would park)"
	fi
fi

_wt_root=$(ai_harness_worktree_root)
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
if _pf=$(ai_harness_gate_preflight 2>&1); then
	_row gates "$AI_HARNESS_GATES (all runnable)"
else
	_row gates "$AI_HARNESS_GATES"
	# Fed by redirect, not a pipe. A pipe would run the loop in a subshell and
	# the _fails increments would be discarded with it.
	while IFS= read -r _line; do
		if [ -n "$_line" ]; then
			_bad preflight "${_line#aih: }"
		fi
	done <<PF
$_pf
PF
fi

_orphan=
for _g in ${AI_HARNESS_QUICK_GATES:-} ${AI_HARNESS_EXCLUSIVE_GATES:-}; do
	case " $AI_HARNESS_GATES " in
	*" $_g "*) ;;
	*) _orphan="$_orphan $_g" ;;
	esac
done
if [ -n "$_orphan" ]; then
	_bad "gate subsets" "not in AI_HARNESS_GATES:$_orphan"
else
	_row "gate subsets" "quick: ${AI_HARNESS_QUICK_GATES:-none}   exclusive: ${AI_HARNESS_EXCLUSIVE_GATES:-none}"
fi

_row worktrees "$(git worktree list | wc -l | tr -d ' ') (including the main one)"
_row push "${AI_HARNESS_PUSH:-no}"

# The block is refreshed by install and reported here; never rewritten here.
_blk=$(sed -n '/^<!-- ai-harness:begin /,/^<!-- ai-harness:end -->$/p' "$AI_HARNESS_REPO/AGENTS.md" 2>/dev/null)
if [ -z "$_blk" ]; then
	_bad AGENTS.md "no ai-harness block between <!-- ai-harness:begin --> and <!-- ai-harness:end -->"
else
	_want=$(printf '%s\n' "$_blk" | sed -n '1s/.*cksum=\([0-9]*\).*/\1/p')
	_got=$(printf '%s\n' "$_blk" | sed '1d;$d' | cksum | cut -d' ' -f1)
	if [ "$_want" = "$_got" ]; then
		_row AGENTS.md "ai-harness block intact"
	else
		_bad AGENTS.md "ai-harness block edited: its cksum is $_got, the marker says ${_want:-nothing} — update the marker if the edit is meant"
	fi
fi

# Advisory: dispatched agents get this tree's bin on PATH regardless.
if _l=$(command -v aih 2>/dev/null); then
	_row launcher "$_l"
else
	_row launcher "aih is not on PATH; for your own shell, install the launcher:"
	cat <<'TXT'
                  cat >~/.local/bin/aih <<'EOF'
                  #!/bin/sh
                  exec "$(git rev-parse --show-toplevel)/ai-harness/bin/aih" "$@"
                  EOF
                  chmod +x ~/.local/bin/aih
TXT
fi

if [ "$_selftest" = yes ]; then
	printf '\n  selftest (HEAD, not the working tree)\n'
	ai_harness_selftest || _fails=$((_fails + 1))
fi

printf '\n'
if [ "$_fails" -eq 0 ]; then
	log "doctor: ok"
else
	die "$EX_FAIL" "doctor: $_fails problem(s)"
fi
