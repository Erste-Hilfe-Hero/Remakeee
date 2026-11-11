class_name LiveContent
extends RefCounted
## Live content (docs/LIVE_CONTENT.md): signed data patches from the server, so shop offers,
## balance values, the type chart, events, texts and news change without a store release.
## - Data only. A patch is JSON with the keys in ALLOWED_KEYS; anything that names a script,
##   scene or resource pack is refused (App Store and Play rules forbid downloading code).
## - The body is signed with RSA-SHA256 by tools/live/publish.py. The game checks the
##   signature against PUBLIC_KEY before it uses or caches a patch.
## - Order of trust: a verified cache in user://, otherwise the bundled data/live_content.json.

const PUBLIC_KEY: String = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR130v7/1dKmNC2CGEyE
lDNKlWV7LZAiYxnEokQcqLUTL4eLSUqZ9gAVwRDVjYmHKEGrdsoc1Bqu51+uzf6f
j5uBqAKRU4yManRs+tuKV2iDqy5sEeqbzGm0ElF/PdO2pk8vhWFTVjnXKVr5Wc7p
vz/qVps6Js0SojXDDuT31kQWZBBtQ3UfNShkRtMgBhlao0xKB4wxdqh6/fRCtQGW
FMDadZqdWvEV1Pl4Irlf6lAN9c42kbP0vPJwiWKk/70O+0AGci+huimdeyk0MCJM
jp6qmPyUoJj8+KP3mFaJ3u1MbLD8OXLimzAritSujUVObC8tHFtwf4O+pF/7q2AY
bwIDAQAB
-----END PUBLIC KEY-----
"""
const BUNDLED_PATH: String = "res://data/live_content.json"
const CACHE_PATH: String = "user://live_content.json"
const ALLOWED_KEYS: Array[String] = ["version", "requires", "min_client", "latest", "shop", "balance",
	"type_chart", "events", "texts", "news"]
## Strings that point at code or packs. A patch containing one is refused as a whole.
const CODE_MARKERS: Array[String] = [".gd", ".gdc", ".gde", ".pck", ".zip", ".so", ".dylib", ".dll",
	".dex", ".jar", ".tscn", ".scn", ".tres", ".res", "res://", "user://", "extends ", "func "]
const PLATFORMS: Array[String] = ["ios", "android"]

class Events extends RefCounted:
	signal changed(version: int)

static var events: Events = Events.new()
## The patch in use (bundled or a verified download).
static var data: Dictionary = {}
static var _loaded: bool = false

## Parsed JSON or null, without engine errors for bad input (it comes from outside).
static func _json(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null

# --- Checking ------------------------------------------------------------------------------

## True when [param signature_b64] is a valid RSA-SHA256 signature of [param body].
static func verify(body: String, signature_b64: String, public_pem: String = PUBLIC_KEY) -> bool:
	if body.is_empty() or signature_b64.strip_edges().is_empty():
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_pem, true) != OK:
		return false
	var sig: PackedByteArray = Marshalls.base64_to_raw(signature_b64.strip_edges())
	if sig.is_empty():
		return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, body.sha256_buffer(), sig, key)

## The patch in [param body] if it is well-formed data, otherwise {}.
static func parse(body: String) -> Dictionary:
	var v: Variant = _json(body)
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	for k: Variant in d.keys():
		if not str(k) in ALLOWED_KEYS:
			return {}
	var ver: Variant = d.get("version")
	if not (ver is float or ver is int) or int(ver) < 1:
		return {}
	if has_code(d):
		return {}
	return d

## True if anything inside [param v] (keys or values) looks like code or a code path.
static func has_code(v: Variant) -> bool:
	if v is Dictionary:
		for k: Variant in v:
			if has_code(str(k)) or has_code(v[k]):
				return true
	elif v is Array:
		for x: Variant in v:
			if has_code(x):
				return true
	elif v is String:
		var s: String = (v as String).to_lower()
		for m: String in CODE_MARKERS:
			if s.contains(m) and not _is_web_link(s):
				return true
	return false

## News links (https://...) may end in anything; they open in the browser, not in the game.
static func _is_web_link(s: String) -> bool:
	return s.begins_with("https://") and not s.contains(" ")

## The verified patch from [param body] and [param signature], or {} if anything is wrong or
## it needs a newer game than [param client_version] ("requires").
static func accept(body: String, signature: String, client_version: String, public_pem: String = PUBLIC_KEY) -> Dictionary:
	if not verify(body, signature, public_pem):
		return {}
	var d: Dictionary = parse(body)
	if d.is_empty():
		return {}
	if compare_versions(client_version, str(d.get("requires", "0"))) < 0:
		return {}
	return d

# --- Versions ------------------------------------------------------------------------------

## -1, 0 or 1 for version names like "1.10.2" (missing parts count as 0, junk as 0).
static func compare_versions(a: String, b: String) -> int:
	var pa: PackedStringArray = a.strip_edges().split(".")
	var pb: PackedStringArray = b.strip_edges().split(".")
	for i: int in maxi(pa.size(), pb.size()):
		var x: int = pa[i].to_int() if i < pa.size() else 0
		var y: int = pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0

## "ios", "android" or "" (desktop, browser test build).
static func platform() -> String:
	match OS.get_name():
		"iOS": return "ios"
		"Android": return "android"
	return ""

## The per-platform version in field [param field] ("min_client" or "latest"), "0" if unset.
## iOS and Android are kept apart: their builds differ, one shared number would lock one out.
static func platform_version(content: Dictionary, field: String, plat: String) -> String:
	var f: Variant = content.get(field)
	if f is Dictionary and plat in PLATFORMS:
		return str((f as Dictionary).get(plat, "0"))
	return "0"

## "required", "optional" or "none" for a game at [param client] on [param plat].
## [param store_version] (the store's own answer, iOS) wins over the patch's "latest" when newer.
static func update_state(content: Dictionary, plat: String, client: String, store_version: String = "") -> String:
	if plat.is_empty():
		return "none"
	if compare_versions(client, platform_version(content, "min_client", plat)) < 0:
		return "required"
	var latest: String = platform_version(content, "latest", plat)
	if not store_version.is_empty() and compare_versions(store_version, latest) > 0:
		latest = store_version
	return "optional" if compare_versions(client, latest) < 0 else "none"

## The version from an iTunes lookup answer, "" if there is none.
static func itunes_version(json_text: String) -> String:
	var v: Variant = _json(json_text)
	if not v is Dictionary or not (v as Dictionary).get("results") is Array:
		return ""
	var results: Array = v.results
	if results.is_empty() or not results[0] is Dictionary:
		return ""
	return str(results[0].get("version", ""))

# --- Storage -------------------------------------------------------------------------------

## Loads the cache if it is still valid, otherwise the bundled patch. Safe to call often.
static func ensure_loaded(client_version: String) -> void:
	if _loaded:
		return
	_loaded = true
	data = load_bundled()
	var cached: Dictionary = load_cache(CACHE_PATH, client_version)
	if int(cached.get("version", 0)) > int(data.get("version", 0)):
		data = cached

static func load_bundled(path: String = BUNDLED_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return parse(FileAccess.get_file_as_string(path))

## The cached patch, checked again (a changed file is ignored).
static func load_cache(path: String, client_version: String, public_pem: String = PUBLIC_KEY) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = _json(FileAccess.get_file_as_string(path))
	if not v is Dictionary:
		return {}
	return accept(str(v.get("body", "")), str(v.get("signature", "")), client_version, public_pem)

## Takes a live_content_get answer. Returns true when a newer verified patch is now in use.
static func take(answer: Variant, client_version: String, path: String = CACHE_PATH, public_pem: String = PUBLIC_KEY) -> bool:
	if not answer is Dictionary or not answer.has("body"):
		return false
	if int(answer.get("version", 0)) <= version():
		return false
	var body: String = str(answer.body)
	var sig: String = str(answer.get("signature", ""))
	var d: Dictionary = accept(body, sig, client_version, public_pem)
	if d.is_empty() or int(d.version) <= version():
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"body": body, "signature": sig}))
		f.close()
	data = d
	events.changed.emit(version())
	return true

static func version() -> int:
	return int(data.get("version", 0))

## Back to nothing loaded (tests).
static func reset() -> void:
	data = {}
	_loaded = false

# --- Reading -------------------------------------------------------------------------------

## A whole section ("shop", "balance", "type_chart", "events"), or [param fallback].
static func section(name: String, fallback: Variant = null) -> Variant:
	return data.get(name, fallback)

## A text from "texts": {"<lang>": {"<key>": "..."}}. Current language, then English, then
## [param fallback].
static func text(key: String, fallback: String = "") -> String:
	var t: Variant = data.get("texts")
	if not t is Dictionary:
		return fallback
	for lang: String in [Loc.language(), "en"]:
		if t.get(lang) is Dictionary and t[lang].has(key):
			return str(t[lang][key])
	return fallback

## A field that is either plain text or {"en": ..., "de": ...}.
static func localized(v: Variant) -> String:
	if v is Dictionary:
		var d: Dictionary = v
		return str(d.get(Loc.language(), d.get("en", "")))
	return "" if v == null else str(v)

## News entries, newest first: [{"title", "body", "url", "date"}] with texts in the current language.
static func news() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n: Variant = data.get("news")
	if not n is Array:
		return out
	for e: Variant in n:
		if not e is Dictionary:
			continue
		var url: String = str(e.get("url", ""))
		out.append({"title": localized(e.get("title")), "body": localized(e.get("body")),
			"url": url if url.begins_with("https://") else "", "date": str(e.get("date", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.date > b.date)
	return out
