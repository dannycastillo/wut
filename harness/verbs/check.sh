# check — may this branch merge, mechanically? Read-only, no checkout
#
#   harness check [<todo-stem>]    defaults to the current branch's todo

[ $# -le 1 ] || die "$EX_USAGE" "usage: harness check [<todo-stem>]"
if [ $# -eq 1 ]; then
	_stem=${1#todo/}
	_stem=${_stem%.md}
else
	_b=$(git symbolic-ref -q --short HEAD) || die "$EX_USAGE" "check: detached HEAD — name the todo"
	_stem=$(harness_stem_of_branch "$_b")
fi

_branch=$(harness_todo_branch_from_stem "$_stem") ||
	die "$EX_USAGE" "check: '$_stem' starts with no declared prefix ($HARNESS_PREFIXES)"
git rev-parse -q --verify "refs/heads/$_branch" >/dev/null ||
	die "$EX_FAIL" "check: no branch $_branch"

_touches=$(harness_check_touches "$_stem")
[ -n "$_touches" ] || die "$EX_FAIL" "check: no Touches for $_stem on $HARNESS_TRUNK or in its claim"

harness_check "$_stem" "$_branch" "$_touches" || die "$EX_FAIL" "check: $_branch may not merge"
printf 'clean\n'
