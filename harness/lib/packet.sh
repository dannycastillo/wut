# What the reviewer reads before its verdict, and what the merge records.

# Only a box that names a static property of the tree can be settled by reading
# a patch. Anything that has to happen is behavioural, and the default.
harness_ig_boxes() {
	git show "$HARNESS_TRUNK:$(harness_todo_file "$1")" 2>/dev/null | awk '
		function flush() {
			if (box == "") return
			l = tolower(box)
			k = "needs running"
			if (l ~ /unchanged|restate|no longer (says|names)|carries|names no|is deleted/ &&
			    l !~ /(^|[^a-z])(pass|fail|run|refuse|merge|park|return|behave|print|exit|reach|list|work)(e?s)?([^a-z]|$)/)
				k = "from diff"
			printf "    [%-13s] %s\n", k, box
			box = ""
		}
		/^## / { flush(); on = ($0 == "## Done when"); next }
		!on { next }
		/^- \[[ xX]\] / { flush(); box = substr($0, 7); next }
		/^[ \t]+[^ \t]/ && box != "" { sub(/^[ \t]+/, ""); box = box " " $0; next }
		{ flush() }
		END { flush() }
	'
}

harness_ig_packet() {
	_ig_p=$(harness_ig_file integrate/pending)
	printf 'judgment needed: %s\n\n' "$1"
	printf '  branch  %s @ %s\n' "$2" "$(git rev-parse --short "$2")"
	printf '  trunk   %s @ %s, baseline gate green\n' "$HARNESS_TRUNK" "$(git rev-parse --short HEAD)"
	printf '  check   %s\n\n' "$(harness_kv_get "$_ig_p" check)"
	git log --no-merges --format='  %h %s' "$HARNESS_TRUNK..$2"
	printf '\n'
	git diff --stat "$HARNESS_TRUNK...$2" | sed 's/^/  /'
	printf '\n  Done when (%s:%s) — run every needs-running box, do not read it off the diff:\n' \
		"$HARNESS_TRUNK" "$(harness_todo_file "$1")"
	harness_ig_boxes "$1"
	sed -n 's/^note=/  note: /p' "$(harness_ig_file submitted)/$1"
	printf '\n  body:   %s\n' "$(harness_ig_file submitted)/$1.body"
	printf '\ncontinue with exactly one of:\n'
	printf '  harness integrate --continue --verdict pass\n'
	printf '  harness integrate --continue --reject "<which box>"\n'
	printf '  harness integrate --continue --park <code> --detail "<what>"\n'
}

# Prose, a blank line, then trailers and nothing else. No --- separator: git
# reads it as the patch divider and interpret-trailers then finds no block.
harness_ig_message() {
	_ig_sub="$(harness_ig_file submitted)/$1"
	_ig_p=$(harness_ig_file integrate/pending)
	printf "Merge branch '%s'\n\n" "$2"
	awk 1 "$_ig_sub.body"
	printf '\nHarness-Todo: %s\n' "$(harness_todo_file "$1")"
	printf 'Harness-Worker: %s\n' "$(harness_kv_get "$_ig_sub" agent || :)"
	printf 'Harness-Gate: baseline:ok merge:ok (%s)\n' "$HARNESS_GATES"
	printf 'Harness-Check: %s\n' "$(harness_kv_get "$_ig_p" check || :)"
	printf 'Harness-Donewhen: %s\n' "$(harness_kv_get "$_ig_p" verdict || :)"
	sed -n 's/^park=/Harness-Parked: /p' "$_ig_sub"
	sed -n 's/^note=/Harness-Notes: /p' "$_ig_sub"
}
