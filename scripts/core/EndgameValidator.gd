class_name EndgameValidator
extends RefCounted
## Data check for the endgame files (plan area 8, items 3517 and 3518), run by
## tools/validate_data.gd: every item named in data/endgame.json and data/events.json exists in
## data/items.json, ids are unique inside each list, and every reward amount is above 0.

const FILES: Array[String] = ["res://data/endgame.json", "res://data/events.json"]
## Keys that hold one item id, or a list of item ids.
const ITEM_KEYS: Array[String] = ["item"]
const ITEM_LIST_KEYS: Array[String] = ["items", "gifts"]
## Keys that hold a reward or price amount; each one must be above 0.
const REWARD_KEYS: Array[String] = ["waymarks", "reward", "ribbons", "coins", "amount", "price"]

static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var items: Dictionary = {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	if raw is Array:
		for it: Variant in raw:
			if it is Dictionary:
				items[str((it as Dictionary).get("id", ""))] = true
	for path: String in FILES:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if d == null:
			errors.append("%s: not readable JSON" % path)
			continue
		_walk(d, path.get_file(), items, errors)
	return errors

static func _is_number(v: Variant) -> bool:
	return v is int or v is float

static func _walk(v: Variant, where: String, items: Dictionary, errors: PackedStringArray) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d:
			var key: String = str(k)
			var at: String = where + "." + key
			var x: Variant = d[k]
			if key in ITEM_KEYS and x is String and str(x) != "" and not items.has(str(x)):
				errors.append("%s: unknown item '%s'" % [at, x])
			if key in ITEM_LIST_KEYS and x is Array:
				for y: Variant in x:
					if y is String and not items.has(str(y)):
						errors.append("%s: unknown item '%s'" % [at, y])
			if key in REWARD_KEYS and _is_number(x) and float(x) <= 0.0:
				errors.append("%s: amount %s is not above 0" % [at, str(x)])
			_walk(x, at, items, errors)
	elif v is Array:
		var seen: Dictionary = {}
		var list: Array = v
		for i: int in list.size():
			var y: Variant = list[i]
			if y is Dictionary and (y as Dictionary).has("id"):
				var id: String = str((y as Dictionary).id)
				if seen.has(id):
					errors.append("%s: id '%s' twice" % [where, id])
				seen[id] = true
			_walk(y, "%s[%d]" % [where, i], items, errors)
