class_name Lexicon
extends RefCounted
## The lexicon (plan area 2, items 680, 759): short entries the player collects. The ids live in
## GameState.records["lexicon"]; the texts in data/lexicon.json. Bonus goals grant entries
## (BattleGoals "lore"), and a Wayfarer with a "lexicon" key writes one down after its first win.

const PATH: String = "res://data/lexicon.json"

static var _cache: Dictionary = {}

static func all() -> Dictionary:
	if _cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if raw is Dictionary:
			for k: String in raw:
				if not k.begins_with("_") and raw[k] is Dictionary:
					_cache[k] = raw[k]
	return _cache

static func has_entry(id: String) -> bool:
	return all().has(id)

static func title(id: String) -> String:
	return str(all().get(id, {}).get("title", id))

static func text(id: String) -> String:
	return str(all().get(id, {}).get("text", ""))

## The collected entry ids in [param records], in the order they were found.
static func collected(records: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in records.get("lexicon", []):
		if has_entry(str(v)):
			out.append(str(v))
	return out

## Writes [param id] into [param records]. Returns false if it was already there or is unknown.
static func add(records: Dictionary, id: String) -> bool:
	if not has_entry(id):
		return false
	var l: Array = (records.get("lexicon", []) as Array).duplicate()
	if l.has(id):
		return false
	l.append(id)
	records["lexicon"] = l
	return true
