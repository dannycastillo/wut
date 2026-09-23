# path — print a claim's worktree, for cd "$(aih path <todo>)"

[ $# -eq 1 ] || die "$EX_USAGE" "usage: aih path <todo-stem>"
_stem=${1#todo/}
_stem=${_stem%.md}
_c=$(ai_harness_claim_file "$_stem")
[ -f "$_c" ] || die "$EX_FAIL" "path: $_stem is not claimed"
_wt=$(ai_harness_kv_get "$_c" worktree)
[ -d "$_wt" ] || die "$EX_FAIL" "path: $_wt is recorded but gone — aih doctor --repair"
printf '%s\n' "$_wt"
