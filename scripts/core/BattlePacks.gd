class_name BattlePacks
extends RefCounted
## Battle data packs (KAMPF_PLAN_1000 items 991, 992): community battle content as data, never code.
## A pack is "<name>.kpack.json" plus "<name>.kpack.json.sig" next to it. The pack may add Rift
## fields and bosses to data/battle_tables.json and carry ready battle setups for the battle editor
## (tools/battle_editor). It may never change an existing entry, name a file, a path or a script.
## The .sig file is {"key": id, "sig": base64}: an RSA SHA-256 signature over the exact bytes of
## the .kpack.json, made by tools/battle_pack.py. Only keys listed in data/battle_pack_keys.json
## are trusted, so an unsigned or edited pack is refused before a single value is read.

const FORMAT: int = 1
const KEYS_PATH: String = "res://data/battle_pack_keys.json"
const MAX_BYTES: int = 262144
const TOP_KEYS: Array[String] = ["format", "id", "name", "author", "fields", "bosses", "battles"]
## Battle setup keys (see tools/battle_editor/BattleSetup.gd).
const SETUP_KEYS: Array[String] = ["name", "player", "foe", "level", "field", "rule", "boss", "seed", "ai", "front", "wild"]
const CODE_ENDINGS: Array[String] = [".gd", ".gdc", ".cs", ".tscn", ".scn", ".tres", ".res", ".so", ".dll", ".dylib", ".pck", ".zip"]

## The trusted public keys: {id: PEM}.
static func trusted_keys() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEYS_PATH))
	var keys: Variant = parsed.get("keys", {}) if parsed is Dictionary else {}
	return keys if keys is Dictionary else {}

## True when [param sig_b64] is a signature of [param bytes] by the PEM public key [param pem].
static func signed_by(bytes: PackedByteArray, sig_b64: String, pem: String) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	var sig: PackedByteArray = Marshalls.base64_to_raw(sig_b64)
	if sig.is_empty():
		return false
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return Crypto.new().verify(HashingContext.HASH_SHA256, h.finish(), sig, key)

## Reads and checks the pack at [param path] against [param keys] (trusted_keys() when empty).
## {"pack": Dictionary, "key": id, "errors": PackedStringArray}; the pack is {} on any error.
static func read(path: String, keys: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"pack": {}, "key": "", "errors": PackedStringArray()}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		out.errors.append("pack %s: missing or empty" % path.get_file())
		return out
	if bytes.size() > MAX_BYTES:
		out.errors.append("pack %s: larger than %d bytes" % [path.get_file(), MAX_BYTES])
		return out
	var sig: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".sig")) if FileAccess.file_exists(path + ".sig") else null
	if not sig is Dictionary:
		out.errors.append("pack %s: no signature file" % path.get_file())
		return out
	var trusted: Dictionary = keys if not keys.is_empty() else trusted_keys()
	var key_id: String = str(sig.get("key", ""))
	if not trusted.has(key_id):
		out.errors.append("pack %s: key '%s' is not trusted" % [path.get_file(), key_id])
		return out
	if not signed_by(bytes, str(sig.get("sig", "")), str(trusted[key_id])):
		out.errors.append("pack %s: signature does not match" % path.get_file())
		return out
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		out.errors.append("pack %s: not a JSON object" % path.get_file())
		return out
	var errs: PackedStringArray = errors(BattleRules._whole(parsed))
	if not errs.is_empty():
		out.errors = errs
		return out
	out.pack = BattleRules._whole(parsed)
	out.key = key_id
	return out

## Problems of [param pack] against the tables in play, one line each.
static func errors(pack: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if int(pack.get("format", 0)) != FORMAT:
		out.append("format must be %d" % FORMAT)
	if str(pack.get("id", "")).is_empty():
		out.append("needs an id")
	for k: Variant in pack:
		if not str(k) in TOP_KEYS:
			out.append("unknown key '%s' (only data tables, no code)" % k)
	_no_code(pack, "", out)
	var fields: Dictionary = BattleRules.FIELDS.duplicate()
	for table: String in ["fields", "bosses"]:
		var t: Variant = pack.get(table, {})
		if not t is Dictionary:
			out.append("%s must be an object" % table)
			continue
		var have: Dictionary = BattleRules.FIELDS if table == "fields" else BattleRules.BOSSES
		for id: Variant in t:
			if have.has(str(id)):
				out.append("%s '%s' already exists; a pack only adds" % [table, id])
			if not t[id] is Dictionary:
				out.append("%s '%s' must be an object" % [table, id])
	if not out.is_empty():
		return out
	fields.merge(pack.get("fields", {}))
	out.append_array(KampfChecks.field_errors(pack.get("fields", {})))
	var bosses: Dictionary = pack.get("bosses", {})
	for id: String in bosses:
		var one: Dictionary = {id: bosses[id]}
		for e: String in KampfChecks.boss_errors(one, fields):
			if e.begins_with("boss '"):
				out.append(e)
	var battles: Variant = pack.get("battles", [])
	if not battles is Array:
		out.append("battles must be a list")
	else:
		for b: Variant in battles:
			if not b is Dictionary:
				out.append("every battle must be an object")
				continue
			for k: Variant in b:
				if not str(k) in SETUP_KEYS:
					out.append("battle '%s': unknown key '%s'" % [b.get("name", "?"), k])
	return out

## Strings that name a path, a link or a script file.
static func _no_code(v: Variant, where: String, out: PackedStringArray) -> void:
	if v is String:
		var s: String = (v as String).to_lower()
		if "://" in s or s.begins_with("/") or s.begins_with("res:") or s.begins_with("user:"):
			out.append("%s: no paths or links in a data pack" % where)
		for e: String in CODE_ENDINGS:
			if s.ends_with(e):
				out.append("%s: no code or files in a data pack" % where)
	elif v is Dictionary:
		for k: Variant in v:
			_no_code(str(k), where + "/" + str(k), out)
			_no_code(v[k], where + "/" + str(k), out)
	elif v is Array:
		for i: int in (v as Array).size():
			_no_code(v[i], "%s[%d]" % [where, i], out)

## Adds the fields and bosses of a checked [param pack] to BattleRules. BattleRules.reload_tables()
## takes them out again.
static func apply(pack: Dictionary) -> void:
	var fields: Dictionary = pack.get("fields", {})
	for id: String in fields:
		BattleRules.FIELDS[id] = fields[id]
	var bosses: Dictionary = pack.get("bosses", {})
	for id: String in bosses:
		BattleRules.BOSSES[id] = bosses[id]

## Every pack in [param dir] that reads cleanly, applied in name order. Returns the errors of the rest.
static func load_dir(dir: String, keys: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	var names: PackedStringArray = DirAccess.get_files_at(dir)
	names.sort()
	for f: String in names:
		if not f.ends_with(".kpack.json"):
			continue
		var r: Dictionary = read(dir.path_join(f), keys)
		if (r.pack as Dictionary).is_empty():
			out.append_array(r.errors)
		else:
			apply(r.pack)
	return out
