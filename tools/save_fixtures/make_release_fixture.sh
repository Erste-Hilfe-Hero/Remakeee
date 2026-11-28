#!/usr/bin/env bash
# Writes tests/fixtures/saves/releases/{save,settings}_<version>.json with the code of a shipped
# release, so test_save_releases.gd loads exactly the shape players have on their phones.
#   tools/save_fixtures/make_release_fixture.sh <version> <commit> <difficulty 0-3>
# Without arguments it rebuilds every release below. When a release ships, add its line here and
# its version to RELEASES in tests/unit/test_save_releases.gd.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tests/fixtures/saves/releases"
GODOT="${GODOT:-godot}"

one() {
	local version="$1" commit="$2" difficulty="$3"
	local tmp
	tmp="$(mktemp -d)"
	trap 'git -C "$ROOT" worktree remove --force "$tmp/src" >/dev/null 2>&1 || true; rm -rf "$tmp"' RETURN
	git -C "$ROOT" worktree add --detach "$tmp/src" "$commit" >/dev/null
	cp "$ROOT/tools/save_fixtures/release_journey.gd" "$tmp/src/release_journey.gd"
	mkdir -p "$tmp/data"
	# Own user:// so the run never touches the saves or settings of this machine.
	XDG_DATA_HOME="$tmp/data" "$GODOT" --headless --path "$tmp/src" --import >/dev/null 2>&1 || true
	XDG_DATA_HOME="$tmp/data" "$GODOT" --headless --path "$tmp/src" -s res://release_journey.gd -- \
		"$difficulty" "$OUT" "$version"
	test -s "$OUT/save_$version.json"
}

if [ "$#" -eq 3 ]; then
	one "$1" "$2" "$3"
	exit 0
fi
# version, release commit (store build), difficulty the journey starts on
one 1.1.0 a0275dd07 3   # chore: version 1.1.0 for iOS and Android, Rift-Born
one 1.2.0 7a45ea1ea 2   # 1.2.0 Google Play notes (#560), Veteran
one 1.3.0 f04f1391f 0   # chore(release): version 1.3.0 (3), Story
one 1.3.1 295fbe8a8 2   # chore(release): Chimora 1.3.1, Veteran
