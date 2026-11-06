#!/usr/bin/env bash
# IP hygiene gate (see docs/IP_HYGIENE.md).
# 1. Fails if any tracked text file uses a banned franchise term. The pattern is stored
#    base64-encoded so this script does not itself spell the terms out.
# 2. Fails if a file under art/ or audio/ is missing from docs/ASSET_LOG.md.
# AGENTS.md and LEGAL.md are skipped because they define the banned list.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern="$(printf '%s' 'cG9rW2XDqV18XGJneW1cYnxcYihobXx0bSlbMC05XXsxLDN9XGJ8XGJwb2tlID8oYmFsbHxkZXh8Y2VudGVyfGNlbnRyZSlcYg==' | base64 -d)"
# Battle phrases that are verbatim from the inspiration's battle text (sum of small similarities,
# see docs/legal/IP_PATENT_AUDIT.md). Also base64-encoded.
phrases="$(printf '%s' 'd2hhdCB3aWxsIFxTKyBkb1w/fGEgd2lsZCBcUysgYXBwZWFyZWR8d2FudHMgdG8gYmF0dGxlfCwgY29tZSBiYWNrIXxidXQgdGhlcmUgd2FzIG5vIHRhcmdldHxnb3QgYXdheSBzYWZlbHl8Y291bGRuLnQgZ2V0IGF3YXl8Z3JldyB0byBsZXZlbHxpdC5zIHN1cGVyIGVmZmVjdGl2ZXxpdC5zIG5vdCB2ZXJ5IGVmZmVjdGl2ZXxhIGNyaXRpY2FsIGhpdCF8d29uLnQgZ28gYW55IChoaWdoZXJ8bG93ZXIpfChyb3NlfGZlbGwpIHNoYXJwbHl8aXQgd29uLnQgaGF2ZSBhbnkgZWZmZWN0fHNjdXJyaWVkfGJsYWNrZWQgb3V0fGlzIGh1cnQgYnkgaXRzfGl0IGNhbi50IG1vdmU=' | base64 -d)"
fail=0

if git ls-files -z -- . ':!:AGENTS.md' ':!:LEGAL.md' ':!:addons/**' \
	| xargs -0 grep -I -n -i -P -- "$pattern" 2>/dev/null; then
	echo "::error::Banned franchise term found (lines above). See docs/IP_HYGIENE.md."
	fail=1
fi

if git ls-files -z -- . ':!:AGENTS.md' ':!:LEGAL.md' ':!:addons/**' \
	| xargs -0 grep -I -n -i -P -- "$phrases" 2>/dev/null; then
	echo "::error::Borrowed battle phrase found (lines above). Write our own wording. See docs/legal/IP_PATENT_AUDIT.md."
	fail=1
fi

# Patent-risk mechanics (LEGAL.md, Palworld suit): no throwing, gliding, riding, swipe-to-throw or a
# visible capture-odds meter in game code. Comment lines are skipped so docs can name what is banned.
patent='(throw|toss_|glid|parachute|swipe|flick_|capture_?(rate|chance|odds)|catch_?(rate|chance|odds)|(odds|chance)_?(meter|gauge|bar|label|ring)|ride_|riding|mount_)'
if git ls-files -z -- 'scripts/*.gd' 'scenes/*.tscn' \
	| xargs -0 grep -n -i -P -- "^(?!\s*#).*${patent}" 2>/dev/null; then
	echo "::error::Patent-risk mechanic in game code (lines above). See LEGAL.md."
	fail=1
fi

# German text: no terms from the franchise's German edition (move = "Attacke", critical hit,
# fainted, the run command, the storage box). Base64 like the lists above.
de_terms="$(printf '%s' 'QXR0YWNrZXxWb2xsdHJlZmZlcnxrYW1wZnVuZi5oaWd8IkZsdWNodCJ8IkJveCJ8Qm94IFwofFBvay4/bW9u' | base64 -d)"
if grep -n -i -P -- "$de_terms" data/i18n/de.json tools/i18n/*.py 2>/dev/null; then
	echo "::error::German text uses a term from the franchise's German edition (lines above). See docs/IP_HYGIENE.md."
	fail=1
fi

while IFS= read -r f; do
	case "$f" in
		*.gitkeep|*.import) continue ;;
	esac
	if ! grep -qF -- "$f" docs/ASSET_LOG.md; then
		echo "::error::$f is not listed in docs/ASSET_LOG.md (who made it, licence, date)."
		fail=1
	fi
done < <(git ls-files -- art audio)

# Every generator named in the asset log must exist (item 2637).
while IFS= read -r g; do
	if [ ! -f "$g" ]; then
		echo "::error::docs/ASSET_LOG.md names $g, which is not in the repo."
		fail=1
	fi
done < <(grep -oE "tools/[A-Za-z0-9_/]+\.py" docs/ASSET_LOG.md | sort -u)

if [ "$fail" -eq 0 ]; then
	echo "IP check OK"
fi
exit "$fail"
