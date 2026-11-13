class_name KampfChecks
extends RefCounted
## Data checks for the battle tables that live in code (Kampf-Plan 1000, "Balance-Werkzeuge und
## Tests"): every Rift field and every boss with its second phase. DataValidator.validate() adds
## these errors, so the data job fails on a broken table before a battle ever meets it.

const BOSS_KEYS: Array[String] = ["label", "hp_per_ally", "max_actions", "text", "phase"]
const PHASE_KEYS: Array[String] = ["at", "stage", "field", "text"]
const FIELD_KEYS: Array[String] = ["label", "boost", "weaken", "intro", "blocks", "regen_element", "regen_div",
	"energy_element", "energy_gain", "bond_bonus"]
## Maps and tables that name a boss by id.
const BOSS_SOURCES: Array[String] = ["res://data/ideas200c.json"]
const MAP_DIR: String = "res://data/maps"

## Problems of BattleRules.FIELDS, one line each ("" lines never appear).
static func field_errors(fields: Dictionary = BattleRules.FIELDS) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in fields:
		var f: Dictionary = fields[id]
		for k: String in f:
			if not k in FIELD_KEYS:
				out.append("field '%s': unknown key '%s'" % [id, k])
		if str(f.get("label", "")).is_empty() or str(f.get("intro", "")).is_empty():
			out.append("field '%s': needs a label and an intro text" % id)
		for k: String in ["boost", "weaken", "regen_element", "energy_element"]:
			if f.has(k) and not Elements.E.has(str(f[k])):
				out.append("field '%s': %s '%s' is not an element" % [id, k, f[k]])
		if f.has("boost") and str(f.get("boost")) == str(f.get("weaken", "")):
			out.append("field '%s': boosts and weakens the same element" % id)
		for st: Variant in f.get("blocks", []):
			if not StatusRules.exists(str(st)):
				out.append("field '%s': blocks unknown status '%s'" % [id, st])
		if f.has("regen_element") and int(f.get("regen_div", 0)) <= 0:
			out.append("field '%s': regen_element needs a regen_div above 0" % id)
		# Field extras of RiftFields (KAMPF_PLAN_1000 items 345, 349).
		if f.has("energy_element") and int(f.get("energy_gain", 1)) <= 0:
			out.append("field '%s': energy_element needs an energy_gain above 0" % id)
		if f.has("bond_bonus") and (float(f.bond_bonus) <= 0.0 or float(f.bond_bonus) > 0.5):
			out.append("field '%s': bond_bonus must lie in (0, 0.5]" % id)
	return out

## Problems of BattleRules.BOSSES and its phases.
static func boss_errors(bosses: Dictionary = BattleRules.BOSSES, fields: Dictionary = BattleRules.FIELDS) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in bosses:
		var b: Dictionary = bosses[id]
		for k: String in b:
			if not k in BOSS_KEYS:
				out.append("boss '%s': unknown key '%s'" % [id, k])
		if str(b.get("label", "")).is_empty() or str(b.get("text", "")).is_empty():
			out.append("boss '%s': needs a label and an intro text" % id)
		if float(b.get("hp_per_ally", 0.0)) <= 0.0:
			out.append("boss '%s': hp_per_ally must be above 0" % id)
		if int(b.get("max_actions", 0)) < 1:
			out.append("boss '%s': max_actions must be at least 1" % id)
		var p: Variant = b.get("phase", {})
		if not p is Dictionary:
			out.append("boss '%s': phase must be an object" % id)
			continue
		var ph: Dictionary = p
		if ph.is_empty():
			continue
		for k: String in ph:
			if not k in PHASE_KEYS:
				out.append("boss '%s': phase has unknown key '%s'" % [id, k])
		var at: float = float(ph.get("at", 0.0))
		if at <= 0.0 or at >= 1.0:
			out.append("boss '%s': phase 'at' must lie between 0 and 1" % id)
		if str(ph.get("text", "")).is_empty():
			out.append("boss '%s': phase needs a text" % id)
		var st: Variant = ph.get("stage", {})
		if st is Dictionary:
			for stat: Variant in st:
				if not str(stat) in BattleRules.STAGE_STATS:
					out.append("boss '%s': phase raises unknown stat '%s'" % [id, stat])
				elif absi(int(st[stat])) > BattleRules.STAGE_MAX:
					out.append("boss '%s': phase stage %s is out of range" % [id, stat])
		if ph.has("field") and not fields.has(str(ph.field)):
			out.append("boss '%s': phase field '%s' does not exist" % [id, ph.field])
	for at_ref: Array in boss_refs():
		if not bosses.has(str(at_ref[1])):
			out.append("%s: boss '%s' does not exist" % [at_ref[0], at_ref[1]])
	return out

## Every [where, boss id] the maps and tables name.
static func boss_refs() -> Array[Array]:
	var out: Array[Array] = []
	var paths: Array[String] = BOSS_SOURCES.duplicate()
	var dir := DirAccess.open(MAP_DIR)
	if dir != null:
		for f: String in dir.get_files():
			if f.ends_with(".json"):
				paths.append(MAP_DIR.path_join(f))
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_collect(raw, path.get_file(), out)
	return out

static func _collect(v: Variant, where: String, out: Array[Array]) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		if d.get("boss") is String:
			out.append([where, str(d.boss)])
		for k: Variant in d:
			_collect(d[k], where, out)
	elif v is Array:
		for x: Variant in v:
			_collect(x, where, out)
