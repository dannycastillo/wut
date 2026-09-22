# Reading and validating one todo file.

harness_todo_file() { printf 'todo/%s.md\n' "$1"; }

# The value of a "- **Field:** value" line.
harness_todo_field() { sed -n "s/^- \*\*$2:\*\* *//p" "$1" | head -1; }

# todo/<prefix>-<kebab>.md is branch <prefix>/<kebab>. Split on the declared
# prefixes rather than the first hyphen, since a kebab description contains
# hyphens too.
harness_todo_branch_from_stem() {
	for _p in $HARNESS_PREFIXES; do
		case $1 in
		"$_p"-*)
			printf '%s/%s\n' "$_p" "${1#"$_p"-}"
			return 0
			;;
		esac
	done
	return 1
}

harness_todo_validate() {
	_stem=$1
	_f=$(harness_todo_file "$_stem")
	_bad=0

	[ -f "$_f" ] || {
		warn "no such todo: $_f"
		return 1
	}

	_want=$(harness_todo_branch_from_stem "$_stem") || {
		warn "$_f: '$_stem' starts with no declared prefix ($HARNESS_PREFIXES)"
		return 1
	}

	_got=$(harness_todo_field "$_f" Branch)
	[ "$_got" = "$_want" ] || {
		warn "$_f: Branch is '$_got', but the filename means '$_want'"
		_bad=1
	}

	case $(harness_todo_field "$_f" Priority) in
	high | medium | low) ;;
	*) warn "$_f: Priority must be high, medium or low"; _bad=1 ;;
	esac

	[ -n "$(harness_todo_field "$_f" Touches)" ] || {
		warn "$_f: Touches is empty — it reserves nothing"
		_bad=1
	}

	[ "$_bad" -eq 0 ]
}
