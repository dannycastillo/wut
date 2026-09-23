# log — the history: events and merge trailers, one timeline
#
#   harness log [<todo-stem>]

[ $# -le 1 ] || die "$EX_USAGE" "usage: harness log [<todo-stem>]"
_stem=${1:-}
_stem=${_stem#todo/}
_stem=${_stem%.md}

harness_agents_reap
_tab=$(printf '\t')
_ev="$(harness_state_dir)/events"

# Each line is "<time>TAB<seq>TAB<text>": the seq keeps a merge's trailer lines
# under their merge once everything is sorted by time.
{
	[ ! -f "$_ev" ] || awk -v s="$_stem" 'NF >= 4 && (s == "" || $2 == s) {
		d = ""; for (i = 5; i <= NF; i++) d = d (i > 5 ? " " : "") $i
		printf "%s\t0\t%s  %-34s %-9s %-10s %s\n", $1, $1, $2, $3, $4, d }' "$_ev"

	# Merges on trunk are the durable record; the events above only annotate
	# them. A merge without trailers was made by hand. format-local, not
	# format: the latter renders in the committer's zone whatever TZ says.
	TZ=UTC git log --first-parent --merges --date=format-local:'%Y-%m-%dT%H:%M:%SZ' \
		--format='%H %cd %h %s' "$HARNESS_TRUNK" 2>/dev/null |
		while read -r _h _d _short _subj; do
			_tr=$(git show -s --format=%B "$_h" | git interpret-trailers --parse | grep '^Harness-' || :)
			_todo=$(printf '%s\n' "$_tr" | sed -n 's#^Harness-Todo: todo/\(.*\)\.md$#\1#p')
			if [ -n "$_todo" ]; then
				_how='by integrate'
			else
				_how='by hand'
				_todo=$(printf '%s' "$_subj" | sed -n "s/^Merge branch '\([^']*\)'.*/\1/p")
				[ -z "$_todo" ] || _todo=$(harness_stem_of_branch "$_todo")
			fi
			[ -z "$_stem" ] || [ "$_todo" = "$_stem" ] || continue
			printf '%s\t0\t%s  %-34s %-9s %-10s %s %s\n' "$_d" "$_d" "${_todo:-?}" - merged "$_short" "$_how"
			printf '%s\n' "$_tr" | grep -v '^Harness-Todo:' | grep . |
				awk -v d="$_d" '{ printf "%s\t%d\t%56s%s\n", d, NR, "", $0 }'
		done
} | sort -t "$_tab" -k1,1 -k2,2n | cut -f3-
