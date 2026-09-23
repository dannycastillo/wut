# submit — hand a finished branch to the integrator
#
#   harness submit [--body <file>|-] [--note "<observation>"]... [--escalate "<reason>"]

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
_stem=$(harness_stem_of_branch "$_branch")
_c=$(harness_claim_file "$_stem")
[ -f "$_c" ] || die "$EX_FAIL" "submit: $_branch holds no claim — harness status"
[ "$(harness_kv_get "$_c" branch)" = "$_branch" ] ||
	die "$EX_FAIL" "submit: the claim on $_stem is for $(harness_kv_get "$_c" branch), not $_branch"
[ -z "$(git status --porcelain)" ] || die "$EX_FAIL" "submit: the tree has uncommitted work"
! git cat-file -e "HEAD:$(harness_todo_file "$_stem")" 2>/dev/null ||
	die "$EX_FAIL" "submit: $(harness_todo_file "$_stem") is still on the branch — git rm it in the final commit"
[ "$(git rev-list --count "$HARNESS_TRUNK..HEAD")" -gt 0 ] ||
	die "$EX_FAIL" "submit: $_branch has no commits beyond $HARNESS_TRUNK"

_p="$(harness_state_dir)/integrate/pending"
[ "$(harness_kv_get "$_p" stem || :)" != "$_stem" ] ||
	die "$EX_FAIL" "submit: $_stem is mid-integration, awaiting a verdict"

_q="$(harness_state_dir)/submitted"
_tmp="$(harness_state_dir)/tmp/submit.$$"
mkdir -p "$_q" "$(dirname -- "$_tmp")"

# The harness writes the body itself because git merge -F - does not read
# stdin: the merge needs a real path, and finding out at merge time is late.
case $_body in
"") git log --no-merges --reverse --format='%s' "$HARNESS_TRUNK..HEAD" >"$_tmp.body" ;;
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
# so every Harness-* trailer below it would silently vanish.
if grep -q '^---' "$_tmp.body"; then
	rm -f "$_tmp.body"
	die "$EX_USAGE" "submit: the body has a line starting ---, which would hide the merge's trailers"
fi

if ! "$HARNESS_HOME/bin/harness" gate --full; then
	rm -f "$_tmp.body"
	die "$EX_FAIL" "submit: gate --full is red — not submitted"
fi

{
	printf 'todo=%s\n' "$(harness_todo_file "$_stem")"
	printf 'branch=%s\n' "$_branch"
	printf 'head=%s\n' "$(git rev-parse HEAD)"
	printf 'worktree=%s\n' "$HARNESS_REPO"
	printf 'agent=%s\n' "$(harness_kv_get "$_c" agent || :)"
	printf 'submitted=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
	printf 'epoch=%s\n' "$(date -u '+%s')"
	printf 'escalate=%s\n' "$_esc"
	printf '%s' "$_notes" | sed '/^$/d; s/^/note=/'
	sed -n '/^park=/p' "$(harness_state_dir)/parked/$_stem" 2>/dev/null || :
} >"$_tmp"

# The entry is what the integrator polls for, so it lands last and whole.
mv "$_tmp.body" "$_q/$_stem.body"
mv "$_tmp" "$_q/$_stem"
rm -f "$(harness_state_dir)/parked/$_stem"

log "submit: $_stem queued for the integrator"
[ -z "$_esc" ] || log "  escalated: $_esc — it will park for a human"
