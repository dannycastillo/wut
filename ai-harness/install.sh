#!/bin/sh
# install.sh — lift ai-harness into a repo that has never seen it
#
#   ai-harness/install.sh [--yes] [<repo>]        fresh install into <repo> (default: .)
#   ai-harness/install.sh --upgrade [<repo>]      replace the tree; keep the config
#
# Copies this tree, detects the gate and writes .ai-harness.conf, inserts the
# marker-delimited AGENTS.md block, installs the launcher when aih is not on
# PATH, and copies the adapters whose dot directory already exists. It never
# writes into .git/hooks (adr-2026-09-23-the-harness-installs-no-git-hooks).

set -eu

SRC=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
readonly SRC

die() { # <message> [<exit code>]
	printf 'install: %s\n' "$1" >&2
	exit "${2:-1}"
}
say() { printf 'install: %s\n' "$*" >&2; }
has() { command -v "$1" >/dev/null 2>&1; }

yes=no
upgrade=no
target=.
while [ $# -gt 0 ]; do
	case $1 in
	--yes | -y) yes=yes ;;
	--upgrade) upgrade=yes ;;
	-h | --help)
		sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	-*) die "unknown option: $1 (try --help)" 2 ;;
	*) target=$1 ;;
	esac
	shift
done

[ -x "$SRC/bin/aih" ] || die "$SRC is not an ai-harness tree (no bin/aih)"
[ -d "$target" ] || die "no such directory: $target"
target=$(CDPATH='' cd -- "$target" && pwd -P)
top=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null) ||
	die "$target is not inside a git repository"
[ "$top" = "$target" ] || die "$target is not the repository root ($top is)"
[ "$SRC" != "$target/ai-harness" ] || die "$SRC is already the tree in $target"

conf="$target/.ai-harness.conf"
if [ "$upgrade" = yes ]; then
	[ -f "$conf" ] || die "no .ai-harness.conf in $target — nothing to upgrade; install instead"
else
	[ ! -f "$conf" ] || die "$conf exists — use --upgrade to replace the tree and keep it"
fi

tmp=$(mktemp -d) || die "could not make a temp directory"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- detection
#
# In order of preference; the first stack found wins. Each detector appends
# gate functions to $tmp/gates and their names to $gates, and names the file
# it read in $detected. A gate is declared only for a tool that is actually
# present at install time, and never for one it merely expects — a gate that
# cannot run stops the harness rather than quietly passing.

gates=
quick=
detected=
gate() { # <name> <tools> <command>
	printf 'ai_harness_gate_%s() { %s; }\n' "$1" "$3" >>"$tmp/gates"
	printf 'AI_HARNESS_GATE_TOOLS_%s="%s"\n' "$1" "$2" >>"$tmp/gates"
	gates="$gates $1"
}

detect_go() {
	[ -f "$target/go.mod" ] || return 1
	detected=go.mod
	gate build go 'go build ./...'
	gate vet go 'go vet ./...'
	cat >>"$tmp/gates" <<'EOF'
ai_harness_gate_fmt() {
	out=$(gofmt -l .)
	[ -z "$out" ] || {
		printf '%s\n' "$out"
		return 1
	}
}
AI_HARNESS_GATE_TOOLS_fmt="gofmt"
EOF
	gates="$gates fmt"
	gate test go 'go test ./...'
	quick="build vet"
}

# The scripts block of package.json, keys only. Good enough for a file written
# by npm or a human; a script value holding a "}" on its own line ends it early.
npm_scripts() {
	sed -n '/"scripts"[[:space:]]*:/,/^[[:space:]]*}/p' "$target/package.json" |
		sed '1d' | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*:.*/\1/p'
}

detect_node() {
	[ -f "$target/package.json" ] || return 1
	detected=package.json
	pm=npm
	[ ! -f "$target/pnpm-lock.yaml" ] || pm=pnpm
	[ ! -f "$target/yarn.lock" ] || pm=yarn
	scripts=$(npm_scripts)
	for s in lint typecheck build test; do
		printf '%s\n' "$scripts" | grep -qx "$s" || continue
		gate "$s" "$pm" "$pm run $s"
		case $s in
		lint | typecheck) quick="$quick $s" ;;
		build) [ -n "$quick" ] || quick=build ;;
		esac
	done
	quick=${quick# }
}

detect_cargo() {
	[ -f "$target/Cargo.toml" ] || return 1
	detected=Cargo.toml
	gate build cargo 'cargo build'
	! has rustfmt || gate fmt 'cargo rustfmt' 'cargo fmt --check'
	! has cargo-clippy || gate clippy 'cargo cargo-clippy' 'cargo clippy -- -D warnings'
	gate test cargo 'cargo test'
	quick=build
}

# Only tools the file declares a [tool.<name>] table for, so the gate reflects
# a choice the project made rather than one this script made for it.
detect_python() {
	[ -f "$target/pyproject.toml" ] || return 1
	detected=pyproject.toml
	for t in ruff black mypy pytest; do
		grep -q "^\[tool\.$t\(\.\|\]\)" "$target/pyproject.toml" || continue
		case $t in
		ruff) gate ruff ruff 'ruff check .' && quick="$quick ruff" ;;
		black) gate black black 'black --check .' ;;
		mypy) gate mypy mypy 'mypy .' && quick="$quick mypy" ;;
		pytest) gate test pytest pytest ;;
		esac
	done
	quick=${quick# }
}

detect_make() {
	[ -f "$target/Makefile" ] || return 1
	detected=Makefile
	for t in build lint check fmt test; do
		grep -q "^${t}[[:space:]]*:" "$target/Makefile" || continue
		gate "$t" make "make $t"
		case $t in
		build | lint | check) quick="$quick $t" ;;
		esac
	done
	quick=${quick# }
}

detect() {
	detect_go || detect_node || detect_cargo || detect_python || detect_make || :
	[ -z "$detected" ] || [ -n "$gates" ] || {
		say "$detected found, but nothing in it names a check this script recognises"
		detected=
	}
	if [ -z "$detected" ]; then
		# An undefined gate function is what doctor and gate refuse loudly,
		# which is the point: nothing merges until someone writes it.
		detected="nothing it recognises"
		gates=" unconfigured"
		quick=unconfigured
		printf '%s\n' '# install.sh recognised no stack. Define ai_harness_gate_unconfigured and' \
			'# AI_HARNESS_GATE_TOOLS_unconfigured, or rename the gate to what it runs.' >>"$tmp/gates"
	fi
	# shellsize needs only wc and awk; shellcheck only when it is here to run.
	! has shellcheck || gates="$gates shellcheck"
	gates="${gates# } shellsize"
}

# ------------------------------------------------------------------- config

trunk_name() {
	for b in main master; do
		if git -C "$target" show-ref --verify --quiet "refs/heads/$b"; then
			printf '%s\n' "$b"
			return
		fi
	done
	git -C "$target" symbolic-ref --short HEAD 2>/dev/null || printf 'main\n'
}

write_conf() {
	project=$(basename -- "$target")
	trunk=$(trunk_name)
	{
		printf 'AI_HARNESS_GATES="%s"\n' "$gates"
		printf 'AI_HARNESS_QUICK_GATES="%s"\n\n' "$quick"
		cat "$tmp/gates"
	} >"$tmp/gateblock"
	sed -e "s|@PROJECT@|$project|g" -e "s|@TRUNK@|$trunk|g" \
		-e "s|@WORKTREE_ROOT@|../$project-worktrees|g" -e "s|@DETECTED@|$detected|g" \
		"$SRC/templates/ai-harness.conf" |
		awk -v f="$tmp/gateblock" '
			$0 == "@GATES@" { while ((getline l < f) > 0) print l; next }
			{ print }' >"$tmp/conf"
}

confirm() {
	printf '\n--- %s (from %s) ---\n' ".ai-harness.conf" "$detected"
	cat "$tmp/conf"
	printf -- '--- end ---\n\n'
	[ "$yes" = no ] || return 0
	[ -t 0 ] || die "refusing to install unconfirmed: pass --yes, or run from a terminal" 2
	printf 'Write this config and install into %s? [y/N] ' "$target"
	read -r ans
	case $ans in
	y | Y | yes | YES) ;;
	*) die "aborted; nothing written" 1 ;;
	esac
}

# ---------------------------------------------------------------- AGENTS.md

block_marker() { printf '<!-- ai-harness:begin cksum=%s -->\n' "$(cksum <"$SRC/templates/agents-block.md" | cut -d' ' -f1)"; }

# Writes the marker, the block, and the end marker, with no blank line inside
# the markers: doctor checksums exactly the lines between them.
block() {
	block_marker
	cat "$SRC/templates/agents-block.md"
	printf '<!-- ai-harness:end -->\n'
}

agents_has_block() {
	grep -q '^<!-- ai-harness:begin ' "$target/AGENTS.md" 2>/dev/null &&
		grep -q '^<!-- ai-harness:end -->$' "$target/AGENTS.md"
}

# 0 when the block in AGENTS.md is exactly what its marker says it was.
agents_block_intact() {
	blk=$(sed -n '/^<!-- ai-harness:begin /,/^<!-- ai-harness:end -->$/p' "$target/AGENTS.md")
	want=$(printf '%s\n' "$blk" | sed -n '1s/.*cksum=\([0-9]*\).*/\1/p')
	got=$(printf '%s\n' "$blk" | sed '1d;$d' | cksum | cut -d' ' -f1)
	[ "$want" = "$got" ]
}

agents_replace_block() {
	block >"$tmp/block"
	awk -v f="$tmp/block" '
		/^<!-- ai-harness:begin / { while ((getline l < f) > 0) print l; skip = 1; next }
		/^<!-- ai-harness:end -->$/ { skip = 0; next }
		!skip { print }' "$target/AGENTS.md" >"$tmp/agents"
	cat "$tmp/agents" >"$target/AGENTS.md"
}

install_agents() {
	if [ ! -f "$target/AGENTS.md" ]; then
		block >"$tmp/block"
		sed "s|@TRUNK@|$(trunk_name)|g" "$SRC/templates/AGENTS.md" |
			awk -v f="$tmp/block" '
				$0 == "<!-- ai-harness:block -->" { while ((getline l < f) > 0) print l; next }
				{ print }' >"$target/AGENTS.md"
		say "AGENTS.md: created from the template"
	elif ! agents_has_block; then
		# Appended, after one blank line, so the file's own sections are not
		# moved. A missing final newline would glue the marker to a sentence.
		[ -z "$(tail -c1 "$target/AGENTS.md")" ] || printf '\n' >>"$target/AGENTS.md"
		{
			printf '\n'
			block
		} >>"$target/AGENTS.md"
		say "AGENTS.md: block appended"
	elif agents_block_intact; then
		agents_replace_block
		say "AGENTS.md: block refreshed"
	else
		say "AGENTS.md: block was edited after install — left as is; doctor will say the same"
	fi
}

# --------------------------------------------------- adapters and launcher

# The table in adapters/README.md is the one source of which platform reads
# which dot directory. A dot directory is copied into only when it exists:
# its presence is the only evidence the platform is in use.
install_adapters() {
	# shellcheck disable=SC2016  # the backticks are markdown, matched literally
	sed -n 's/^| `\([^`]*\)` *| `\([^`]*\)\/` .*/\1 \2/p' "$SRC/adapters/README.md" |
		while read -r platform dir; do
			[ -d "$SRC/adapters/$platform" ] || continue
			if [ -d "$target/$dir" ]; then
				cp -R "$SRC/adapters/$platform/." "$target/$dir/"
				say "adapter: $platform copied into $dir/"
			else
				say "adapter: $platform skipped, no $dir/ in $target"
			fi
		done
}

install_launcher() {
	if has aih; then
		say "launcher: aih is already on PATH at $(command -v aih); left alone"
		return
	fi
	bin="${HOME}/.local/bin"
	if [ -e "$bin/aih" ]; then
		say "launcher: $bin/aih exists but is not on PATH; left alone"
		return
	fi
	mkdir -p "$bin"
	cat >"$bin/aih" <<'EOF'
#!/bin/sh
exec "$(git rev-parse --show-toplevel)/ai-harness/bin/aih" "$@"
EOF
	chmod +x "$bin/aih"
	say "launcher: written to $bin/aih"
	case ":$PATH:" in
	*":$bin:"*) ;;
	*) say "launcher: $bin is not on PATH — add it, or run ai-harness/bin/aih" ;;
	esac
}

# --------------------------------------------------------------------- run

install_tree() {
	[ "$upgrade" = no ] || rm -rf "$target/ai-harness"
	mkdir -p "$target/ai-harness"
	cp -R "$SRC/." "$target/ai-harness/"
	say "tree: copied to $target/ai-harness"
}

if [ "$upgrade" = no ]; then
	detect
	write_conf
	confirm
	install_tree
	cp "$tmp/conf" "$conf"
	say "config: written to $conf"
else
	install_tree
	say "config: $conf untouched"
fi
install_agents
install_adapters
install_launcher

say "done — review the diff, then: git add ai-harness .ai-harness.conf AGENTS.md"
say "doctor:"
cd "$target" && exec ./ai-harness/bin/aih doctor
