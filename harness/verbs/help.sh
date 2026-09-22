# help — list the verbs and how to invoke them
#
# The list is globbed rather than declared, so a new verb appears here for free.

printf 'harness — %s\n\n' "$HARNESS_PROJECT"
printf 'verbs:\n'
for _f in "$HARNESS_HOME"/verbs/*.sh; do
	_name=$(basename -- "$_f" .sh)
	_desc=$(sed -n '1s/^# [a-z-]* — //p' "$_f")
	printf '  %-12s %s\n' "$_name" "$_desc"
done

cat <<'TXT'

Each worktree runs its own copy, so put this in your shell rather than a fixed
PATH entry:

  harness() { "$(git rev-parse --show-toplevel)/harness/bin/harness" "$@"; }

exit codes: 0 ok, 1 failed, 2 usage, 3 paused, 10 judgment needed
TXT
