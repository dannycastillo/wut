# The mechanical half of review: what a branch's diff may touch, read from git
# without a checkout.

# Every code check or integrate can report. The set is closed: a situation it
# does not name is unknown, and unknown stops like any other code.
harness_codes() {
	printf '%s\n' protected-path undeclared-path todo-deleted todo-not-deleted \
		skip-added bad-subject dirty-trunk merge-in-progress \
		trunk-diverged gate-config gate-red-trunk escalated moved \
		merge-conflict gate-red-merge merge-refused rejected \
		behavioural-conflict needs-human cleanup-refused unknown
}

harness_code_known() { harness_codes | grep -qxF -- "$1"; }

# Read from trunk, where the todo still stands until the merge; the claim file
# is only a copy, and one an agent can edit.
harness_check_touches() {
	_ck_t=$(git show "$HARNESS_TRUNK:$(harness_todo_file "$1")" 2>/dev/null |
		sed -n 's/^- \*\*Touches:\*\* *//p' | head -1)
	[ -n "$_ck_t" ] || _ck_t=$(harness_kv_get "$(harness_claim_file "$1")" touches) || :
	printf '%s\n' "$_ck_t"
}

# Whether a path with git status $3 falls inside the Touches in $2. The globs
# are matched unquoted on purpose, and set -f keeps the loop from expanding them
# against the working tree first.
# shellcheck disable=SC2254
harness_check_declared() {
	_ck_hit=no
	_ck_new=no
	set -f
	for _ck_g in $(printf '%s' "$2" | tr ',' ' '); do
		case $_ck_g in
		ALL | UNKNOWN) _ck_hit=yes ;;
		NEW) _ck_new=yes && continue ;;
		esac
		if [ "$_ck_new" = no ] || [ "$3" = A ]; then
			case $1 in $_ck_g) _ck_hit=yes ;; esac
		fi
		_ck_new=no
	done
	set +f
	[ "$_ck_hit" = yes ]
}

# One "<code> <detail>" line per finding on stdout. Non-zero on any finding.
harness_check() {
	_ck_stem=$1
	_ck_branch=$2
	_ck_touches=$3
	_ck_todo=$(harness_todo_file "$_ck_stem")
	_ck_n=0
	_ck_gone=no
	_ck_list="$(harness_state_dir)/tmp/check.$$"
	mkdir -p "$(dirname -- "$_ck_list")"

	if ! git diff --name-status --no-renames "$HARNESS_TRUNK...$_ck_branch" >"$_ck_list"; then
		printf 'unknown git diff %s...%s failed\n' "$HARNESS_TRUNK" "$_ck_branch"
		rm -f "$_ck_list"
		return 1
	fi

	_ck_tab=$(printf '\t')
	while IFS="$_ck_tab" read -r _ck_s _ck_p; do
		_ck_code=
		case $_ck_s:$_ck_p in
		[!ADM]:*) _ck_code=unknown ;;
		"D:$_ck_todo") _ck_gone=yes && continue ;;
		*:"$_ck_todo") continue ;;
		A:todo/*.md) continue ;;
		D:todo/*.md) _ck_code=todo-deleted ;;
		*:AGENTS.md | *:.harness.conf | *:harness/*) _ck_code=protected-path ;;
		esac
		if [ -z "$_ck_code" ] && ! harness_check_declared "$_ck_p" "$_ck_touches" "$_ck_s"; then
			_ck_code=undeclared-path
			! harness_check_declared "$_ck_p" "${HARNESS_PROTECTED:-}" M || _ck_code=protected-path
		fi
		[ -n "$_ck_code" ] || continue
		printf '%s %s (%s)\n' "$_ck_code" "$_ck_p" "$_ck_s"
		_ck_n=$((_ck_n + 1))
	done <"$_ck_list"
	rm -f "$_ck_list"

	if [ "$_ck_gone" = no ]; then
		printf 'todo-not-deleted %s is still on the branch\n' "$_ck_todo"
		_ck_n=$((_ck_n + 1))
	fi

	_ck_skips=$(git diff "$HARNESS_TRUNK...$_ck_branch" -- '*.go' |
		grep '^+' | grep -v '^+++' | grep -c 't\.Skip(' || :)
	if [ "${_ck_skips:-0}" -gt 0 ]; then
		printf 'skip-added %s added line(s) call t.Skip(\n' "$_ck_skips"
		_ck_n=$((_ck_n + 1))
	fi

	while IFS= read -r _ck_line; do
		[ -n "$_ck_line" ] || continue
		_ck_ok=no
		for _ck_px in $HARNESS_PREFIXES; do
			case ${_ck_line#* } in "$_ck_px: "*) _ck_ok=yes ;; esac
		done
		[ "$_ck_ok" = no ] || continue
		printf 'bad-subject %s\n' "$_ck_line"
		_ck_n=$((_ck_n + 1))
	done <<LOG
$(git log --no-merges --format='%h %s' "$HARNESS_TRUNK..$_ck_branch")
LOG

	[ "$_ck_n" -eq 0 ]
}

# fix/foo is todo/fix-foo.md: the inverse of harness_todo_branch_from_stem.
harness_stem_of_branch() { printf '%s\n' "$1" | sed 's#/#-#'; }
