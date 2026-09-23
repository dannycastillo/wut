# help — list the verbs and how to invoke them
#
# The list is globbed rather than declared, so a new verb appears here for free.

printf 'aih — AI Harness for %s\n\n' "$AI_HARNESS_PROJECT"
printf 'verbs:\n'
for _f in "$AI_HARNESS_HOME"/verbs/*.sh; do
	_name=$(basename -- "$_f" .sh)
	_desc=$(sed -n '1s/^# [a-z-]* — //p' "$_f")
	printf '  %-12s %s\n' "$_name" "$_desc"
done

cat <<'TXT'

Each worktree runs its own copy, so aih on PATH is a launcher, never a fixed
path or a symlink. aih doctor prints it when it is missing.

exit codes: 0 ok, 1 failed, 2 usage, 3 paused, 10 judgment needed
TXT
