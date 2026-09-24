# plan — what can run now, and why everything else cannot
#
#   aih plan [<todo-stem>...]
#
# Stems given are the set aih run <stem>... would work, so this is its preview:
# a todo outside the set is neither runnable nor able to hold one in it. What
# is claimed shows whatever the set, since a claim holds regardless.

_stems=
for _a in "$@"; do
	case $_a in -*) die "$EX_USAGE" "usage: aih plan [<todo-stem>...]" ;; esac
	_s=${_a#todo/}
	_s=${_s%.md}
	[ -f "$(ai_harness_todo_file "$_s")" ] || die "$EX_USAGE" "plan: no such todo: $_s"
	_stems="$_stems $_s"
done

_tab=$(printf '\t')
# shellcheck disable=SC2086  # a list of stems
_out=$(ai_harness_plan $_stems)

_section() {
	_rows=$(printf '%s\n' "$_out" | awk -F'\t' -v k="$1" '$1 == k { printf "  %-34s %s\n", $2, (NF > 3 ? sprintf("%-34s %s", $3, $4) : $3) }')
	[ -z "$_rows" ] || printf '%s\n%s\n\n' "$2" "$_rows"
}
_section run 'runnable, in priority order'
_section hold 'held'
_section claimed 'claimed'

# Every overlapping pair, not just the ones the plan tripped over: two held
# todos that meet will still collide once whatever holds them clears.
_all=
for _f in todo/*.md; do
	[ -f "$_f" ] || continue
	_s=$(basename -- "$_f" .md)
	if [ -n "$_stems" ] && [ ! -f "$(ai_harness_claim_file "$_s")" ]; then
		case " $_stems " in *" $_s "*) ;; *) continue ;; esac
	fi
	_all="$_all$_s$_tab$(ai_harness_touches_norm "$(ai_harness_todo_field "$_f" Touches)")
"
done

printf 'overlaps\n'
_rest=$_all
while IFS="$_tab" read -r _a _ta; do
	[ -n "$_a" ] || continue
	_rest=${_rest#*
}
	if [ "$_ta" = ALL ]; then
		printf '  %-34s %s\n' "$_a" 'against everything (barrier)'
		continue
	fi
	while IFS="$_tab" read -r _b _tb; do
		[ -n "$_b" ] && [ "$_tb" != ALL ] || continue
		_w=$(ai_harness_touches_meet "$_ta" "$_tb") || continue
		printf '  %-34s %s  on %s\n' "$_a" "$_b" "$_w"
	done <<EOF
$_rest
EOF
done <<EOF
$_all
EOF
