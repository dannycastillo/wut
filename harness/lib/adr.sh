# ADR numbering at merge (ADR-08), and the assertions that follow it.

harness_adr_nns() {
	for _nn_f in docs/adr-[0-9][0-9]-*.md; do
		[ -f "$_nn_f" ] || continue
		_nn_f=${_nn_f#docs/adr-}
		printf '%s\n' "${_nn_f%%-*}"
	done
}

harness_adr_next() {
	_an=$(harness_adr_nns | sort -n | tail -1)
	_an=${_an#0}
	printf '%02d\n' $((${_an:-0} + 1))
}

# Rewrites a file in place through sed, keeping its mode: sed -i differs
# between BSD and GNU, and mv over the file would drop an executable bit.
harness_adr_rewrite() {
	_ar_f=$1
	shift
	sed "$@" "$_ar_f" >"$_ar_f.tmp" && cat "$_ar_f.tmp" >"$_ar_f" && rm -f "$_ar_f.tmp"
}

# Numbers every draft in the tree. Runs inside integrate after the merge and
# before its gate, so the tree that is gated is the tree that lands. The
# number is recomputed here, not taken from anywhere: that is the whole fix.
harness_adr_number_drafts() {
	for _ad_f in docs/adr-draft-*.md; do
		[ -f "$_ad_f" ] || continue
		_ad_kebab=${_ad_f#docs/adr-draft-}
		_ad_kebab=${_ad_kebab%.md}
		_ad_tok="ADR-DRAFT-$(printf '%s' "$_ad_kebab" | tr '[:lower:]' '[:upper:]')"
		_ad_nn=$(harness_adr_next)
		_ad_new="docs/adr-$_ad_nn-$_ad_kebab.md"
		git mv "$_ad_f" "$_ad_new" || return 1
		harness_adr_rewrite "$_ad_new" \
			-e "s/^# $_ad_tok:/# ADR-$_ad_nn:/" \
			-e 's/^- \*\*Status:\*\* Proposed$/- **Status:** Accepted/' \
			-e "s/^- \*\*Date:\*\* .*/- **Date:** $(date -u '+%Y-%m-%d')/"
		for _ad_g in $(git grep -l -F "$_ad_tok" -- . 2>/dev/null); do
			harness_adr_rewrite "$_ad_g" -e "s/$_ad_tok/ADR-$_ad_nn/g"
		done
		git add -u -- . || return 1
		log "integrate: numbered $_ad_f as ADR-$_ad_nn"
	done
}

# Prints "<code> <detail>" and fails on a token that survived numbering or an
# NN held by two files. A human numbering by hand is what the second catches.
harness_adr_assert() {
	_aa=$(git grep -l -e 'ADR-DRAFT-[A-Z0-9]' -- . 2>/dev/null | head -1)
	[ -z "$_aa" ] || {
		printf 'adr-draft %s still carries an ADR-DRAFT token after numbering\n' "$_aa"
		return 1
	}
	_aa=$(harness_adr_nns | sort | uniq -d | head -1)
	[ -z "$_aa" ] || {
		printf 'adr-duplicate ADR-%s is %s\n' "$_aa" "$(for _aa_f in docs/adr-"$_aa"-*.md; do printf '%s ' "$_aa_f"; done)"
		return 1
	}
}
