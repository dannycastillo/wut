# submit — hand a finished branch to the reviewer
#
#   aih submit [--body <file>|-] [--note "<observation>"]... [--escalate "<reason>"]

_body=
_esc=
_notes=
_nl='
'
while [ $# -gt 0 ]; do
	case $1 in
	--body | --note | --escalate)
		[ $# -gt 1 ] || die "$EX_USAGE" "submit: $1 needs a value"
		case $1 in
		--body) _body=$2 ;;
		--note) _notes="$_notes$(printf '%s' "$2" | tr '\n' ' ')$_nl" ;;
		--escalate) _esc=$(printf '%s' "$2" | tr '\n' ' ') ;;
		esac
		shift
		;;
	*) die "$EX_USAGE" "submit: unknown argument: $1" ;;
	esac
	shift
done

_branch=$(git symbolic-ref -q --short HEAD) || die "$EX_FAIL" "submit: detached HEAD"
_stem=$(ai_harness_stem_of_branch "$_branch")
_c=$(ai_harness_claim_file "$_stem")
[ -f "$_c" ] || die "$EX_FAIL" "submit: $_branch holds no claim — aih status"
[ "$(ai_harness_kv_get "$_c" branch)" = "$_branch" ] ||
	die "$EX_FAIL" "submit: the claim on $_stem is for $(ai_harness_kv_get "$_c" branch), not $_branch"
[ -z "$(git status --porcelain)" ] || die "$EX_FAIL" "submit: the tree has uncommitted work"
! git cat-file -e "HEAD:$(ai_harness_todo_file "$_stem")" 2>/dev/null ||
	die "$EX_FAIL" "submit: $(ai_harness_todo_file "$_stem") is still on the branch — git rm it in the final commit"
[ "$(git rev-list --count "$AI_HARNESS_TRUNK..HEAD")" -gt 0 ] ||
	die "$EX_FAIL" "submit: $_branch has no commits beyond $AI_HARNESS_TRUNK"

_p="$(ai_harness_state_dir)/integrate/pending"
[ "$(ai_harness_kv_get "$_p" stem || :)" != "$_stem" ] ||
	die "$EX_FAIL" "submit: $_stem is mid-integration, awaiting a verdict"

_q="$(ai_harness_state_dir)/submitted"
_tmp="$(ai_harness_state_dir)/tmp/submit.$$"
mkdir -p "$_q" "$(dirname -- "$_tmp")"

# aih writes the body itself because git merge -F - does not read
# stdin: the merge needs a real path, and finding out at merge time is late.
case $_body in
"") git log --no-merges --reverse --format='%s' "$AI_HARNESS_TRUNK..HEAD" >"$_tmp.body" ;;
-) cat >"$_tmp.body" ;;
*)
	[ -f "$_body" ] || die "$EX_USAGE" "submit: no such body file: $_body"
	cat -- "$_body" >"$_tmp.body"
	;;
esac
[ -n "$(tr -d ' \t\n' <"$_tmp.body")" ] || {
	rm -f "$_tmp.body"
	die "$EX_USAGE" "submit: the body is empty"
}
# A --- line is git's patch separator: interpret-trailers stops reading there,
# so every AI-Harness-* trailer below it would silently vanish.
if grep -q '^---' "$_tmp.body"; then
	rm -f "$_tmp.body"
	die "$EX_USAGE" "submit: the body has a line starting ---, which would hide the merge's trailers"
fi

if ! "$AI_HARNESS_HOME/bin/aih" gate --full; then
	rm -f "$_tmp.body"
	die "$EX_FAIL" "submit: gate --full is red — not submitted"
fi

{
	printf 'todo=%s\n' "$(ai_harness_todo_file "$_stem")"
	printf 'branch=%s\n' "$_branch"
	printf 'head=%s\n' "$(git rev-parse HEAD)"
	printf 'worktree=%s\n' "$AI_HARNESS_REPO"
	printf 'agent=%s\n' "$(ai_harness_kv_get "$_c" agent || :)"
	printf 'submitted=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	printf 'epoch=%s\n' "$(date -u '+%s')"
	printf 'escalate=%s\n' "$_esc"
	printf '%s' "$_notes" | sed '/^$/d; s/^/note=/'
	sed -n '/^park=/p' "$(ai_harness_state_dir)/parked/$_stem" 2>/dev/null || :
} >"$_tmp"

# The entry is what the reviewer polls for, so it lands last and whole.
mv "$_tmp.body" "$_q/$_stem.body"
mv "$_tmp" "$_q/$_stem"
rm -f "$(ai_harness_state_dir)/parked/$_stem"
# A resubmission invalidates the last judgment, so it may have a reviewer again.
rm -f "$(ai_harness_agent_file "$_stem" reviewer)" "$(ai_harness_agent_file "$_stem" reviewer).exit"

ai_harness_event "$_stem" worker submitted "$(git rev-parse --short HEAD)${_esc:+ escalated: $_esc}"
log "submit: $_stem queued for the reviewer"
[ -z "$_esc" ] || log "  escalated: $_esc — it will park for a human"
