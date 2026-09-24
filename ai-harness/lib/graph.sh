# The todo graph: Blocked-by edges, Touches intersections, and the plan built
# from them.

# Blockers of a todo file that are still open, i.e. still present in todo/.
ai_harness_open_blockers() {
	_ob=
	for _b in $(ai_harness_todo_field "$1" "Blocked by" | tr ',' ' '); do
		_b=${_b#todo/}
		_b=${_b%.md}
		[ -f "todo/$_b.md" ] && _ob="$_ob $_b"
	done
	printf '%s\n' "${_ob# }"
}

# A Touches value as space-separated globs, NEW dropped. ALL, UNKNOWN and an
# empty value all become ALL.
ai_harness_touches_norm() {
	_tn=
	set -f
	for _t in $(printf '%s' "$1" | tr ',' ' '); do
		case $_t in
		ALL | UNKNOWN) _tn=ALL && break ;;
		NEW) ;;
		*) _tn="$_tn $_t" ;;
		esac
	done
	set +f
	_tn=${_tn# }
	printf '%s\n' "${_tn:-ALL}"
}

# Whether one path can match both globs. Sound, not exact: any shared path
# starts with both literal prefixes and ends with both literal suffixes, so an
# incompatible pair is disjoint and everything else is reported as meeting.
ai_harness_globs_meet() {
	_pa=${1%%[*?[]*}
	_pb=${2%%[*?[]*}
	_sa=${1##*[]*?]}
	_sb=${2##*[]*?]}
	case $_pa in "$_pb"*) ;; *) case $_pb in "$_pa"*) ;; *) return 1 ;; esac ;; esac
	case $_sa in *"$_sb") ;; *) case $_sb in *"$_sa") ;; *) return 1 ;; esac ;; esac
}

# The first place two normalized Touches lists meet, printed; 1 when disjoint.
ai_harness_touches_meet() {
	if [ "$1" = ALL ] || [ "$2" = ALL ]; then
		echo ALL
		return 0
	fi
	set -f
	for _x in $1; do
		for _y in $2; do
			ai_harness_globs_meet "$_x" "$_y" || continue
			set +f
			if [ "$_x" = "$_y" ]; then echo "$_x"; else echo "$_x & $_y"; fi
			return 0
		done
	done
	set +f
	return 1
}

# Per active claim: claimed, stem, agent, branch. Then per unclaimed todo, by
# priority: run|hold, stem, priority|reason. Tab-separated.
ai_harness_plan() {
	_tab=$(printf '\t')
	_barrier=$(cat "$(ai_harness_state_dir)/BARRIER" 2>/dev/null) || _barrier=
	_active='' _nact=0
	for _s in $(ai_harness_claim_stems); do
		_c=$(ai_harness_claim_file "$_s")
		_active="$_active$_s$_tab$(ai_harness_touches_norm "$(ai_harness_kv_get "$_c" touches)")
"
		_nact=$((_nact + 1))
		printf 'claimed\t%s\t%s\t%s\n' "$_s" "$(ai_harness_kv_get "$_c" agent)" "$(ai_harness_kv_get "$_c" branch)"
	done
	for _f in todo/*.md; do
		[ -f "$_f" ] || continue
		case $(ai_harness_todo_field "$_f" Priority) in
		high) _pr=1 ;; medium) _pr=2 ;; low) _pr=3 ;; *) _pr=4 ;;
		esac
		printf '%s %s\n' "$_pr" "$(basename -- "$_f" .md)"
	done | sort -k1,1n -k2,2 | {
		_runs=
		while read -r _pr _s; do
			[ -f "$(ai_harness_claim_file "$_s")" ] && continue
			_f=$(ai_harness_todo_file "$_s")
			case $_pr in 1) _pr=high ;; 2) _pr=medium ;; 3) _pr=low ;; esac
			# 2>&1 before >/dev/null: the reasons are on stderr, and that is what
			# the pipe must carry.
			_why=$(ai_harness_todo_validate "$_s" 2>&1 >/dev/null | sed -n "1s/^aih: //; 1s|^$_f: ||p")
			_bl=$(ai_harness_open_blockers "$_f")
			_tc=$(ai_harness_touches_norm "$(ai_harness_todo_field "$_f" Touches)")
			_br=$(ai_harness_todo_branch_from_stem "$_s") || _br=
			if [ -n "$_why" ]; then
				_why="invalid: $_why"
			elif [ -n "$_bl" ]; then
				_why="blocked by $_bl"
			elif git show-ref --verify --quiet "refs/heads/$_br"; then
				_why="branch $_br exists unclaimed — git branch -d it to offer this again"
			elif [ -n "$_barrier" ] && [ "$_barrier" != "$_s" ]; then
				_why="barrier: draining for $_barrier"
			elif [ "$_tc" = ALL ] && { [ "$_nact" -gt 0 ] || [ -n "$_runs" ]; }; then
				_why="barrier: Touches ALL runs alone, after $_nact active claim(s) and every runnable todo above it"
			fi
			[ -n "$_why" ] || _why=$(ai_harness_plan_clash "$_tc" "$_active" "active claim")
			[ -n "$_why" ] || _why=$(ai_harness_plan_clash "$_tc" "$_runs" "runnable")
			if [ -n "$_why" ]; then
				printf 'hold\t%s\t%s\n' "$_s" "$_why"
			else
				printf 'run\t%s\t%s\n' "$_s" "$_pr"
				_runs="$_runs$_s$_tab$_tc
"
			fi
		done
	}
}

# Every entry in a "stem<TAB>touches" list that meets the given Touches.
ai_harness_plan_clash() {
	_cl=
	while IFS="$(printf '\t')" read -r _os _ot; do
		[ -n "$_os" ] || continue
		_w=$(ai_harness_touches_meet "$1" "$_ot") && _cl="$_cl; conflicts with $3 $_os on $_w"
	done <<EOF
$2
EOF
	printf '%s\n' "${_cl#; }"
}
