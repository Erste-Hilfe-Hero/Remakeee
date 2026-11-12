class_name WorldValidator
extends RefCounted
## Checks maps, warps, dialogue references, encounter tables, hidden finds and the world
## layout (data/world_layout.json) in data/.

const LAYOUT_PATH: String = "res://data/world_layout.json"
## Regions a map may belong to (Corvane is the island across the lake, area 3 item 1287).
const REGIONS: Array[String] = ["veydal", "corvane", "ashmere", "solenne"]

## Maps per region, counted apart (item 1287): "Maps: veydal 37, corvane 1".
static func region_counts(map_ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for r: String in REGIONS:
		out[r] = 0
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m != null:
			out[m.region] = int(out.get(m.region, 0)) + 1
	return out

static func region_summary() -> String:
	var counts: Dictionary = region_counts(MapData.all_ids())
	var parts: PackedStringArray = []
	for r: Variant in counts:
		parts.append("%s %d" % [r, counts[r]])
	return "Maps: " + ", ".join(parts)

static func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	Database.load_all()
	var map_ids: PackedStringArray = MapData.all_ids()
	check_reachability(errors, map_ids)
	check_encounter_tables(errors, map_ids)
	check_secrets(errors, map_ids)
	check_puzzles(errors, map_ids)
	check_passages(errors, map_ids)
	check_layout(errors, map_ids, load_layout())
	check_transit(errors, map_ids, load_layout().get("lines", {}))
	check_schedules(errors, map_ids)
	check_shapes(errors, map_ids, load_layout())
	check_squares(errors, map_ids, load_layout())
	check_room_encounters(errors, map_ids)
	check_landmarks(errors, map_ids)
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
				if n.get("rule_by_difficulty") is Dictionary:
					for k: String in n.rule_by_difficulty:
						var v: Variant = n.rule_by_difficulty[k]
						var ids: Array = v if v is Array else [v]
						var d: int = TrainerData.DIFFICULTY_KEYS.find(k)
						var bad: bool = d < 0 or ids.is_empty() or ids.size() > BattleRules.rule_stack(d)
						for r: Variant in ids:
							bad = bad or not BattleRules.RULES.has(str(r)) or not d in BattleRules.RULES[str(r)].get("difficulty", [0, 1, 2, 3])
						if bad:
							errors.append("map '%s': npc '%s' has a bad difficulty rule %s" % [id, n.get("id", ""), k])
				if n.has("profile") and not BattleAI.profiles().has(str(n.profile)):
					errors.append("map '%s': npc '%s' has unknown AI profile '%s'" % [id, n.get("id", ""), n.profile])
				if n.has("profile_from") and not str(n.profile_from) in TrainerData.DIFFICULTY_KEYS:
					errors.append("map '%s': npc '%s' has unknown profile_from '%s'" % [id, n.get("id", ""), n.profile_from])
				var tune: Variant = n.get("profile_tune", {})
				if not tune is Dictionary:
					errors.append("map '%s': npc '%s' profile_tune must be an object" % [id, n.get("id", "")])
				else:
					for k: Variant in tune:
						if not (tune[k] is float or tune[k] is int) or not (BattleAI.profiles().get("balanced", {}) as Dictionary).has(str(k)):
							errors.append("map '%s': npc '%s' profile_tune '%s' is not a known number weight" % [id, n.get("id", ""), k])
				if n.has("second_trial"):
					var st_ok: bool = TrainerData.has_second_trial(n)
					if st_ok:
						var rules: Array = n.second_trial.get("rules", [])
						st_ok = rules.size() == TrainerData.SECOND_TRIAL_RULES
						for r: Variant in rules:
							st_ok = st_ok and BattleRules.RULES.has(str(r))
						for d: int in TrainerData.DIFFICULTY_KEYS.size():
							var entries: Array = TrainerData.team_entries(TrainerData.second_trial_def(n, id), "", d)
							st_ok = st_ok and not entries.is_empty()
							for e: Variant in entries:
								st_ok = st_ok and e is Dictionary and Database.species(str(e.get("species", ""))) != null
					if not st_ok:
						errors.append("map '%s': npc '%s' has a bad second_trial (a Warden, %d known rules, known species)" % [id, n.get("id", ""), TrainerData.SECOND_TRIAL_RULES])
				if n.has("lexicon") and not Lexicon.has_entry(str(n.lexicon)):
					errors.append("map '%s': npc '%s' has unknown lexicon entry '%s'" % [id, n.get("id", ""), n.lexicon])
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
## Name prefixes and suffixes of spots that sit on an object (a sign, a desk), not on floor.
const OBJECT_SPOT_PREFIX: Array[String] = ["letter_", "page_", "wall_", "burned_"]
const OBJECT_SPOT_SUFFIX: Array[String] = ["_desk", "_shelf", "_stove", "_sign", "_plate", "_lamp", "_diary"]

static func is_object_spot(name: String) -> bool:
	for p: String in OBJECT_SPOT_PREFIX:
		if name.begins_with(p):
			return true
	for p: String in OBJECT_SPOT_SUFFIX:
		if name.ends_with(p):
			return true
	return false

## Secret passages (item 1082) are blocks with the same flag next to a reachable cell, and
## spots for story figures sit inside the map on floor (or on an object for story signs).
static func check_passages(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var entries: Dictionary = entry_cells(map_ids)
	var flags: Dictionary = {}
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		for name: String in m.spots:
			var c: Vector2i = m.spots[name]
			if not m.in_bounds(c):
				errors.append("map '%s': spot '%s' at %s is off the map" % [id, name, c])
			elif not is_object_spot(name) and not m.is_walkable(c):
				errors.append("map '%s': spot '%s' at %s is not on floor" % [id, name, c])
		for b: Dictionary in m.blocks:
			var of: String = str(b.get("open_flag", ""))
			if of.begins_with("_") and not of in WorldMechanics.CLOCK_FLAGS:
				errors.append("map '%s': block at %s,%s waits for unknown clock flag '%s'" % [id, b.x, b.y, of])
		if not m.beam.is_empty():
			check_beam(errors, id, m)
		for list: Array in [m.npcs, m.signs, m.blocks]:
			for def: Dictionary in list:
				if not def.has("phase_only"):
					continue
				var only: Array = def.phase_only if def.phase_only is Array else [def.phase_only]
				for ph: Variant in only:
					if not str(ph) in DayCycle.PHASE_NAMES:
						errors.append("map '%s': phase_only '%s' at %s,%s is not dawn, day, dusk or night" % [id, ph, def.x, def.y])
		for def: Dictionary in m.npcs:
			for wd: Variant in def.get("weekdays", []):
				if int(wd) < 0 or int(wd) > 6:
					errors.append("map '%s': npc '%s' has weekday %s (0 Sunday .. 6 Saturday)" % [id, def.get("id", ""), wd])
		if m.passages.is_empty():
			continue
		var reach: Dictionary = reachable_cells(m, entries.get(id, []))
		for p: Dictionary in m.passages:
			var c := Vector2i(int(p.x), int(p.y))
			var flag: String = str(p.get("flag", ""))
			if flag == "" or flags.has(flag):
				errors.append("map '%s': passage at %s needs its own flag" % [id, c])
			flags[flag] = true
			var blocked: bool = false
			for b: Dictionary in m.blocks:
				if int(b.x) == c.x and int(b.y) == c.y and str(b.get("open_flag", "")) == flag:
					blocked = true
			if not blocked:
				errors.append("map '%s': passage at %s has no block with open_flag '%s'" % [id, c, flag])
			var near: bool = false
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				near = near or reach.has(c + d)
			if not near:
				errors.append("map '%s': passage at %s cannot be reached" % [id, c])

## Lanternwell (item 1010): some way of turning the mirrors must light the crystal, and the
## room must not start solved.
static func check_beam(errors: PackedStringArray, id: String, m: MapData) -> void:
	var cells: Array[Vector2i] = []
	var start: Dictionary = {}
	for mm: Variant in m.beam.get("mirrors", []):
		var c := Vector2i(int(mm[0]), int(mm[1]))
		cells.append(c)
		start[c] = str(mm[2]) if (mm as Array).size() > 2 else "/"
	if cells.size() > 10:
		errors.append("map '%s': too many mirrors to check (%d)" % [id, cells.size()])
		return
	if WorldMechanics.beam_hits(m, start):
		errors.append("map '%s': the light already hits the crystal at the start" % id)
	for bits: int in 1 << cells.size():
		var ways: Dictionary = {}
		for i: int in cells.size():
			ways[cells[i]] = "\\" if bits & (1 << i) else "/"
		if WorldMechanics.beam_hits(m, ways):
			return
	errors.append("map '%s': no way of turning the mirrors lights the crystal" % id)

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
		# Falling through cracked floor lands on the same cell of the floor below.
		if not m.drop_to.is_empty():
			var below: Array = entries.get(m.drop_to, [])
			for y: int in m.height:
				for x: int in m.rows[y].length():
					if m.kind_at(Vector2i(x, y)) == TilesetFactory.Kind.CRACKED:
						below.append(Vector2i(x, y))
			entries[m.drop_to] = below
	# Boat, coach and ferry stops (Transit) are ways in as well.
	for t: Variant in Transit.lines().values():
		var st: Dictionary = (t as Dictionary).get("stops", {})
		for sid: Variant in st:
			var arr: Array = entries.get(str(sid), [])
			arr.append(Vector2i(int(st[sid][0]), int(st[sid][1])))
			entries[str(sid)] = arr
	return entries

static func load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	return raw if raw is Dictionary else {}

## World layout (area 3 item 896): every map file has a place in data/world_layout.json (or
## lies "inside" one, like a house in a town), every warp between two places is an edge there,
## and every edge is backed by a warp (the ferry and coach lines count as warps too).
## Outdoor maps fit the portrait screen when scrolled: at most MAX_OUTDOOR_W wide and
## MAX_OUTDOOR_H tall (item 907). Routes and marshes are walkable both ways: each has at least two
## other places to go, by foot or by line (item 934).
## Item 1030: puzzle rooms (the rooms with a goal line) have no wild cells in the puzzle
## itself; wild Spirlings only wait on the landing row in front of the stairs (second row from
## the bottom), which is the corridor between two rooms.
static func check_room_encounters(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null or m.goal.is_empty():
			continue
		for c: Vector2i in wild_cells(m):
			if c.y != m.height - 2:
				errors.append("puzzle room '%s': wild cell %s inside the puzzle (only the landing row may have them)" % [id, c])

## Cells of [param m] where wild Spirlings can appear.
static func wild_cells(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in m.height:
		for x: int in m.width:
			if m.kind_at(Vector2i(x, y)) in TilesetFactory.ENCOUNTER_KINDS:
				out.append(Vector2i(x, y))
	return out

const SQUARE_FOLK: int = 3
const SQUARE_REACH: int = 2

## Item 966: every town has a meeting place (a spring, a lamp or a sign) and at dusk at least
## SQUARE_FOLK people with a day plan stand within SQUARE_REACH cells of it.
static func check_squares(errors: PackedStringArray, map_ids: PackedStringArray, layout: Dictionary) -> void:
	var places: Dictionary = layout.get("maps", {})
	for id: String in map_ids:
		if str((places.get(id, {}) as Dictionary).get("kind", "")) != "town":
			continue
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		if not m.in_bounds(m.square):
			errors.append("town '%s' has no square (meeting place)" % id)
			continue
		var k: int = m.kind_at(m.square)
		if not k in [TilesetFactory.Kind.SPRING, TilesetFactory.Kind.LAMP, TilesetFactory.Kind.SIGN]:
			errors.append("town '%s': square %s is not a spring, lamp or sign" % [id, m.square])
		var n: int = square_folk(m, DayCycle.Phase.DUSK).size()
		if n < SQUARE_FOLK:
			errors.append("town '%s': only %d people at the square at dusk, at least %d" % [id, n, SQUARE_FOLK])

## Ids of the people with a day plan near the square of [param m] at [param phase].
static func square_folk(m: MapData, phase: int) -> Array[String]:
	var out: Array[String] = []
	for d: Dictionary in NpcSchedule.defs_for(m, phase):
		if not NpcSchedule.has_plan(d) or not DayCycle.shows_at(d, phase):
			continue
		var c := Vector2i(int(d.x), int(d.y))
		if maxi(absi(c.x - m.square.x), absi(c.y - m.square.y)) <= SQUARE_REACH:
			out.append(str(d.get("id", "")))
	return out

## Landmarks (map design item 509): each one stands on a solid cell of an outdoor map in its
## own act, next to a cell you can walk on, and never on a door, sign, person, find or story spot.
static func check_landmarks(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	var names: Dictionary = {}
	var all: Dictionary = Landmarks.all()
	for id: String in all:
		var lm: Dictionary = all[id]
		if not id in map_ids:
			errors.append("landmark on unknown map '%s'" % id)
			continue
		var m: MapData = MapData.load_map(id)
		var kind: String = str(lm.get("kind", ""))
		if not m.outdoor:
			errors.append("landmark of '%s': the map is not outdoors" % id)
		if Landmarks.region_of(kind) != m.region:
			errors.append("landmark of '%s': kind '%s' is not drawn by region '%s'" % [id, kind, m.region])
		if Landmarks.art_path(kind).is_empty():
			errors.append("landmark of '%s': no art for '%s'" % [id, kind])
		var n: String = str(lm.get("name", ""))
		if n.is_empty() or str(lm.get("line", "")).is_empty():
			errors.append("landmark of '%s' needs a name and a line" % id)
		elif names.has(n):
			errors.append("landmark name '%s' is used on '%s' and '%s'" % [n, names[n], id])
		names[n] = id
		var c: Vector2i = Landmarks.cell(lm)
		if not m.in_bounds(c) or not m.in_bounds(c + Vector2i.UP):
			errors.append("landmark of '%s' at %s: it and the cell above must be on the map" % [id, c])
			continue
		if m.is_walkable(c):
			errors.append("landmark of '%s' at %s stands on a cell you can walk on" % [id, c])
		var problem: String = landmark_cell_problem(m, c)
		if not problem.is_empty():
			errors.append("landmark of '%s' at %s: %s" % [id, c, problem])
		var near: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if m.in_bounds(c + d) and m.is_walkable(c + d):
				near = true
		if not near:
			errors.append("landmark of '%s' at %s: no walkable cell next to it to read it from" % [id, c])

## Why [param c] cannot hold a landmark ("" when it can): warps, signs, people, finds, gates, gear and story spots keep their cell.
static func landmark_cell_problem(m: MapData, c: Vector2i) -> String:
	var lists: Dictionary = {"warp": m.warps, "sign": m.signs, "person": m.npcs, "hidden find": m.secrets,
		"gate": m.blocks, "gear spot": m.gear_spots}
	for what: String in lists:
		for e: Dictionary in lists[what]:
			if e.has("x") and Vector2i(int(e.x), int(e.y)) == c:
				return "on a %s" % what
	for k: String in m.spots:
		var v: Variant = m.spots[k]
		if v is Array and (v as Array).size() >= 2 and Vector2i(int(v[0]), int(v[1])) == c:
			return "on the story spot '%s'" % k
	return ""

## Longest straight run of path tiles ("_" and piers) down one column of [param m] (map design
## item 508: no single road straight through the middle).
static func longest_straight_path(m: MapData) -> int:
	var best: int = 0
	for x: int in m.width:
		var run: int = 0
		for y: int in m.height:
			var ch: String = m.rows[y].substr(x, 1)
			run = run + 1 if ch == "_" or ch == "+" else 0
			best = maxi(best, run)
	return best

const MAX_OUTDOOR_W: int = 12
const MAX_OUTDOOR_H: int = 40
const THROUGH_KINDS: Array[String] = ["route", "marsh"]

static func check_shapes(errors: PackedStringArray, map_ids: PackedStringArray, layout: Dictionary) -> void:
	var places: Dictionary = layout.get("maps", {})
	for id: String in map_ids:
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		if m.outdoor and (m.width > MAX_OUTDOOR_W or m.height > MAX_OUTDOOR_H):
			errors.append("map '%s' is %dx%d; outdoor maps are at most %dx%d" % [id, m.width, m.height, MAX_OUTDOOR_W, MAX_OUTDOOR_H])
		var p: Dictionary = places.get(id, {})
		if not str(p.get("kind", "")) in THROUGH_KINDS:
			continue
		var ways: Dictionary = {}
		for w: Dictionary in m.warps:
			ways[str(MapData.split_id(str(w.to))[0])] = true
		for lid: String in Transit.lines():
			if id in Transit.stops(lid):
				for s: String in Transit.stops(lid):
					ways[s] = true
		ways.erase(id)
		if ways.size() < 2:
			errors.append("map '%s' is a %s with only one way out; give it a second exit" % [id, p.kind])

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
		for to: String in targets:
			var b: String = layout_place(places, to)
			if a.is_empty() or b.is_empty() or a == b:
				continue
			var e: String = layout_edge(a, b)
			warped[e] = true
			if not edges.has(e):
				errors.append("world layout: warp from '%s' to '%s' is not an edge (add it to neighbours)" % [id, to])
	# Boat, coach and ferry lines back an edge too, but need not be one: the world map draws
	# them as routes of their own. The Corvane ferry is also an edge (item 1290).
	for t: Variant in layout.get("lines", {}).values():
		var st: Array = ((t as Dictionary).get("stops", {}) as Dictionary).keys()
		for a: Variant in st:
			for b: Variant in st:
				var pa: String = layout_place(places, str(a))
				var pb: String = layout_place(places, str(b))
				if not pa.is_empty() and not pb.is_empty() and pa != pb:
					warped[layout_edge(pa, pb)] = true
	for e: String in edges:
		if not warped.has(e):
			errors.append("world layout: edge %s has no warp" % e)

## Boat and coach lines (area 3 items 1187-1191, 1289): known kinds, every stop is a map with
## a free arrival cell that the rest of the map reaches, and every stop of a line that is not
## run by the story has someone there whose talk offers "transit <line>".
static func check_transit(errors: PackedStringArray, map_ids: PackedStringArray, lines: Dictionary) -> void:
	var warp_in: Dictionary = entry_cells(map_ids)
	for lid: String in lines:
		var l: Dictionary = lines[lid]
		if not str(l.get("kind", "")) in Transit.KINDS:
			errors.append("line '%s': unknown kind '%s'" % [lid, l.get("kind", "")])
		var st: Dictionary = l.get("stops", {})
		if st.size() < 2:
			errors.append("line '%s' needs at least two stops" % lid)
		for sid: String in st:
			if not sid in map_ids:
				errors.append("line '%s': stop '%s' is not a map" % [lid, sid])
				continue
			var m: MapData = MapData.load_map(sid)
			var cell: Array = st[sid]
			var c: Vector2i = Vector2i(int(cell[0]), int(cell[1])) if cell.size() >= 2 else Vector2i(-1, -1)
			if not m.in_bounds(c) or not m.is_walkable(c):
				errors.append("line '%s': arrival %s on '%s' is not on floor" % [lid, c, sid])
				continue
			for n: Dictionary in m.npcs:
				if Vector2i(int(n.x), int(n.y)) == c:
					errors.append("line '%s': npc '%s' stands on the arrival %s on '%s'" % [lid, n.get("id", ""), c, sid])
			# Ways in on foot only: the stops themselves don't count.
			var others: Array = (warp_in.get(sid, []) as Array).filter(func(e: Vector2i) -> bool: return not _is_stop_cell(sid, e, lines))
			if not others.is_empty() and not reachable_cells(m, others).has(c):
				errors.append("line '%s': arrival %s on '%s' cannot be reached on foot" % [lid, c, sid])
			if not bool(l.get("story", false)) and not _offers_transit(m, lid):
				errors.append("line '%s': nobody on '%s' offers 'transit %s'" % [lid, sid, lid])

static func _is_stop_cell(sid: String, c: Vector2i, extra: Dictionary) -> bool:
	for src: Dictionary in [Transit.lines(), extra]:
		for t: Variant in src.values():
			var a: Variant = ((t as Dictionary).get("stops", {}) as Dictionary).get(sid, [])
			if a is Array and (a as Array).size() >= 2 and Vector2i(int(a[0]), int(a[1])) == c:
				return true
	return false

static func _offers_transit(m: MapData, lid: String) -> bool:
	var want: String = "transit " + lid
	for list: Array in [m.npcs, m.signs]:
		for def: Dictionary in list:
			var e: Dictionary = Dialogue.get_entry(str(def.get("dialogue", "")))
			if str(e.get("action", "")) == want:
				return true
			for ch: Variant in e.get("choices", []):
				if ch is Dictionary and str((ch as Dictionary).get("action", "")) == want:
					return true
	return false

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
		# Cracked floor drops the player onto the floor below (Shatterfloor Mine).
		if not m.drop_to.is_empty():
			var drop: Array = entries.get(m.drop_to, [])
			for e: Variant in entry_cells(PackedStringArray([id])).get(m.drop_to, []):
				drop.append(e)
			entries[m.drop_to] = drop
			var dl: Dictionary = links.get(id, {})
			dl[m.drop_to] = true
			links[id] = dl
	# Boat, coach and ferry stops (Transit): each stop is a way in from every other stop.
	for t: Variant in Transit.lines().values():
		var st: Dictionary = (t as Dictionary).get("stops", {})
		for a: Variant in st:
			var cell: Array = st[a]
			var arr: Array = entries.get(str(a), [])
			arr.append(Vector2i(int(cell[0]), int(cell[1])))
			entries[str(a)] = arr
			var l: Dictionary = links.get(str(a), {})
			for b: Variant in st:
				if b != a:
					l[str(b)] = true
			links[str(a)] = l
	for id: String in map_ids:
		if not entries.has(id):
			errors.append("map '%s': no warp leads here" % id)
			continue
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		var reach: Dictionary = reachable_cells(m, entries[id])
		check_reached(errors, id, m, reach)
		for w: Dictionary in m.warps:
			if not (links.get(str(w.get("to", "")), {}) as Dictionary).has(id):
				errors.append("map '%s': no way back from '%s'" % [id, w.get("to", "")])
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

## Every warp, NPC, sign, gear spot and the rest point of [param m] is in [param reach] or next
## to it. [param when] names the time of day for day-plan checks ("" for the plain map).
static func check_reached(errors: PackedStringArray, id: String, m: MapData, reach: Dictionary, when: String = "") -> void:
	var at: String = "" if when.is_empty() else " at " + when
	var near: Callable = func(c: Vector2i) -> bool:
		if reach.has(c):
			return true
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if reach.has(c + d):
				return true
		return false
	for w: Dictionary in m.warps:
		if not near.call(Vector2i(int(w.x), int(w.y))):
			errors.append("map '%s': warp to '%s' at %s,%s cannot be reached%s" % [id, w.get("to", ""), w.x, w.y, at])
	for n: Dictionary in m.npcs:
		if not _unplaced(n) and not near.call(Vector2i(int(n.x), int(n.y))):
			errors.append("map '%s': npc '%s' cannot be reached%s" % [id, n.get("id", ""), at])
	if not when.is_empty():
		for sc: Dictionary in m.secrets:
			if not near.call(Vector2i(int(sc.get("x", -1)), int(sc.get("y", -1)))):
				errors.append("map '%s': hidden find at %s,%s cannot be reached%s" % [id, sc.get("x"), sc.get("y"), at])
	for sg: Dictionary in m.signs:
		if not near.call(Vector2i(int(sg.x), int(sg.y))):
			errors.append("map '%s': sign at %s,%s cannot be reached%s" % [id, sg.x, sg.y, at])
	for g: Dictionary in m.gear_spots:
		var f: Array = g.get("from", [g.x, g.y])
		if not reach.has(Vector2i(int(f[0]), int(f[1]))):
			errors.append("map '%s': gear spot at %s,%s cannot be reached%s" % [id, g.x, g.y, at])
	if m.heal_point.x >= 0 and not near.call(m.heal_point):
		errors.append("map '%s': rest point cannot be reached%s" % [id, at])

## Day plans and walks (area 3 items 1212-1216): only townsfolk get them, every phase name is
## known, every place and walk cell is free floor (no warp, door, puzzle block, rest point or
## arrival cell), walks are chains of neighbouring cells from the place, and at every time of
## day the people standing around still leave every warp, sign, person and rest point reachable.
static func check_schedules(errors: PackedStringArray, map_ids: PackedStringArray) -> void:
	NpcSchedule.reset()
	var entries: Dictionary = entry_cells(map_ids)
	for id: String in map_ids:
		if id.contains(MapData.FLOOR_SEP):
			continue
		var m: MapData = MapData.load_map(id)
		if m == null:
			continue
		for def: Dictionary in m.npcs:
			if not NpcSchedule.has_plan(def):
				continue
			var who: String = "map '%s': npc '%s'" % [id, def.get("id", "")]
			if TrainerData.is_trainer(def):
				errors.append("%s is a Wayfarer and cannot have a day plan" % who)
			for e: Variant in def.get("schedule", []):
				var p: Variant = (e as Dictionary).get("phase", []) if e is Dictionary else null
				for name: Variant in (p if p is Array else [p]):
					if not str(name) in DayCycle.PHASE_NAMES:
						errors.append("%s: unknown phase '%s' in its day plan" % [who, name])
				if e is Dictionary and (e as Dictionary).has("map") and not str(e.map) in map_ids:
					errors.append("%s goes to unknown map '%s'" % [who, e.map])
			for phase: int in DayCycle.PHASE_NAMES.size():
				var pl: Dictionary = NpcSchedule.place_for(def, id, phase)
				if pl.is_empty() or not str(pl.map) in map_ids:
					continue
				var tm: MapData = MapData.load_map(str(pl.map))
				var start := Vector2i(int(pl.x), int(pl.y))
				var route: Array[Vector2i] = pl.walk
				if not route.is_empty() and route[0] != start:
					errors.append("%s: walk at %s must start on its place %s" % [who, DayCycle.phase_name(phase), start])
				var last: Vector2i = start
				for c: Vector2i in [start] + route:
					var why: String = _plan_cell_problem(tm, c, entries.get(str(pl.map), []))
					if not why.is_empty():
						errors.append("%s at %s: cell %s on '%s' %s" % [who, DayCycle.phase_name(phase), c, pl.map, why])
					if absi(c.x - last.x) + absi(c.y - last.y) > 1:
						errors.append("%s: walk jumps from %s to %s" % [who, last, c])
					last = c
	# Nobody stands in the way for good, at any time of day.
	for id: String in map_ids:
		if id.contains(MapData.FLOOR_SEP) or not entries.has(id):
			continue
		var base: MapData = MapData.load_map(id)
		if base == null:
			continue
		var planned: bool = base.npcs.any(func(d: Dictionary) -> bool: return NpcSchedule.has_plan(d)) or not NpcSchedule.visitors(id).is_empty()
		if not planned:
			continue
		for phase: int in DayCycle.PHASE_NAMES.size():
			var m: MapData = MapData.load_map(id)
			m.npcs.assign(NpcSchedule.defs_for(m, phase).filter(func(d: Dictionary) -> bool: return DayCycle.shows_at(d, phase)))
			check_reached(errors, id, m, reachable_cells(m, entries[id]), DayCycle.phase_name(phase))

## A map file's own entry for someone with a day plan (not yet moved to a time of day).
static func _unplaced(def: Dictionary) -> bool:
	return NpcSchedule.has_plan(def) and not def.has("home_place")

static func _plan_cell_problem(m: MapData, c: Vector2i, arrivals: Array) -> String:
	if not m.in_bounds(c) or not m.is_walkable(c):
		return "is not floor"
	if not m.warp_at(c).is_empty():
		return "is a warp"
	if m.kind_at(c) == TilesetFactory.Kind.DOOR:
		return "is a door"
	if c == m.heal_point:
		return "is the rest point"
	if c in arrivals:
		return "is where the player arrives"
	for b: Dictionary in m.blocks:
		if Vector2i(int(b.x), int(b.y)) == c:
			return "is a puzzle block"
	return ""

## Cells reachable from [param starts] with blocks open, gear owned and NPCs in the way.
static func reachable_cells(m: MapData, starts: Array) -> Dictionary:
	var open: Dictionary = {}
	for b: Dictionary in m.blocks:
		open[str(b.get("open_flag", ""))] = true
	m.apply_blocks(open)
	var npc_cells: Dictionary = {}
	for n: Dictionary in m.npcs:
		# People with a day plan are checked per time of day (check_schedules), placed.
		if _unplaced(n):
			continue
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
