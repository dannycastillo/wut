# Shared helpers. Sourced by harness/bin/harness before any verb.
#
# POSIX sh only: macOS ships bash 3.2.57, so no arrays and no mapfile.

# shellcheck disable=SC2034  # read by verbs, which are sourced at runtime
EX_OK=0
EX_FAIL=1
EX_USAGE=2
EX_PAUSED=3
# The environment cannot run the gate, as distinct from the gate failing.
# The integrator must not blame a branch for a misconfigured machine.
EX_CONFIG=4
EX_JUDGE=10

log()  { printf '%s\n' "$*" >&2; }
warn() { printf 'harness: %s\n' "$*" >&2; }

die() {
	_c=$1
	shift
	printf 'harness: %s\n' "$*" >&2
	exit "$_c"
}

# The coordination state directory, shared by every worktree and structurally
# untrackable by git (ADR-07).
#
# --git-common-dir, never --git-dir or --git-path: those two are per-worktree
# for this name, and all three spellings return ".git" from the main worktree.
# A slip here passes every test run from the root and first breaks once a second
# worker exists, silently, by giving each worker a private claims directory.
harness_state_dir() {
	_d=$(git rev-parse --git-common-dir) || return 1
	case $_d in
	/*) ;;
	*) _d=$(CDPATH='' cd -- "$_d" && pwd -P) ;;
	esac
	printf '%s/harness\n' "$_d"
}

# The main worktree: the one holding .git itself. Relative paths in
# .harness.conf resolve against this rather than the current worktree, which
# would otherwise nest HARNESS_WORKTREE_ROOT inside itself one level down.
harness_main_worktree() {
	_d=$(git rev-parse --git-common-dir) || return 1
	case $_d in
	/*) ;;
	*) _d=$(CDPATH='' cd -- "$_d" && pwd -P) ;;
	esac
	dirname -- "$_d"
}

harness_worktree_root() {
	case $HARNESS_WORKTREE_ROOT in
	/*) _r=$HARNESS_WORKTREE_ROOT ;;
	*) _r="$(harness_main_worktree)/$HARNESS_WORKTREE_ROOT" ;;
	esac
	# It need not exist yet, so normalize the parent and keep the leaf.
	printf '%s/%s\n' "$(CDPATH='' cd -- "$(dirname -- "$_r")" && pwd -P)" "$(basename -- "$_r")"
}

# Where trunk is checked out, discovered rather than assumed. Empty when trunk
# is not checked out anywhere.
harness_trunk_worktree() {
	git worktree list --porcelain | awk -v b="refs/heads/$HARNESS_TRUNK" '
		/^worktree /  { p = substr($0, 10) }
		$0 == "branch " b { print p; exit }
	'
}

harness_is_defined() { command -v "$1" >/dev/null 2>&1; }
