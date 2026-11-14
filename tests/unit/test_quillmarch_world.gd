extends GutTest
## Quillmarch made playable (tools/art/world/quillmarch.py from data/region3.json): the towns,
## roads and four Rifts exist as Era III maps, the Mail Boat from Lastlamp (Vellmarch's end) runs
## after the Era II finale, every house has a room, everything is reachable, the Wardens seal their
## Rifts in order, the last one sets era3_finale_done (Halcyra's way in), and the road tables hold
## all 70 of Quillmarch's own kinds.

var _d: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_d = Region3.data()

func _ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in ["towns", "routes", "rifts"]:
		for e: Dictionary in _d[k]:
			out.append(str(e.id))
	return out

func _npc(map_id: String, npc_id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_every_sheet_place_is_an_era_three_map() -> void:
	var places: Dictionary = WorldValidator.load_layout().maps
	assert_has(WorldValidator.REGIONS, "quillmarch")
	for id: String in _ids():
		assert_true(MapData.exists(id), id)
		var m: MapData = MapData.load_map(id)
		assert_eq(m.region, "quillmarch", id)
		assert_eq(str((places.get(id, {}) as Dictionary).get("region", "")), "quillmarch", id)
		assert_eq(EraManager.region_era(m.region), EraManager.Era.ETCHED, "%s is drawn in Era III" % id)
	for t: Dictionary in _d.towns:
		var m: MapData = MapData.load_map(str(t.id))
		assert_eq(m.display_name, str(t.name))
		assert_true(m.outdoor and m.heal_point.x >= 0, str(t.id))

func test_every_town_house_has_a_room_of_its_own() -> void:
	for t: Dictionary in _d.towns:
		var m: MapData = MapData.load_map(str(t.id))
		var rooms: int = 0
		for w: Dictionary in m.warps:
			var to: String = str(w.to)
			if not to.begins_with(str(t.id) + "_"):
				continue
			rooms += 1
			var room: MapData = MapData.load_map(to)
			assert_false(room.outdoor, to)
			assert_eq(room.region, "quillmarch", to)
			assert_gt(room.warps.filter(func(b: Dictionary) -> bool: return str(b.to) == str(t.id)).size(), 0, "%s leads back out" % to)
		assert_eq(rooms, 4, "%s has four houses with rooms" % t.id)

func test_the_mail_boat_runs_from_lastlamp_after_the_era_two_finale() -> void:
	var line: String = str(_d.arrival.line)
	var stops: Array[String] = Transit.stops(line)
	assert_eq(stops.size(), 2)
	assert_has(stops, str(_d.arrival.to))
	var top: String = stops[0] if stops[1] == str(_d.arrival.to) else stops[1]
	assert_eq(top, str(Region2.data().story[-1].at), "the boat leaves from Vellmarch's last town")
	var vell: Dictionary = {"vellmarch_done": true}
	EraManager.mark_finales(vell)
	assert_eq(Transit.open_stops(line, top, vell), [str(_d.arrival.to)] as Array[String], "Vellmarch's finale opens the boat")
	assert_eq(Transit.open_stops(line, top, {}), [] as Array[String], "shut before the finale")
	var done: Dictionary = {str(_d.unlock_flag): true}
	assert_eq(Transit.open_stops(line, top, done), [str(_d.arrival.to)] as Array[String])
	assert_eq(Transit.open_stops(line, str(_d.arrival.to), done), [top] as Array[String])
	var gate: MapData = MapData.load_map(str(_d.arrival.to))
	assert_true(gate.is_walkable(Transit.arrival(line, str(_d.arrival.to)).cell))
	assert_eq(str(Dialogue.get_entry(str(_npc(str(_d.arrival.to), "boatman").dialogue)).get("action", "")), "transit " + line)
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_npcs.json"))
	var boatman: Array = ((story.get(top, {}) as Dictionary).get("npcs", []) as Array).filter(func(n: Dictionary) -> bool: return str(n.id) == "mail_boatman")
	assert_eq(boatman.size(), 1, "a boatman waits in %s" % top)
	if boatman.size() == 1:
		assert_eq(str(boatman[0].show_flag), str(_d.unlock_flag))
		assert_eq(str(Dialogue.get_entry(str(boatman[0].dialogue)).get("action", "")), "transit " + line)

func test_every_place_is_reached_from_burin_landing() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_reachability(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
	var start: String = str(_d.arrival.to)
	var seen: Dictionary = {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for w: Dictionary in MapData.load_map(cur).warps:
			var to: String = str(w.to)
			if not seen.has(to) and to in _ids():
				seen[to] = true
				queue.append(to)
	for id: String in _ids():
		assert_true(seen.has(id), "%s is reached on foot from %s" % [id, start])
	var entries: Dictionary = WorldValidator.entry_cells(MapData.all_ids())
	for w: Dictionary in Region3.wardens():
		var m: MapData = MapData.load_map(str(w.rift))
		var reach: Dictionary = WorldValidator.reachable_cells(m, entries.get(str(w.rift), []))
		var npc: Dictionary = _npc(str(w.rift), "warden_" + str(w.id))
		var c := Vector2i(int(npc.x), int(npc.y))
		var near: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			near = near or reach.has(c + d)
		assert_true(near, "%s can be walked up to" % w.name)

func test_rift_gates_open_in_the_story_order() -> void:
	for c: Dictionary in _d.story:
		if not c.has("rift"):
			continue
		var r: Dictionary = Region3.rift(str(c.rift))
		var town: MapData = MapData.load_map(str(r.near))
		var gate: Array = town.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == str(r.id))
		assert_eq(gate.size(), 2, "%s has a gate to %s" % [r.near, r.id])
		var cell := Vector2i(int(gate[0].x), int(gate[0].y))
		town.apply_blocks({})
		assert_false(town.is_walkable(cell), "%s shut at first" % r.id)
		town.apply_blocks({str(c.needs): true})
		assert_true(town.is_walkable(cell), "%s opens with %s" % [r.id, c.needs])
	var wren: Dictionary = _npc(str(_d.arrival.to), "wren")
	assert_eq(str(Dialogue.get_entry(str(wren.dialogue)).get("action", "")), "set_flag " + str(_d.story[0].sets))

func test_wardens_follow_the_sheet_and_seal_their_rift() -> void:
	var flags: Dictionary = {str(_d.unlock_flag): true}
	for w: Dictionary in Region3.wardens():
		var r: Dictionary = Region3.rift(str(w.rift))
		var npc: Dictionary = _npc(str(w.rift), "warden_" + str(w.id))
		assert_false(npc.is_empty(), str(w.id))
		assert_eq("rift_%s_sealed" % str(npc.warden), str(r.flag), "GameState.seal_rift sets the sheet flag")
		assert_eq(str(npc.trainer), str(w.name))
		assert_eq(int(npc.money), int(w.money))
		assert_eq((npc.team as Array).size(), (w.team as Array).size(), str(w.id))
		for i: int in (w.team as Array).size():
			assert_eq(str(npc.team[i].species), Region3.slot_species(w.team[i]))
			assert_eq(int(npc.team[i].level), int(w.team[i].level))
		assert_has(npc.win_flags, str(r.flag))
		for k: String in ["dialogue", "intro", "defeat"]:
			assert_true(Dialogue.exists(str(npc[k])), "%s %s" % [w.id, k])
		assert_eq(str(Region3.next_warden(flags).id), str(w.id), "met in order")
		for f: Variant in npc.win_flags:
			flags[str(f)] = true
	assert_true(Region3.next_warden(flags).is_empty())
	assert_true(flags.get(str(_d.finale_flag), false), "the last Warden ends the region")
	EraManager.mark_finales(flags)
	assert_true(flags.get("era3_finale_done", false), "and opens Era IV")
	assert_eq(Transit.open_stops("halcyra_funicular", "greyreach", flags), ["brightledge"] as Array[String], "Halcyra's funicular runs")

func test_roads_roll_the_sheet_slots_in_their_ring() -> void:
	for r: Dictionary in _d.routes:
		var m: MapData = MapData.load_map(str(r.id))
		assert_eq(m.encounter_table, str(r.id))
		var species: Array[String] = EncounterTable.species_on(str(r.id))
		for s: Dictionary in r.slots:
			assert_has(species, Region3.slot_species(s), str(r.id))
		for sp: Dictionary in EncounterTable.table(str(r.id)).spawns:
			assert_between(int(sp.min), int(r.ring[0]), int(r.ring[1]), "%s %s" % [r.id, sp.species])
			assert_between(int(sp.max), int(r.ring[0]), int(r.ring[1]), "%s %s" % [r.id, sp.species])
		assert_eq(m.npcs.filter(func(n: Dictionary) -> bool: return n.has("trainer") and not str(n.id).begins_with("q3_")).size(), 2, "%s has two Wayfarers (side content apart)" % r.id)
	var errors: PackedStringArray = []
	WorldValidator.check_table_balance(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
	assert_eq(WorldValidator.check_rarity_weights(), PackedStringArray())

func test_every_own_kind_lives_on_a_road() -> void:
	var wild: Dictionary = {}
	for r: Dictionary in _d.routes:
		for sp: String in EncounterTable.species_on(str(r.id)):
			wild[sp] = true
			assert_eq(Database.species(sp).region, "quillmarch", "%s on %s is a Quillmarch kind" % [sp, r.id])
	var own: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region != "quillmarch":
			continue
		own += 1
		assert_true(wild.has(sd.species_name), "%s can be met on a Quillmarch road" % sd.species_name)
	assert_eq(own, 70)

func test_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	var keep: Array = Loc.load_table("de").get("keep", [])
	var ids: Array[String] = _ids()
	for t: Dictionary in _d.towns:
		for w: Dictionary in MapData.load_map(str(t.id)).warps:
			if str(w.to).begins_with(str(t.id) + "_"):
				ids.append(str(w.to))
	for id: String in ids:
		var m: MapData = MapData.load_map(id)
		assert_true(de.has(m.display_name) or m.display_name in keep, "DE missing: %s" % m.display_name)
		for e: Dictionary in m.npcs + m.signs:
			for k: String in ["dialogue", "intro", "defeat"]:
				if not e.has(k):
					continue
				var entry: Dictionary = Dialogue.get_entry(str(e[k]))
				var lines: Array = entry.get("lines", []).duplicate()
				for a: Variant in entry.get("after_flag", []):
					lines.append_array((a as Dictionary).get("lines", []))
				for s: Variant in lines:
					assert_true(de.has(str(s)) or str(s) in keep, "DE missing: %s" % s)
