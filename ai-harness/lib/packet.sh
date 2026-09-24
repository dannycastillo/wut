# What the reviewer reads before its verdict, and what the merge records.

ai_harness_ig_packet() {
	_ig_p=$(ai_harness_ig_file integrate/pending)
	printf 'judgment needed: %s\n\n' "$1"
	printf '  branch  %s @ %s\n' "$2" "$(git rev-parse --short "$2")"
	printf '  trunk   %s @ %s, baseline gate green\n' "$AI_HARNESS_TRUNK" "$(git rev-parse --short HEAD)"
	printf '  check   %s\n\n' "$(ai_harness_kv_get "$_ig_p" check)"
	git log --no-merges --format='  %h %s' "$AI_HARNESS_TRUNK..$2"
	printf '\n'
	git diff --stat "$AI_HARNESS_TRUNK...$2" | sed 's/^/  /'
	printf '\n  Done when (%s:%s) — run every box that needs running, do not read it off the diff:\n' \
		"$AI_HARNESS_TRUNK" "$(ai_harness_todo_file "$1")"
	git show "$AI_HARNESS_TRUNK:$(ai_harness_todo_file "$1")" 2>/dev/null | awk '
		function flush() { if (box != "") print "    - " box; box = "" }
		/^## / { flush(); on = ($0 == "## Done when"); next }
		!on { next }
		/^- \[[ xX]\] / { flush(); box = substr($0, 7); next }
		/^[ \t]+[^ \t]/ && box != "" { sub(/^[ \t]+/, ""); box = box " " $0; next }
		{ flush() }
		END { flush() }
	'
	sed -n 's/^note=/  note: /p' "$(ai_harness_ig_file submitted)/$1"
	printf '\n  body:   %s\n' "$(ai_harness_ig_file submitted)/$1.body"
	printf '\ncontinue with exactly one of:\n'
	printf '  aih integrate --continue --verdict pass\n'
	printf '  aih integrate --continue --reject "<which box>"\n'
	printf '  aih integrate --continue --park <code> --detail "<what>"\n'
}

# Prose, a blank line, then trailers and nothing else. No --- separator: git
# reads it as the patch divider and interpret-trailers then finds no block.
ai_harness_ig_message() {
	_ig_sub="$(ai_harness_ig_file submitted)/$1"
	_ig_p=$(ai_harness_ig_file integrate/pending)
	printf "Merge branch '%s'\n\n" "$2"
	awk 1 "$_ig_sub.body"
	printf '\nAI-Harness-Todo: %s\n' "$(ai_harness_todo_file "$1")"
	printf 'AI-Harness-Worker: %s\n' "$(ai_harness_kv_get "$_ig_sub" agent || :)"
	printf 'AI-Harness-Gate: baseline:ok merge:ok (%s)\n' "$AI_HARNESS_GATES"
	printf 'AI-Harness-Check: %s\n' "$(ai_harness_kv_get "$_ig_p" check || :)"
	printf 'AI-Harness-Donewhen: %s\n' "$(ai_harness_kv_get "$_ig_p" verdict || :)"
	sed -n 's/^park=/AI-Harness-Parked: /p' "$_ig_sub"
	sed -n 's/^note=/AI-Harness-Notes: /p' "$_ig_sub"
}
