class_name DataValidator
extends RefCounted
## Checks the authored JSON in data/ for broken references.
## Used by tools/validate_data.gd (CI) and by the GUT suite.

const VALID_KINDS: Array[String] = ["PHYSICAL", "FOCUS", "STATUS"]
const VALID_STATUSES: Array[String] = ["", "scorch", "soak", "root", "jolt", "daze", "drowse"]

## Returns a list of human-readable problems. Empty means the data is valid.
static func validate(spirlings_path: String = "res://data/spirlings.json", moves_path: String = "res://data/moves.json") -> PackedStringArray:
	var errors: PackedStringArray = []
	var moves_raw: Variant = _load_json(moves_path, errors)
	var spirlings_raw: Variant = _load_json(spirlings_path, errors)
	if not (moves_raw is Array and spirlings_raw is Array):
		errors.append("moves.json and spirlings.json must both be JSON arrays")
		return errors

	var move_names: Dictionary[String, bool] = {}
	for m: Variant in moves_raw:
		if not m is Dictionary:
			errors.append("moves.json: entry is not an object")
			continue
		var name: String = str(m.get("name", ""))
		if name.is_empty():
			errors.append("moves.json: move without a name")
		elif move_names.has(name):
			errors.append("moves.json: duplicate move '%s'" % name)
		move_names[name] = true
		if not _valid_element(str(m.get("element", ""))):
			errors.append("move '%s': unknown element '%s'" % [name, m.get("element", "")])
		if not str(m.get("kind", "")) in VALID_KINDS:
			errors.append("move '%s': unknown kind '%s'" % [name, m.get("kind", "")])
		if not str(m.get("status", "")) in VALID_STATUSES:
			errors.append("move '%s': unknown status '%s'" % [name, m.get("status", "")])
		if int(m.get("energy", -1)) < 0:
			errors.append("move '%s': missing or negative energy cost" % name)
		if m.has("effect") and not EffectRegistry.has_effect(StringName(str(m.effect))):
			errors.append("move '%s': unknown effect '%s'" % [name, m.effect])
		if m.has("stat") and not str(m.stat) in BattleRules.STAGE_STATS:
			errors.append("move '%s': unknown stat '%s'" % [name, m.stat])
		if m.has("target") and not str(m.target) in MoveData.TARGETS:
			errors.append("move '%s': unknown target '%s'" % [name, m.target])

	var species_names: Dictionary[String, bool] = {}
	var dex_ids: Dictionary[int, bool] = {}
	for s: Variant in spirlings_raw:
		if not s is Dictionary:
			errors.append("spirlings.json: entry is not an object")
			continue
		var sname: String = str(s.get("name", ""))
		species_names[sname] = true
		var dex: int = int(s.get("dex_id", 0))
		if dex_ids.has(dex):
			errors.append("spirling '%s': duplicate dex_id %d" % [sname, dex])
		dex_ids[dex] = true
	for s: Variant in spirlings_raw:
		if not s is Dictionary:
			continue
		var sname: String = str(s.get("name", ""))
		if s.has("trait") and not BattleRules.TRAITS.has(str(s.trait)):
			errors.append("spirling '%s': unknown trait '%s'" % [sname, s.trait])
		var elements: Variant = s.get("elements", [])
		if not elements is Array or (elements as Array).is_empty() or (elements as Array).size() > 2:
			errors.append("spirling '%s': needs 1 or 2 elements" % sname)
		else:
			for e: Variant in elements:
				if not _valid_element(str(e)):
					errors.append("spirling '%s': unknown element '%s'" % [sname, e])
		var evo: Variant = s.get("evolves_to")
		if evo != null and not species_names.has(str(evo)):
			errors.append("spirling '%s': evolves_to '%s' does not exist" % [sname, evo])
		if evo != null and int(s.get("evolve_level", 0)) <= 0 and str(s.get("evolve_item", "")).is_empty():
			errors.append("spirling '%s': evolves but has no evolve_level or evolve_item" % sname)
		var learnset: Variant = s.get("learnset", {})
		if learnset is Dictionary and (learnset as Dictionary).is_empty():
			errors.append("spirling '%s': empty learnset" % sname)
		if learnset is Dictionary:
			for lvl: Variant in learnset:
				if not str(lvl).is_valid_int():
					errors.append("spirling '%s': learnset level '%s' is not a number" % [sname, lvl])
				var entries: Variant = learnset[lvl]
				var list: Array = entries if entries is Array else [entries]
				for mv: Variant in list:
					if not move_names.has(str(mv)):
						errors.append("spirling '%s': learnset move '%s' does not exist" % [sname, mv])
		else:
			errors.append("spirling '%s': learnset must be an object (level -> move)" % sname)
	return errors

static func _valid_element(e: String) -> bool:
	return Elements.E.has(e)

static func _load_json(path: String, errors: PackedStringArray) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing file %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
