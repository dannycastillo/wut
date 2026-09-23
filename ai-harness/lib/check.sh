# The mechanical half of review: what a branch's diff may touch, read from git
# without a checkout.

# Every code check or integrate can report. The set is closed: a situation it
# does not name is unknown, and unknown stops like any other code. The soft
# codes are reported and never stop.
ai_harness_codes() {
	printf '%s\n' protected-path undeclared-path undeclared-path-collision todo-deleted \
		todo-not-deleted skip-added bad-subject \
		dirty-trunk merge-in-progress trunk-diverged gate-config gate-red-trunk escalated \
		moved merge-conflict gate-red-merge merge-refused rejected behavioural-conflict \
		needs-human cleanup-refused unknown
	ai_harness_soft_codes
}
ai_harness_soft_codes() { printf '%s\n' diff-large tests-shrunk; }

ai_harness_code_known() { ai_harness_codes | grep -qxF -- "$1"; }

# Read from trunk, where the todo still stands until the merge; the claim file
# is only a copy, and one an agent can edit.
ai_harness_check_touches() {
	_ck_t=$(git show "$AI_HARNESS_TRUNK:$(ai_harness_todo_file "$1")" 2>/dev/null |
		sed -n 's/^- \*\*Touches:\*\* *//p' | head -1)
	[ -n "$_ck_t" ] || _ck_t=$(ai_harness_kv_get "$(ai_harness_claim_file "$1")" touches) || :
	printf '%s\n' "$_ck_t"
}

# Whether a path with git status $3 falls inside the Touches in $2. The globs
# are matched unquoted on purpose, and set -f keeps the loop from expanding them
# against the working tree first.
# shellcheck disable=SC2254
ai_harness_check_declared() {
	_ck_hit=no _ck_new=no
	set -f
	for _ck_g in $(printf '%s' "$2" | tr ',' ' '); do
		case $_ck_g in ALL | UNKNOWN) _ck_hit=yes ;; NEW) _ck_new=yes && continue ;; esac
		if [ "$_ck_new" = no ] || [ "$3" = A ]; then case $1 in $_ck_g) _ck_hit=yes ;; esac; fi
		_ck_new=no
	done
	set +f
	[ "$_ck_hit" = yes ]
}

ai_harness_check_holder() {
	for _ck_c in $(ai_harness_claim_stems); do
		[ "$_ck_c" = "$1" ] || ! ai_harness_check_declared "$2" "$(ai_harness_check_touches "$_ck_c")" "$3" || break
		_ck_c=
	done
	[ -n "${_ck_c:-}" ] && printf '%s\n' "$_ck_c"
}

ai_harness_check_paths() {
	_ck_todo=$(ai_harness_todo_file "$1")
	_ck_d=$(git diff --name-status --no-renames "$AI_HARNESS_TRUNK...$2") ||
		{ printf 'unknown git diff %s...%s failed\n' "$AI_HARNESS_TRUNK" "$2" && return 0; }
	printf '%s\n' "$_ck_d" | grep -qxF "D	$_ck_todo" || printf 'todo-not-deleted %s is still on the branch\n' "$_ck_todo"
	printf '%s\n' "$_ck_d" | while IFS='	' read -r _ck_s _ck_p; do
		_ck_code='' _ck_why=''
		case $_ck_s:$_ck_p in
		: | *:"$_ck_todo" | A:todo/*.md) continue ;;
		[!ADM]:*) _ck_code=unknown _ck_why=" is status $_ck_s, which check has no rule for" ;;
		D:todo/*.md) _ck_code=todo-deleted ;;
		*:AGENTS.md | *:.ai-harness.conf | *:ai-harness/*) _ck_code=protected-path ;;
		esac
		if [ -z "$_ck_code" ] && ! ai_harness_check_declared "$_ck_p" "$3" "$_ck_s"; then
			_ck_code=undeclared-path
			if ai_harness_check_declared "$_ck_p" "${AI_HARNESS_PROTECTED:-}" M; then
				_ck_code=protected-path
			elif _ck_who=$(ai_harness_check_holder "$1" "$_ck_p" "$_ck_s"); then
				_ck_code=undeclared-path-collision _ck_why=", inside $_ck_who's Touches"
			fi
		fi
		[ -z "$_ck_code" ] || printf '%s %s (%s)%s\n' "$_ck_code" "$_ck_p" "$_ck_s" "$_ck_why"
	done
}

ai_harness_check_diff() {
	git diff "$AI_HARNESS_TRUNK...$2" | awk '/^\+\+\+ / { go = /\.go$/; next } !/^\+/ { next } go && /t\.Skip\(/ { k++ }
		END { if (k) print "skip-added " k " added line(s) call t.Skip(" }'
	git log --no-merges --format='%h %s' "$AI_HARNESS_TRUNK..$2" | awk -v px=" $AI_HARNESS_PREFIXES " '
		{ p = $2; sub(/:$/, "", p) } NF < 3 || $2 !~ /:$/ || !index(px, " " p " ") { print "bad-subject " $0 }'
	git diff --numstat --no-renames "$AI_HARNESS_TRUNK...$2" | awk -F'\t' -v lim="${AI_HARNESS_DIFF_SOFT_LIMIT:-0}" '
		{ a = $1 + 0; d = $2 + 0; t += a + d }
		$3 ~ /_test\./ { tn += a - d; next } $3 !~ /^todo\// { o++ }
		END { if (lim > 0 && t > lim) printf "diff-large %d changed lines, over AI_HARNESS_DIFF_SOFT_LIMIT=%d\n", t, lim
			if (tn < 0 && o) printf "tests-shrunk test files lose %d net lines beside %d other changed file(s)\n", -tn, o }'
}

# One "<code> <detail>" line per finding, stops before soft codes; non-zero on
# any stop. Without the "." sentinel, a producer that failed would read as clean.
ai_harness_check() {
	{ ai_harness_check_paths "$@" && ai_harness_check_diff "$@" && printf '.\n'; } | awk -v known=" $(ai_harness_codes | tr '\n' ' ')" -v soft=" $(ai_harness_soft_codes | tr '\n' ' ')" '
		$0 == "." { done = 1; next } NF == 0 { next }
		!index(known, " " $1 " ") { $0 = "unknown " $0 }
		index(soft, " " $1 " ") { s = s $0 "\n"; next }
		{ print; n++ }
		END { if (!done) { print "unknown check stopped before it finished"; n++ }
			printf "%s", s; exit n > 0 }'
}

# fix/foo is todo/fix-foo.md: the inverse of ai_harness_todo_branch_from_stem.
ai_harness_stem_of_branch() { printf '%s\n' "$1" | sed 's#/#-#'; }
