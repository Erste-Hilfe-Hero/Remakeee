class_name WorldValidator
extends RefCounted
## Checks maps, warps, dialogue references, encounter tables, hidden finds and the world
## layout (data/world_layout.json) in data/.

const LAYOUT_PATH: String = "res://data/world_layout.json"
## Regions a map may belong to (Corvane is the island across the lake, area 3 item 1287).
const REGIONS: Array[String] = ["veydal", "corvane"]

static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	Database.load_all()
	var map_ids: PackedStringArray = MapData.all_ids()
	check_reachability(errors, map_ids)
	check_encounter_tables(errors, map_ids)
	check_secrets(errors, map_ids)
	check_puzzles(errors, map_ids)
	check_layout(errors, map_ids, load_layout())
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
				var teams: Array = [n.get("team", [])] if n.has("team") or not n.has("teams_by_difficulty") else []
				if n.has("team_by_starter"):
					teams = (n.team_by_starter as Dictionary).values()
					for st: String in Database.STARTERS:
						if not (n.team_by_starter as Dictionary).has(st):
							errors.append("map '%s': rival '%s' has no team for starter %s" % [id, n.get("id", ""), st])
				if n.get("teams_by_difficulty") is Dictionary:
					for k: String in n.teams_by_difficulty:
						if not k in TrainerData.DIFFICULTY_KEYS:
							errors.append("map '%s': npc '%s' has unknown difficulty team '%s'" % [id, n.get("id", ""), k])
						teams.append(n.teams_by_difficulty[k])
				if teams.size() < TrainerData.DIFFICULTY_KEYS.size() and not n.has("team") and not n.has("team_by_starter"):
					errors.append("map '%s': npc '%s' lacks a team for some difficulties" % [id, n.get("id", "")])
				if n.has("profile") and not BattleAI.profiles().has(str(n.profile)):
					errors.append("map '%s': npc '%s' has unknown AI profile '%s'" % [id, n.get("id", ""), n.profile])
				for t: Variant in teams:
					if (t as Array).is_empty():
						errors.append("map '%s': wayfarer '%s' has an empty team" % [id, n.get("id", "")])
					for entry: Variant in t:
						if Database.species(str((entry as Dictionary).get("species", ""))) == null:
							errors.append("map '%s': npc '%s' has unknown team species %s" % [id, n.get("id", ""), entry])
						for mv: Variant in (entry as Dictionary).get("moves", []):
							if Database.move(str(mv)) == null:
								errors.append("map '%s': npc '%s' has unknown team art '%s'" % [id, n.get("id", ""), mv])
						var held: String = str((entry as Dictionary).get("held", ""))
						if not held.is_empty() and not Database.item(held).has("held"):
							errors.append("map '%s': npc '%s' holds '%s', which is no keepsake" % [id, n.get("id", ""), held])
				errors.append_array(format_errors(n, id))
		for s: Dictionary in m.signs:
			_check_dialogue(errors, id, str(s.get("dialogue", "")))
		if not m.region in REGIONS:
			errors.append("map '%s': unknown region '%s'" % [id, m.region])
		if not m.encounter_table.is_empty():
			for sp: String in EncounterTable.species_on(m.encounter_table):
				if Database.species(sp) == null:
					errors.append("encounter table '%s': unknown species '%s'" % [m.encounter_table, sp])
	errors.append_array(check_rarity_weights())
	return errors

## Plan area 1, item 132: encounter weights follow the kind's rarity band
## (SpirlingData.WEIGHT_BANDS); ancient kinds never spawn at random (DataValidator).
static func check_rarity_weights() -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: String in EncounterTable.table_ids():
		for sp: Variant in EncounterTable.table(id).get("spawns", []):
			var sd: SpirlingData = Database.species(str((sp as Dictionary).get("species", "")))
			if sd == null or not SpirlingData.WEIGHT_BANDS.has(sd.rarity):
				continue
			var band: Vector2i = SpirlingData.WEIGHT_BANDS[sd.rarity]
			var w: int = int((sp as Dictionary).get("weight", 0))
			if w < band.x or w > band.y:
				errors.append("encounter table '%s': %s weight %d outside %s band %d-%d" % [id, sd.species_name, w, sd.rarity, band.x, band.y])
	return errors

## Encounter tables (area 3 item 894): every map with ferns, reeds or scree that rolls wild
## Spirlings names a table that exists, and every table in data/encounters.json is used by a map.
static func check_encounter_tables(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var used: Dictionary = {}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null or m.encounter_table.is_empty():
			continue
		used[m.encounter_table] = true
		if EncounterTable.table(m.encounter_table).is_empty():
			errors.append("map '%s': encounter table '%s' is missing in data/encounters.json" % [id, m.encounter_table])
		var wild_cells: int = 0
		for y: int in m.height:
			for x: int in m.rows[y].length():
				if m.kind_at(Vector2i(x, y)) in TilesetFactory.ENCOUNTER_KINDS:
					wild_cells += 1
		if wild_cells == 0:
			errors.append("map '%s': has encounter table '%s' but no fern, reed or scree cell" % [id, m.encounter_table])
	for t: String in EncounterTable.table_ids():
		if t.begins_with("_"):
			continue
		if not used.has(t):
			errors.append("encounter table '%s' is not used by any map" % t)
	check_table_balance(errors, map_ids)

## Base rate per kind of place (area 3 item 1110). Rift hollows keep their own rate.
const RATES: Dictionary[String, float] = {"route": 0.12, "marsh": 0.10, "cave": 0.10, "dungeon": 0.06}
## Largest jump in ring between two tables next to each other in level order (item 1114).
const MAX_RING_JUMP: int = 4
const MIN_TABLE_WEIGHT: int = 50

## Encounter balance (items 1109, 1110, 1114): grounds are known names, weights add up to at
## least 50, the base rate fits the kind of place, and sorted by their lowest ring no table
## jumps more than 4 rings past the one before it.
static func check_table_balance(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var places: Dictionary = load_layout().get("maps", {})
	var kind_of: Dictionary = {}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null or m.encounter_table.is_empty():
			continue
		var place: String = layout_place(places, id)
		kind_of[m.encounter_table] = str((places.get(place, {}) as Dictionary).get("kind", ""))
	var mins: Array = []
	for t: String in EncounterTable.table_ids():
		if t.begins_with("_"):
			continue
		var total: int = 0
		var low: int = 999
		for sp: Dictionary in EncounterTable.table(t).get("spawns", []):
			total += int(sp.get("weight", 1))
			low = mini(low, int(sp.get("min", 2)))
			for g: String in EncounterTable.grounds_of(sp):
				if not g in EncounterTable.GROUND_NAMES:
					errors.append("encounter table '%s': unknown ground '%s'" % [t, g])
		if total < MIN_TABLE_WEIGHT:
			errors.append("encounter table '%s': weights add up to %d, need at least %d" % [t, total, MIN_TABLE_WEIGHT])
		var kind: String = str(kind_of.get(t, ""))
		if RATES.has(kind) and not is_equal_approx(EncounterTable.rate(t), RATES[kind]):
			errors.append("encounter table '%s': rate %.2f, a %s uses %.2f" % [t, EncounterTable.rate(t), kind, RATES[kind]])
		if low < 999:
			mins.append([low, t])
	mins.sort()
	for i: int in range(1, mins.size()):
		if int(mins[i][0]) - int(mins[i - 1][0]) > MAX_RING_JUMP:
			errors.append("encounter tables: '%s' starts at ring %d, more than %d above '%s' (ring %d)" % [mins[i][1], mins[i][0], MAX_RING_JUMP, mins[i - 1][1], mins[i - 1][0]])

## Hidden finds (area 3 items 1080, 1083): each one is reachable, gives a real item from
## data/items.json and has a flag no other find uses.
static func check_secrets(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var flags: Dictionary = {}
	var entries: Dictionary = entry_cells(map_ids)
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null or m.secrets.is_empty():
			continue
		var reach: Dictionary = reachable_cells(m, entries.get(id, []))
		for sc: Dictionary in m.secrets:
			var at := Vector2i(int(sc.get("x", -1)), int(sc.get("y", -1)))
			var flag: String = str(sc.get("flag", ""))
			if flag.is_empty():
				errors.append("map '%s': hidden find at %s has no flag" % [id, at])
			elif flags.has(flag):
				errors.append("map '%s': hidden find flag '%s' is also used on '%s'" % [id, flag, flags[flag]])
			else:
				flags[flag] = id
			if sc.has("dialogue"):
				var entry: Dictionary = Dialogue.get_entry(str(sc.dialogue))
				if entry.is_empty():
					errors.append("map '%s': hidden find at %s has unknown dialogue '%s'" % [id, at, sc.dialogue])
				elif str(entry.get("flag", "")) != flag:
					errors.append("map '%s': hidden find at %s sets flag '%s' but its dialogue sets '%s'" % [id, at, flag, entry.get("flag", "")])
			if Database.item(str(sc.get("item", ""))).is_empty():
				errors.append("map '%s': hidden find at %s gives unknown item '%s'" % [id, at, sc.get("item", "")])
			if int(sc.get("count", 1)) < 1:
				errors.append("map '%s': hidden find at %s gives nothing" % [id, at])
			if not m.in_bounds(at):
				errors.append("map '%s': hidden find at %s is off the map" % [id, at])
				continue
			var near: bool = reach.has(at)
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				near = near or reach.has(at + d)
			if not near:
				errors.append("map '%s': hidden find at %s cannot be reached" % [id, at])

## Puzzles (area 3 item 893): every plate, boulder and plank gap can be reached, every ladder
## leads to a walkable cell, a map with cracked floor has a floor below, and every boulder
## puzzle has a solution (PuzzleSolver) from the first cell the player arrives on.
static func check_puzzles(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var entries: Dictionary = entry_cells(map_ids)
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var starts: Array = entries.get(id, [])
		var boulders: Array[Vector2i] = PuzzleRoom.start_boulders(m)
		var cracked: bool = false
		var gaps: Array[Vector2i] = []
		for y: int in m.height:
			for x: int in m.rows[y].length():
				var k: int = m.kind_at(Vector2i(x, y))
				cracked = cracked or k == TilesetFactory.Kind.CRACKED
				if k == TilesetFactory.Kind.PLANK and m.ladder_at(Vector2i(x, y)).is_empty():
					gaps.append(Vector2i(x, y))
		if m.puzzles.is_empty() and boulders.is_empty() and not cracked and gaps.is_empty() and m.ladders.is_empty():
			continue
		var reach: Dictionary = reachable_cells(m, starts)
		var near: Callable = func(c: Vector2i) -> bool:
			if reach.has(c):
				return true
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if reach.has(c + d):
					return true
			return false
		for b: Vector2i in boulders:
			if not near.call(b):
				errors.append("map '%s': boulder at %s cannot be reached" % [id, b])
		for g: Vector2i in gaps:
			if not near.call(g):
				errors.append("map '%s': plank gap at %s cannot be reached" % [id, g])
		if cracked and (m.drop_to.is_empty() or not MapData.exists(m.drop_to)):
			errors.append("map '%s': has cracked floor but no floor below (drop_to)" % id)
		elif cracked:
			var below: MapData = MapData.load_map(m.drop_to)
			for y: int in m.height:
				for x: int in m.rows[y].length():
					if m.kind_at(Vector2i(x, y)) == TilesetFactory.Kind.CRACKED and not below.is_walkable(Vector2i(x, y)):
						errors.append("map '%s': cracked floor at %d,%d drops onto a blocked cell of '%s'" % [id, x, y, m.drop_to])
		for l: Dictionary in m.ladders:
			var at := Vector2i(int(l.x), int(l.y))
			if not near.call(at):
				errors.append("map '%s': ladder anchor at %s cannot be reached" % [id, at])
			var to: String = str(l.get("to", ""))
			if not MapData.exists(to) or not MapData.load_map(to).is_walkable(Vector2i(int(l.get("tx", -1)), int(l.get("ty", -1)))):
				errors.append("map '%s': ladder at %s leads nowhere ('%s')" % [id, at, to])
		for pz: Dictionary in m.puzzles:
			var pid: String = str(pz.get("id", "?"))
			if str(pz.get("flag", "")).is_empty():
				errors.append("map '%s': puzzle '%s' has no flag" % [id, pid])
			var plates: Array[Vector2i] = PuzzleRoom.plates(m, pz)
			if plates.is_empty():
				errors.append("map '%s': puzzle '%s' has no pressure plates" % [id, pid])
				continue
			if plates.size() > boulders.size():
				errors.append("map '%s': puzzle '%s' has more plates than boulders" % [id, pid])
				continue
			for p: Vector2i in plates:
				if m.base_char(p) != "P":
					errors.append("map '%s': puzzle '%s' plate %s is not a 'P' tile" % [id, pid, p])
				elif not reach.has(p):
					errors.append("map '%s': puzzle '%s' plate %s cannot be reached" % [id, pid, p])
			if starts.is_empty():
				continue
			# Other doors open (earlier rooms solved), this puzzle's own door shut.
			var fresh: MapData = MapData.load_map(id)
			var open: Dictionary = {}
			for b: Dictionary in fresh.blocks:
				open[str(b.get("open_flag", ""))] = true
			open.erase(str(pz.get("flag", "")))
			fresh.apply_blocks(open)
			if PuzzleSolver.solve(fresh, pz, starts[0]) == null:
				errors.append("map '%s': puzzle '%s' has no solution" % [id, pid])

## Cells the player can arrive on for each map: warp targets plus the new-game start.
static func entry_cells(map_ids: PackedStringArray, start_map: String = "lighthouse", start_cell: Vector2i = Vector2i(4, 4)) -> Dictionary:
	var entries: Dictionary = {start_map: [start_cell]}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		for w: Dictionary in m.warps:
			var to: String = str(w.get("to", ""))
			var arr: Array = entries.get(to, [])
			arr.append(Vector2i(int(w.tx), int(w.ty)))
			entries[to] = arr
	return entries

static func load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return raw if raw is Dictionary else {}

## World layout (area 3 item 896): every map file has a place in data/world_layout.json (or
## lies "inside" one, like a house in a town), every warp between two places is an edge there,
## and every edge is backed by a warp (the ferry and coach lines count as warps too).
static func check_layout(errors: PackedStringArray, map_ids: PackedStringArray, layout: Dictionary) -> void:
	var places: Dictionary = layout.get("maps", {})
	if places.is_empty():
		errors.append("data/world_layout.json is missing or has no maps")
		return
	var files: Dictionary = {}
	for id: String in map_ids:
		files[str(MapData.split_id(id)[0])] = true
	var cells: Dictionary = {}
	for pid: String in places:
		var p: Dictionary = places[pid]
		if not files.has(pid):
			errors.append("world layout: '%s' is not a map" % pid)
		if p.has("inside"):
			if not places.has(str(p.inside)) or (places[str(p.inside)] as Dictionary).has("inside"):
				errors.append("world layout: '%s' is inside unknown place '%s'" % [pid, p.inside])
			continue
		var pos: Array = p.get("pos", [])
		if pos.size() != 2:
			errors.append("world layout: '%s' needs a grid position [x, y]" % pid)
			continue
		if not str(p.get("region", "")) in REGIONS:
			errors.append("world layout: '%s' has unknown region '%s'" % [pid, p.get("region", "")])
		var key: String = "%s:%d,%d" % [p.get("region", ""), int(pos[0]), int(pos[1])]
		if cells.has(key):
			errors.append("world layout: '%s' and '%s' share the grid cell %s" % [pid, cells[key], key])
		cells[key] = pid
	for f: String in files:
		if not places.has(f):
			errors.append("world layout: map '%s' has no place" % f)
	var edges: Dictionary = {}
	for pid: String in places:
		for n: Variant in (places[pid] as Dictionary).get("neighbours", []):
			if not places.has(str(n)):
				errors.append("world layout: '%s' lists unknown neighbour '%s'" % [pid, n])
				continue
			edges[layout_edge(pid, str(n))] = true
	var warped: Dictionary = {}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var a: String = layout_place(places, id)
		var targets: Array = []
		for w: Dictionary in m.warps:
			targets.append(str(w.get("to", "")))
		for t: Variant in layout.get("lines", {}).values():
			if id in (t as Array):
				targets.append_array(t)
		for to: String in targets:
			var b: String = layout_place(places, to)
			if a.is_empty() or b.is_empty() or a == b:
				continue
			var e: String = layout_edge(a, b)
			warped[e] = true
			if not edges.has(e):
				errors.append("world layout: warp from '%s' to '%s' is not an edge (add it to neighbours)" % [id, to])
	for e: String in edges:
		if not warped.has(e):
			errors.append("world layout: edge %s has no warp" % e)

## The place on the world map that [param map_id] belongs to: its file, or the place that
## file lies inside. "" if the layout doesn't know it.
static func layout_place(places: Dictionary, map_id: String) -> String:
	var file: String = str(MapData.split_id(map_id)[0])
	if not places.has(file):
		return ""
	var p: Dictionary = places[file]
	return str(p.inside) if p.has("inside") else file

static func layout_edge(a: String, b: String) -> String:
	return "%s-%s" % [a, b] if a < b else "%s-%s" % [b, a]

## Map reachability (item 99): from every cell the player can arrive on (warps into the map,
## the new-game start), with every puzzle block open and all Wayfarer Gear owned, each warp, NPC,
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
		# All gear owned and every puzzle solved: wading water, vines and plank gaps are
		# crossable and boulders can be pushed aside (PuzzleSolver checks the puzzles themselves).
		var k: int = m.kind_at(c)
		var open_kind: bool = m.in_bounds(c) and (TilesetFactory.GEAR_KINDS.has(k) or k == TilesetFactory.Kind.BOULDER or k == TilesetFactory.Kind.PLANK)
		return (m.is_walkable(c) or open_kind or m.gear_needed_at(c) != "") and not npc_cells.has(c)
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

## Problems with a Wayfarer's battle format: "front", "boss", "partner" and "wild" (see TrainerData).
static func format_errors(def: Dictionary, map_id: String = "?") -> PackedStringArray:
	var errors: PackedStringArray = []
	var who: String = str(def.get("id", "?"))
	if def.has("front"):
		var f: Variant = def.front
		if not (f is Array and (f as Array).size() == 2):
			errors.append("map '%s': npc '%s' front must be [player, foe]" % [map_id, who])
		else:
			for v: Variant in f:
				if int(v) < 1 or int(v) > BattleRules.MAX_FRONT:
					errors.append("map '%s': npc '%s' front values must be 1..%d" % [map_id, who, BattleRules.MAX_FRONT])
	if def.has("boss") and not BattleRules.BOSSES.has(str(def.boss)):
		errors.append("map '%s': npc '%s' has unknown boss '%s'" % [map_id, who, def.boss])
	if def.has("partner"):
		var p: Variant = def.partner
		if not (p is Dictionary and (p as Dictionary).has("name") and (p.get("team", []) as Array).size() > 0):
			errors.append("map '%s': npc '%s' partner needs a name and a team" % [map_id, who])
		else:
			for entry: Variant in p.team:
				if Database.species(str((entry as Dictionary).get("species", ""))) == null:
					errors.append("map '%s': npc '%s' partner has unknown species %s" % [map_id, who, entry])
	if TrainerData.is_wild_horde(def) and def.has("partner"):
		errors.append("map '%s': npc '%s' is a wild horde and can't have a partner" % [map_id, who])
	return errors
