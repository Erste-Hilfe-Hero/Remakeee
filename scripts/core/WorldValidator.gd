class_name WorldValidator
extends RefCounted
## Checks maps, warps, dialogue references and encounter tables in data/.

static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	Database.load_all()
	var map_ids: PackedStringArray = []
	for f: String in DirAccess.get_files_at(MapData.DIR):
		if f.ends_with(".json"):
			map_ids.append(f.get_basename())
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			errors.append("map '%s' cannot be read" % id)
			continue
		for y: int in m.height:
			if m.rows[y].length() != m.width:
				errors.append("map '%s' row %d has length %d, expected %d" % [id, y, m.rows[y].length(), m.width])
			for ch: String in m.rows[y]:
				if not TilesetFactory.LEGEND.has(ch):
					errors.append("map '%s' row %d: unknown tile '%s'" % [id, y, ch])
		for w: Dictionary in m.warps:
			if not w.has("to") or not str(w.to) in map_ids:
				errors.append("map '%s': warp at %s,%s goes to unknown map '%s'" % [id, w.get("x"), w.get("y"), w.get("to", "")])
				continue
			var dest: MapData = MapData.load_map(str(w.to))
			var tc := Vector2i(int(w.tx), int(w.ty))
			if not dest.is_walkable(tc):
				errors.append("map '%s': warp lands on a blocked cell %s in '%s'" % [id, tc, w.to])
		for n: Dictionary in m.npcs:
			_check_dialogue(errors, id, str(n.get("dialogue", "")))
			if not m.is_walkable(Vector2i(int(n.x), int(n.y))) and m.kind_at(Vector2i(int(n.x), int(n.y))) != TilesetFactory.Kind.FLOOR:
				errors.append("map '%s': npc '%s' stands on a blocked cell" % [id, n.get("id", "")])
			if TrainerData.is_trainer(n):
				_check_dialogue(errors, id, str(n.get("intro", "")))
				_check_dialogue(errors, id, str(n.get("defeat", "")))
				var teams: Array = [n.get("team", [])]
				if n.has("team_by_starter"):
					teams = (n.team_by_starter as Dictionary).values()
					for st: String in Database.STARTERS:
						if not (n.team_by_starter as Dictionary).has(st):
							errors.append("map '%s': rival '%s' has no team for starter %s" % [id, n.get("id", ""), st])
				for t: Variant in teams:
					if (t as Array).is_empty():
						errors.append("map '%s': tamer '%s' has an empty team" % [id, n.get("id", "")])
					for entry: Variant in t:
						if Database.species(str((entry as Dictionary).get("species", ""))) == null:
							errors.append("map '%s': npc '%s' has unknown team species %s" % [id, n.get("id", ""), entry])
		for s: Dictionary in m.signs:
			_check_dialogue(errors, id, str(s.get("dialogue", "")))
		if not m.encounter_table.is_empty():
			if EncounterTable.table(m.encounter_table).is_empty():
				errors.append("map '%s': unknown encounter table '%s'" % [id, m.encounter_table])
			for sp: String in EncounterTable.species_on(m.encounter_table):
				if Database.species(sp) == null:
					errors.append("encounter table '%s': unknown species '%s'" % [m.encounter_table, sp])
	return errors

static func _check_dialogue(errors: PackedStringArray, map_id: String, ref: String) -> void:
	if ref.is_empty():
		return
	var parts: PackedStringArray = ref.split("/", false, 1)
	var path: String = Dialogue.DIR + parts[0] + ".json"
	if parts.size() != 2 or not FileAccess.file_exists(path):
		errors.append("map '%s': dialogue '%s' has no file" % [map_id, ref])
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or not (raw as Dictionary).has(parts[1]):
		errors.append("map '%s': dialogue key '%s' missing" % [map_id, ref])
