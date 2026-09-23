# The mechanical half of review: what a branch's diff may touch, read from git
# without a checkout.

# Every code check or integrate can report. The set is closed: a situation it
# does not name is unknown, and unknown stops like any other code. The soft
# codes are reported and never stop.
harness_codes() {
	printf '%s\n' protected-path undeclared-path undeclared-path-collision todo-deleted \
		todo-not-deleted skip-added bad-subject adr-decision adr-duplicate adr-draft \
		dirty-trunk merge-in-progress trunk-diverged gate-config gate-red-trunk escalated \
		moved merge-conflict gate-red-merge merge-refused rejected behavioural-conflict \
		needs-human cleanup-refused unknown
	harness_soft_codes
}
harness_soft_codes() { printf '%s\n' diff-large tests-shrunk; }

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

harness_check_holder() {
	for _ck_c in $(harness_claim_stems); do
		[ "$_ck_c" = "$1" ] || ! harness_check_declared "$2" "$(harness_check_touches "$_ck_c")" "$3" || break
		_ck_c=
	done
	[ -n "${_ck_c:-}" ] && printf '%s\n' "$_ck_c"
}

# $3 at merge base $1, if Accepted, against branch $2. A deletion is one hunk
# over every line, so it lands in the Decision too.
harness_check_adr() {
	_ck_old=$(git show "$1:$3" 2>/dev/null) || return 0
	printf '%s\n' "$_ck_old" | grep -q '^- \*\*Status:\*\* Accepted' || return 0
	_ck_r=$(printf '%s\n' "$_ck_old" | awk '/^## / && s && !e { e = NR }
		$0 == "## Decision" { s = NR } END { if (s) print s, (e ? e : NR + 1) }')
	git diff -U0 "$1" "$2" -- "$3" | awk -v r="${_ck_r:-0 0}" -v p="$3" 'BEGIN { split(r, b, " ") }
		/^@@ / { split(substr($2, 2), h, ","); lo = h[1] + 0; n = (2 in h) ? h[2] : 1; hi = n ? lo + n - 1 : lo
			if (lo < b[2] && hi >= b[1]) { printf "adr-decision %s changes its ## Decision at line %d\n", p, lo; exit } }'
}

harness_check_paths() {
	_ck_todo=$(harness_todo_file "$1")
	_ck_d=$(git diff --name-status --no-renames "$HARNESS_TRUNK...$2") ||
		{ printf 'unknown git diff %s...%s failed\n' "$HARNESS_TRUNK" "$2" && return 0; }
	printf '%s\n' "$_ck_d" | grep -qxF "D	$_ck_todo" || printf 'todo-not-deleted %s is still on the branch\n' "$_ck_todo"
	{ git ls-tree --name-only "$HARNESS_TRUNK" docs/ | sed 's/^/T	/' && printf '%s\n' "$_ck_d"; } | awk -F'\t' '
		$1 == "T" || $1 == "A" { f[$2] = 1 } $1 == "D" { delete f[$2] }
		END { for (p in f) if (match(p, /^docs\/adr-[0-9]+-/)) { k = substr(p, 10, RLENGTH - 10); c[k]++; g[k] = g[k] " " p }
			for (k in c) if (c[k] > 1) print "adr-duplicate ADR-" k " is" g[k] }'
	printf '%s\n' "$_ck_d" | while IFS='	' read -r _ck_s _ck_p; do
		_ck_code='' _ck_why=''
		case $_ck_s:$_ck_p in
		: | *:"$_ck_todo" | A:todo/*.md) continue ;;
		[!ADM]:*) _ck_code=unknown _ck_why=" is status $_ck_s, which check has no rule for" ;;
		D:todo/*.md) _ck_code=todo-deleted ;;
		*:AGENTS.md | *:.harness.conf | *:harness/*) _ck_code=protected-path ;;
		[MD]:docs/adr-[0-9]*) harness_check_adr "$(git merge-base "$HARNESS_TRUNK" "$2")" "$2" "$_ck_p" ;;
		esac
		if [ -z "$_ck_code" ] && ! harness_check_declared "$_ck_p" "$3" "$_ck_s"; then
			_ck_code=undeclared-path
			if harness_check_declared "$_ck_p" "${HARNESS_PROTECTED:-}" M; then
				_ck_code=protected-path
			elif _ck_who=$(harness_check_holder "$1" "$_ck_p" "$_ck_s"); then
				_ck_code=undeclared-path-collision _ck_why=", inside $_ck_who's Touches"
			fi
		fi
		[ -z "$_ck_code" ] || printf '%s %s (%s)%s\n' "$_ck_code" "$_ck_p" "$_ck_s" "$_ck_why"
	done
}

harness_check_diff() {
	git diff "$HARNESS_TRUNK...$2" | awk '/^\+\+\+ / { go = /\.go$/; next } !/^\+/ { next } go && /t\.Skip\(/ { k++ }
		{ while (match($0, /ADR-DRAFT-[A-Z0-9][A-Z0-9-]*/)) { d[substr($0, RSTART, RLENGTH)] = 1; $0 = substr($0, RSTART + RLENGTH) } }
		END { if (k) print "skip-added " k " added line(s) call t.Skip("; for (t in d) print "adr-draft " t " would reach trunk unnumbered" }'
	git log --no-merges --format='%h %s' "$HARNESS_TRUNK..$2" | awk -v px=" $HARNESS_PREFIXES " '
		{ p = $2; sub(/:$/, "", p) } NF < 3 || $2 !~ /:$/ || !index(px, " " p " ") { print "bad-subject " $0 }'
	git diff --numstat --no-renames "$HARNESS_TRUNK...$2" | awk -F'\t' -v lim="${HARNESS_DIFF_SOFT_LIMIT:-0}" '
		{ a = $1 + 0; d = $2 + 0; t += a + d }
		$3 ~ /_test\./ { tn += a - d; next } $3 !~ /^todo\// { o++ }
		END { if (lim > 0 && t > lim) printf "diff-large %d changed lines, over HARNESS_DIFF_SOFT_LIMIT=%d\n", t, lim
			if (tn < 0 && o) printf "tests-shrunk test files lose %d net lines beside %d other changed file(s)\n", -tn, o }'
}

# One "<code> <detail>" line per finding, stops before soft codes; non-zero on
# any stop. Without the "." sentinel, a producer that failed would read as clean.
harness_check() {
	{ harness_check_paths "$@" && harness_check_diff "$@" && printf '.\n'; } | awk -v known=" $(harness_codes | tr '\n' ' ')" -v soft=" $(harness_soft_codes | tr '\n' ' ')" '
		$0 == "." { done = 1; next } NF == 0 { next }
		!index(known, " " $1 " ") { $0 = "unknown " $0 }
		index(soft, " " $1 " ") { s = s $0 "\n"; next }
		{ print; n++ }
		END { if (!done) { print "unknown check stopped before it finished"; n++ }
			printf "%s", s; exit n > 0 }'
}

# fix/foo is todo/fix-foo.md: the inverse of harness_todo_branch_from_stem.
harness_stem_of_branch() { printf '%s\n' "$1" | sed 's#/#-#'; }
