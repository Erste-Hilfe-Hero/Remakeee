class_name Dialogue
extends RefCounted
## Dialogue lookup. A reference "file/key" means data/dialogue/<file>.json -> <key>.
## Each entry is {"lines": [String], "action": optional String, "flag": optional String,
## "after_flag": optional {"flag": String, "lines": [...]}} so NPCs can change what they say.

const DIR: String = "res://data/dialogue/"

static var _cache: Dictionary[String, Dictionary] = {}

static func get_entry(ref: String) -> Dictionary:
	var parts: PackedStringArray = ref.split("/", false, 1)
	if parts.size() != 2:
		return {"lines": [ref]}
	var file: String = parts[0]
	if not _cache.has(file):
		var path: String = DIR + file + ".json"
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_cache[file] = raw if raw is Dictionary else {}
	var entry: Variant = _cache[file].get(parts[1])
	if entry is Array:
		return {"lines": entry}
	if entry is Dictionary:
		return entry
	return {"lines": ["..."]}

## The lines to show now, honouring "after_flag" variants.
static func lines_for(entry: Dictionary, flags: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var alt: Variant = entry.get("after_flag")
	var src: Variant = entry.get("lines", [])
	if alt is Dictionary and bool(flags.get(str(alt.get("flag", "")), false)):
		src = alt.get("lines", src)
	for l: Variant in src:
		out.append(str(l))
	return out
