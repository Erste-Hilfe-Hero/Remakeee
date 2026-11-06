#!/usr/bin/env bash
# Plays a tiny session against a running server the way the game does: anonymous sign-in, hello,
# save, load, a friend request between two accounts, then deletes both test accounts again.
# Usage: server/smoke_test.sh [URL]   (SMOKE_INSECURE=1 accepts a self-signed certificate)
set -euo pipefail
cd "$(dirname "$0")"
url="${1:-$(python3 -c 'import json;print(json.load(open("public/chimora.json"))["url"])')}"
anon="$(python3 -c 'import json;print(json.load(open("public/chimora.json"))["anon_key"])')"
fail() { echo "FAIL: $*" >&2; exit 1; }
k=""; [ "${SMOKE_INSECURE:-0}" = "1" ] && k="-k"
post() { # path token body
	curl -sS $k -X POST "$url$1" -H "apikey: $anon" -H "Authorization: Bearer $2" -H "Content-Type: application/json" -d "$3"
}
field() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval('d'+sys.argv[1]))" "$1"; }

sign_in() { post /auth/v1/signup "$anon" '{"data": {}}' | field '["access_token"]'; }
a="$(sign_in)" || fail "anonymous sign-in"
b="$(sign_in)" || fail "second sign-in"
[ -n "$a" ] && [ -n "$b" ] || fail "no token"

hello="$(post /rest/v1/rpc/hello "$a" '{"p_version": 1}')"
echo "$hello" | grep -q '"code"' || fail "hello: $hello"
code_a="$(echo "$hello" | field '["profile"]["code"]')"

put="$(post /rest/v1/rpc/save_put "$a" '{"p_slot": 1, "p_data": {"schema": 1, "version": 3, "party": [], "money": 5}, "p_summary": "Smoke", "p_base_rev": 0}')"
echo "$put" | grep -q '"ok": *true\|"ok":true' || fail "save_put: $put"
got="$(post /rest/v1/rpc/save_get "$b" '{"p_slot": 1}')"
echo "$got" | grep -q '"money"' && fail "another account could read the save: $got"
got="$(post /rest/v1/rpc/save_get "$a" '{"p_slot": 1}')"
echo "$got" | grep -q '"money"' || fail "save_get: $got"

post /rest/v1/rpc/hello "$b" '{"p_version": 1}' >/dev/null
req="$(post /rest/v1/rpc/friend_request "$b" "{\"p_code\": \"$code_a\"}")"
echo "$req" | grep -q '"ok": *true\|"ok":true' || fail "friend_request: $req"

# Tables must not be reachable directly.
raw="$(curl -sS $k "$url/rest/v1/saves?select=*" -H "apikey: $anon" -H "Authorization: Bearer $a")"
echo "$raw" | grep -q '"money"' && fail "saves table is readable: $raw"

for t in "$a" "$b"; do
	del="$(post /rest/v1/rpc/delete_account "$t" '{}')"
	echo "$del" | grep -q '"ok": *true\|"ok":true' || fail "delete_account: $del"
done

# The store pages (privacy, account deletion, support) must be reachable.
for page in datenschutz privacy konto-loeschen delete-account support impressum; do
	code="$(curl -sS $k -o /dev/null -w '%{http_code}' "$url/$page")"
	[ "$code" = "200" ] || fail "/$page answered $code"
done

echo "Smoke test OK against $url"
