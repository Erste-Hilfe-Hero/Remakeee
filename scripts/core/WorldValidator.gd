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
	check_reachability(errors, map_ids)
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

## Map reachability (item 99): from every cell the player can arrive on (warps into the map,
## the new-game start), with every puzzle block open and all Tamer Gear owned, each warp, NPC,
## sign, gear spot and rest point must be reachable. Every map must be reachable from the start,
## and every warp must have a way back to the map it came from.
static func check_reachability(errors: PackedStringArray, map_ids: PackedStringArray, start_map: String = "lighthouse", start_cell: Vector2i = Vector2i(4, 4)) -> void:
	var entries: Dictionary = {}
	entries[start_map] = [start_cell]
	var links: Dictionary = {}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		for w: Dictionary in m.warps:
			var to: String = str(w.get("to", ""))
			var arr: Array = entries.get(to, [])
			arr.append(Vector2i(int(w.tx), int(w.ty)))
			entries[to] = arr
			var l: Dictionary = links.get(id, {})
			l[to] = true
			links[id] = l
	for id: String in map_ids:
		if not entries.has(id):
			errors.append("map '%s': no warp leads here" % id)
			continue
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var reach: Dictionary = reachable_cells(m, entries[id])
		var near: Callable = func(c: Vector2i) -> bool:
			if reach.has(c):
				return true
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if reach.has(c + d):
					return true
			return false
		for w: Dictionary in m.warps:
			if not near.call(Vector2i(int(w.x), int(w.y))):
				errors.append("map '%s': warp to '%s' at %s,%s cannot be reached" % [id, w.get("to", ""), w.x, w.y])
			if not (links.get(str(w.get("to", "")), {}) as Dictionary).has(id):
				errors.append("map '%s': no way back from '%s'" % [id, w.get("to", "")])
		for n: Dictionary in m.npcs:
			if not near.call(Vector2i(int(n.x), int(n.y))):
				errors.append("map '%s': npc '%s' cannot be reached" % [id, n.get("id", "")])
		for sg: Dictionary in m.signs:
			if not near.call(Vector2i(int(sg.x), int(sg.y))):
				errors.append("map '%s': sign at %s,%s cannot be reached" % [id, sg.x, sg.y])
		for g: Dictionary in m.gear_spots:
			var f: Array = g.get("from", [g.x, g.y])
			if not reach.has(Vector2i(int(f[0]), int(f[1]))):
				errors.append("map '%s': gear spot at %s,%s cannot be reached" % [id, g.x, g.y])
		if m.heal_point.x >= 0 and not near.call(m.heal_point):
			errors.append("map '%s': rest point cannot be reached" % id)
	var seen: Dictionary = {start_map: true}
	var queue: Array[String] = [start_map]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for to: Variant in (links.get(cur, {}) as Dictionary).keys():
			if not seen.has(to):
				seen[to] = true
				queue.append(str(to))
	for id: String in map_ids:
		if not seen.has(id):
			errors.append("map '%s': cannot be reached from the start" % id)

## Cells reachable from [param starts] with blocks open, gear owned and NPCs in the way.
static func reachable_cells(m: MapData, starts: Array) -> Dictionary:
	var open: Dictionary = {}
	for b: Dictionary in m.blocks:
		open[str(b.get("open_flag", ""))] = true
	m.apply_blocks(open)
	var npc_cells: Dictionary = {}
	for n: Dictionary in m.npcs:
		npc_cells[Vector2i(int(n.x), int(n.y))] = true
	var passable: Callable = func(c: Vector2i) -> bool:
		return (m.is_walkable(c) or m.gear_needed_at(c) != "") and not npc_cells.has(c)
	var jumps: Dictionary = {}
	for g: Dictionary in m.gear_spots:
		if g.has("to"):
			var f: Array = g.get("from", [])
			var key := Vector2i(int(f[0]), int(f[1]))
			var arr: Array = jumps.get(key, [])
			arr.append(Vector2i(int(g.to[0]), int(g.to[1])))
			jumps[key] = arr
	var reach: Dictionary = {}
	var queue: Array[Vector2i] = []
	for s: Variant in starts:
		var c: Vector2i = s
		if not reach.has(c):
			reach[c] = true
			queue.append(c)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var next: Array = []
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if passable.call(c + d):
				next.append(c + d)
		next.append_array(jumps.get(c, []))
		for n: Vector2i in next:
			if not reach.has(n):
				reach[n] = true
				queue.append(n)
	return reach

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
