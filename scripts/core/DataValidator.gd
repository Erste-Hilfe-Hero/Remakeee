class_name DataValidator
extends RefCounted
## Checks the authored JSON in data/ for broken references.
## Used by tools/validate_data.gd (CI) and by the GUT suite.

const VALID_KINDS: Array[String] = ["PHYSICAL", "FOCUS", "STATUS"]
const VALID_STATUSES: Array[String] = ["", "scorch", "soak", "root", "jolt", "daze", "drowse"]

## Returns a list of human-readable problems. Empty means the data is valid.
static func validate(spirlings_path: String = "res://data/spirlings.json", moves_path: String = "res://data/moves.json", encounters_path: String = "res://data/encounters.json") -> PackedStringArray:
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
		if m.has("field") and not BattleRules.FIELDS.has(str(m.field)):
			errors.append("move '%s': unknown field '%s'" % [name, m.field])
		if m.has("target") and not str(m.target) in MoveData.TARGETS:
			errors.append("move '%s': unknown target '%s'" % [name, m.target])
		if m.has("vs_status") and not (str(m.vs_status) in ["*", "stage_down"] or StatusRules.exists(str(m.vs_status))):
			errors.append("move '%s': unknown vs_status '%s'" % [name, m.vs_status])
		if int(m.get("priority", 0)) < -1 or int(m.get("priority", 0)) > 1:
			errors.append("move '%s': priority must be -1, 0 or +1" % name)
		if m.has("stats"):
			if not m.stats is Dictionary:
				errors.append("move '%s': stats must be an object (stat -> amount)" % name)
			else:
				for st: Variant in m.stats:
					if not str(st) in BattleRules.STAGE_STATS:
						errors.append("move '%s': unknown stat '%s' in stats" % [name, st])
		if m.has("cooldown") and int(m.cooldown) < 0:
			errors.append("move '%s': negative cooldown" % name)
		if m.has("self_stages"):
			if not m.self_stages is Dictionary:
				errors.append("move '%s': self_stages must be an object (stat -> amount)" % name)
			else:
				for st: Variant in m.self_stages:
					if not str(st) in BattleRules.STAGE_STATS:
						errors.append("move '%s': unknown stat '%s' in self_stages" % [name, st])
		if m.has("stage_chance") and (float(m.stage_chance) <= 0.0 or float(m.stage_chance) > 1.0):
			errors.append("move '%s': stage_chance must be in (0, 1]" % name)

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
		_check_species_fields(s, sname, species_names, errors)
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
	_check_reachable(spirlings_raw, encounters_path, errors)
	return errors

## Plan area 1, items 2, 3, 131 and 336: rarity, region, origin, unfold paths, bond rate band.
static func _check_species_fields(s: Dictionary, sname: String, species_names: Dictionary, errors: PackedStringArray) -> void:
	var rarity: String = str(s.get("rarity", ""))
	if not rarity in SpirlingData.RARITIES:
		errors.append("spirling '%s': unknown rarity '%s'" % [sname, rarity])
	elif s.has("bond_rate"):
		var band: Vector2 = SpirlingData.BOND_RATE_BANDS[rarity]
		var br: float = float(s.bond_rate)
		if br < band.x - 0.0001 or br > band.y + 0.0001:
			errors.append("spirling '%s': bond_rate %.2f outside %s band %.2f-%.2f" % [sname, br, rarity, band.x, band.y])
	if not str(s.get("region", "")) in SpirlingData.REGIONS:
		errors.append("spirling '%s': unknown region '%s'" % [sname, s.get("region", "")])
	var motif: Variant = s.get("cry_motif", [])
	if not motif is Array or (motif as Array).size() != 2 or int(motif[0]) == int(motif[1]) \
			or int(motif[0]) < 0 or int(motif[1]) < 0 or int(motif[0]) >= BondEcho.MARKS or int(motif[1]) >= BondEcho.MARKS:
		errors.append("spirling '%s': cry_motif must be two different marks 0..%d" % [sname, BondEcho.MARKS - 1])
	var hint: String = str(s.get("keepsake_hint", ""))
	if hint.is_empty() or not _held_items().has(hint):
		errors.append("spirling '%s': keepsake_hint '%s' is not an item a Spirling can hold" % [sname, hint])
	if not str(s.get("role", "")) in SpirlingData.ROLES:
		errors.append("spirling '%s': unknown role '%s'" % [sname, s.get("role", "")])
	if str(s.get("origin", "")).strip_edges().is_empty():
		errors.append("spirling '%s': empty origin" % sname)
	if str(s.get("line_id", "")).is_empty():
		errors.append("spirling '%s': no line_id" % sname)
	if not s.has("trait") or not BattleRules.TRAITS.has(str(s.trait)):
		errors.append("spirling '%s': needs a trait from BattleRules.TRAITS" % sname)
	var unfold: Variant = s.get("unfold", [])
	if not unfold is Array:
		errors.append("spirling '%s': unfold must be a list" % sname)
		return
	for p: Variant in unfold:
		if not p is Dictionary:
			errors.append("spirling '%s': unfold entry is not an object" % sname)
			continue
		var to: String = str(p.get("to", ""))
		if not species_names.has(to):
			errors.append("spirling '%s': unfolds into unknown '%s'" % [sname, to])
		var rule: String = str(p.get("rule", ""))
		if not rule in SpirlingData.UNFOLD_RULES:
			errors.append("spirling '%s': unknown unfold rule '%s'" % [sname, rule])
		elif rule in ["ring", "map_pages", "echo_streak"] and int(p.get("value", 0)) <= 0:
			errors.append("spirling '%s': unfold rule '%s' needs a positive value" % [sname, rule])
		elif rule in ["item", "mended", "time"] and str(p.get("value", "")).is_empty():
			errors.append("spirling '%s': unfold rule '%s' needs a value" % [sname, rule])

## Item 8 and 133: every kind can be met somewhere (an encounter table, as a starting partner,
## by unfolding, or a fixed meeting named in "met"), and ancient kinds never in random tables.
static func _check_reachable(spirlings_raw: Array, encounters_path: String, errors: PackedStringArray) -> void:
	var reach: Dictionary = {}
	var rarity: Dictionary = {}
	for sp: String in Database.STARTERS:
		reach[sp] = true
	for s: Variant in spirlings_raw:
		if s is Dictionary:
			rarity[str(s.get("name", ""))] = str(s.get("rarity", ""))
			if not str(s.get("met", "")).is_empty():
				reach[str(s.name)] = true
	var enc: Variant = _load_json(encounters_path, errors) if FileAccess.file_exists(encounters_path) else {}
	if enc is Dictionary:
		for area: Variant in enc:
			for sp: Variant in (enc[area] as Dictionary).get("spawns", []):
				var n: String = str((sp as Dictionary).get("species", ""))
				reach[n] = true
				if str(rarity.get(n, "")) == "ancient":
					errors.append("encounter table '%s': ancient '%s' must only be met in a fixed meeting" % [area, n])
	var grew: bool = true
	while grew:
		grew = false
		for s: Variant in spirlings_raw:
			if not s is Dictionary or not reach.has(str(s.get("name", ""))):
				continue
			for p: Dictionary in Database.unfold_paths(s):
				var to: String = str(p.get("to", ""))
				if not reach.has(to):
					reach[to] = true
					grew = true
	for s: Variant in spirlings_raw:
		if s is Dictionary and not reach.has(str(s.get("name", ""))):
			errors.append("spirling '%s': can't be met anywhere (no encounter, starter, unfold or fixed meeting)" % s.get("name", ""))

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

## Ids of items a Spirling can hold (items.json entries with a "held" block).
static func _held_items() -> Dictionary:
	var out: Dictionary = {}
	var path: String = "res://data/items.json"
	if not FileAccess.file_exists(path):
		return out
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var list: Array = raw if raw is Array else ((raw as Dictionary).values() if raw is Dictionary else [])
	for it: Variant in list:
		if it is Dictionary and (it as Dictionary).has("held"):
			out[str((it as Dictionary).get("id", ""))] = true
	return out
