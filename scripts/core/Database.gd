class_name Database
## Loads roster + moves from JSON into SpirlingData / MoveData resources.
static var spirlings := {}
static var moves := {}

static func load_all() -> void:
	if not spirlings.is_empty():
		return
	for m in JSON.parse_string(FileAccess.get_file_as_string("res://data/moves.json")):
		var md := MoveData.new()
		md.move_name = m.name
		md.element = Elements.E[m.element]
		md.kind = MoveData.Kind[m.kind]
		md.power = m.power
		md.accuracy = m.accuracy
		md.energy_cost = m.energy
		md.priority = m.get("priority", 0)
		md.status_effect = m.get("status", "")
		md.status_chance = m.get("status_chance", 0.0)
		moves[md.move_name] = md
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/spirlings.json"))
	for s in raw:
		var sd := SpirlingData.new()
		sd.dex_id = s.dex_id
		sd.species_name = s.name
		for e in s.elements:
			sd.elements.append(Elements.E[e])
		sd.base_hp = s.base.hp; sd.base_atk = s.base.atk; sd.base_def = s.base["def"]
		sd.base_foc = s.base.foc; sd.base_spd = s.base.spd
		sd.evolve_level = s.evolve_level
		spirlings[sd.species_name] = sd
	for s in raw:
		if s.evolves_to:
			spirlings[s.name].evolves_to = spirlings[s.evolves_to]
