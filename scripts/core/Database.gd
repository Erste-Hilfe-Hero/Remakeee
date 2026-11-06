class_name Database
extends RefCounted
## Loads the authored JSON in data/ into typed SpirlingData / MoveData / item resources.

const SPIRLINGS_PATH: String = "res://data/spirlings.json"
const MOVES_PATH: String = "res://data/moves.json"
const ITEMS_PATH: String = "res://data/items.json"
## The three partners offered at the start of a new game.
## The three that fly to the lighthouse lamp on the storm night: ember, spark and wick light.
## Deliberately not an element triangle (none of them beats the next in a ring).
const STARTERS: Array[String] = ["Kindlop", "Zippit", "Wickit"]

static var spirlings: Dictionary[String, SpirlingData] = {}
static var moves: Dictionary[String, MoveData] = {}
## Item definitions keyed by id. Values are plain Dictionaries from items.json.
static var items: Dictionary[String, Dictionary] = {}

## Loads everything once. Safe to call repeatedly.
static func load_all() -> void:
	if not spirlings.is_empty():
		return
	_load_moves()
	_load_spirlings()
	_load_items()

## Drops the cache and loads again (tests, hot reload).
static func reload_data() -> void:
	spirlings.clear()
	moves.clear()
	items.clear()
	load_all()

static func species(species_name: String) -> SpirlingData:
	load_all()
	return spirlings.get(species_name)

## The form that unfurls into [param sd], or null for a first form.
static func earlier_form(sd: SpirlingData) -> SpirlingData:
	load_all()
	if sd == null:
		return null
	for other: SpirlingData in spirlings.values():
		if other.evolves_to == sd:
			return other
	return null

static func move(move_name: String) -> MoveData:
	load_all()
	return moves.get(move_name)

static func item(item_id: String) -> Dictionary:
	load_all()
	return items.get(item_id, {})

static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _load_moves() -> void:
	var raw: Variant = _read(MOVES_PATH)
	if not raw is Array:
		push_error("Database: cannot read %s" % MOVES_PATH)
		return
	for m: Dictionary in raw:
		var md: MoveData = parse_move(m)
		moves[md.move_name] = md

## Builds one move from its moves.json entry (also used by tests for moves not in the data).
static func parse_move(m: Dictionary) -> MoveData:
	var md := MoveData.new()
	md.move_name = m.name
	md.element = Elements.E[m.element]
	md.kind = MoveData.Kind[m.kind]
	md.power = int(m.power)
	md.accuracy = float(m.accuracy)
	md.energy_cost = int(m.energy)
	md.priority = int(m.get("priority", 0))
	md.status_effect = str(m.get("status", ""))
	md.status_chance = float(m.get("status_chance", 0.0))
	if not md.status_effect.is_empty():
		md.effects.append({"id": &"inflict_status", "status": md.status_effect, "chance": md.status_chance})
	if m.has("stat"):
		md.effects.append({"id": &"stat_change", "stat": str(m.stat), "amount": int(m.get("stages", 1)), "self": bool(m.get("self", true)), "chance": float(m.get("stage_chance", m.get("stat_chance", 1.0)))})
	md.overcharge = bool(m.get("overcharge", false))
	md.target = str(m.get("target", "single"))
	if m.has("field"):
		md.effects.append({"id": &"set_field", "field": str(m.field)})
	if m.has("effect"):
		md.effects.append({"id": StringName(m.effect), "amount": float(m.get("effect_amount", 0.0))})
	md.cooldown = int(m.get("cooldown", 0))
	if m.has("vs_status"):
		md.effects.append({"id": &"bonus_vs_status", "vs_status": str(m.vs_status), "vs_mult": float(m.get("vs_mult", 1.5))})
	if bool(m.get("field_element", false)):
		md.effects.append({"id": &"field_element", "power_bonus": int(m.get("field_power", BattleRules.FIELD_ELEMENT_POWER))})
	if m.has("self_stages"):
		md.effects.append({"id": &"self_stage_after", "stages": m.self_stages})
	if bool(m.get("cure_self", false)):
		md.effects.append({"id": &"cure_self"})
	if m.has("snare"):
		md.effects.append({"id": &"side_snare", "snare": m.snare})
	if bool(m.get("clear_snares", false)):
		md.effects.append({"id": &"clear_snares"})
	# "stats": several stage changes at once, {"atk": -1, "foc": -1}; "self" picks the side.
	if m.get("stats", null) is Dictionary:
		for st: String in m.stats:
			md.effects.append({"id": &"stat_change", "stat": st, "amount": int(m.stats[st]), "self": bool(m.get("self", true)), "chance": float(m.get("stage_chance", 1.0))})
	if m.has("cure_target"):
		md.effects.append({"id": &"cure_target", "status": str(m.cure_target)})
	md.ignore_daze = bool(m.get("ignore_daze", false))
	md.ignore_stages = bool(m.get("ignore_stages", false))
	return md

static func _load_spirlings() -> void:
	var raw: Variant = _read(SPIRLINGS_PATH)
	if not raw is Array:
		push_error("Database: cannot read %s" % SPIRLINGS_PATH)
		return
	for s: Dictionary in raw:
		var sd := SpirlingData.new()
		sd.dex_id = int(s.dex_id)
		sd.species_name = s.name
		for e: String in s.elements:
			sd.elements.append(Elements.E[e])
		var base: Dictionary = s.base
		sd.base_hp = int(base.hp)
		sd.base_atk = int(base.atk)
		sd.base_def = int(base["def"])
		sd.base_foc = int(base.foc)
		sd.base_spd = int(base.spd)
		sd.evolve_level = int(s.get("evolve_level", 0))
		sd.bond_rate = float(s.get("bond_rate", SpirlingData.DEFAULT_BOND_RATE))
		sd.trait_id = str(s.get("trait", ""))
		sd.evolve_item = str(s.get("evolve_item", ""))
		sd.evolve_map = str(s.get("evolve_map", ""))
		sd.lore = str(s.get("lore", ""))
		sd.height = str(s.get("height", ""))
		sd.habitat = str(s.get("habitat", ""))
		var total: int = sd.base_hp + sd.base_atk + sd.base_def + sd.base_foc + sd.base_spd
		sd.xp_yield = int(s.get("xp_yield", total / 5))
		var learnset: Dictionary = s.get("learnset", {})
		var levels: Array = learnset.keys()
		levels.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b))
		for lvl: Variant in levels:
			var entry: Variant = learnset[lvl]
			var names: Array = entry if entry is Array else [entry]
			for move_name: Variant in names:
				var md: MoveData = moves.get(str(move_name))
				if md == null:
					push_error("Database: %s learns unknown move %s" % [sd.species_name, move_name])
					continue
				sd.learnset_levels.append(int(lvl))
				sd.learnset_moves.append(md)
		spirlings[sd.species_name] = sd
	for s: Dictionary in raw:
		if s.get("evolves_to") != null:
			spirlings[s.name].evolves_to = spirlings.get(str(s.evolves_to))

static func _load_items() -> void:
	var raw: Variant = _read(ITEMS_PATH)
	if not raw is Array:
		return
	for it: Dictionary in raw:
		items[str(it.id)] = it
