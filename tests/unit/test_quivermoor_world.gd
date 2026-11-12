extends GutTest
## Quivermoor on foot (data/region5.json, tools/art/world/quivermoor.py): every town, route, Rift
## and landmark is a map in region "quivermoor", the rope basket from Whitecairn (Halcyra's edge)
## is the way in once the Era IV finale is done, every map is reached from there, and each Rift's
## Warden seals the Rift the story waits on.

const LINE: String = "quivermoor_rope"
const FROM: String = "whitecairn"

var _d: Dictionary = {}
var _layout: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_d = Region5.data()
	_layout = WorldValidator.load_layout()

func _ids(kind: String) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in _d[kind]:
		out.append(str(e.id))
	return out

func _all_ids() -> Array[String]:
	var out: Array[String] = []
	for k: String in ["towns", "routes", "rifts", "landmarks"]:
		out.append_array(_ids(k))
	return out

func _npc(map_id: String, id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}

func test_every_place_is_a_map_in_quivermoor() -> void:
	assert_true("quivermoor" in WorldValidator.REGIONS)
	assert_true("quivermoor" in SpirlingData.REGIONS)
	assert_true((_layout.regions as Dictionary).has("quivermoor"))
	var ids: Array[String] = _all_ids()
	assert_eq(ids.size(), 18, "5 towns, 6 routes, 4 Rifts, 3 landmarks")
	for id: String in ids:
		assert_true(MapData.exists(id), id)
		if not MapData.exists(id):
			continue
		assert_eq(MapData.load_map(id).region, "quivermoor", id)
	var kinds: Dictionary = {"towns": "town", "routes": "route", "rifts": "rift"}
	for k: String in kinds:
		for e: Dictionary in _d[k]:
			var p: Dictionary = (_layout.maps as Dictionary).get(str(e.id), {})
			assert_eq(str(p.get("region", "")), "quivermoor", str(e.id))
			assert_eq(str(p.get("kind", "")), str(kinds[k]), str(e.id))
			assert_eq(p.get("pos", []), e.pos, "%s sits on its sheet cell" % e.id)
	for l: Dictionary in _d.landmarks:
		assert_eq(str(((_layout.maps as Dictionary).get(str(l.id), {}) as Dictionary).get("inside", "")), str(l.at), str(l.id))

func test_routes_join_the_towns_they_link() -> void:
	for r: Dictionary in _d.routes:
		var to: Dictionary = {}
		for w: Dictionary in MapData.load_map(str(r.id)).warps:
			to[str(w.to)] = true
		for t: Variant in r.links:
			assert_true(to.has(str(t)), "%s leads to %s" % [r.id, t])

func test_rope_runs_from_whitecairn_after_era_four() -> void:
	var stops: Array[String] = Transit.stops(LINE)
	assert_eq(stops, [str(_d.arrival.from), str(_d.arrival.to)] as Array[String])
	assert_eq(str(_d.arrival.from), FROM)
	assert_eq(str(_d.arrival.line), LINE)
	assert_true(str(Transit.line(LINE).get("kind", "")) in Transit.KINDS)
	assert_ne(Transit.trip_line("rope", "Mossgate"), Transit.trip_line("rail", "Mossgate"), "the basket has its own trip line")
	assert_eq(str(Transit.line(LINE).get("open_flag", "")), str(_d.unlock_flag))
	assert_eq(str(_d.unlock_flag), str(EraManager.unlock_flags()["5"]), "the Era IV finale flag opens the rope")
	assert_true(Transit.open_stops(LINE, FROM, {}).is_empty(), "shut before the Era IV finale")
	assert_true(Transit.open_stops(LINE, FROM, {"halcyra_done": true}).is_empty(), "halcyra_done alone is not the era flag")
	var flags: Dictionary = {"halcyra_done": true}
	EraManager.mark_finales(flags)
	assert_eq(Transit.open_stops(LINE, FROM, flags), [str(_d.arrival.to)] as Array[String], "Halcyra's finale opens it")
	var open: Dictionary = {str(_d.unlock_flag): true}
	assert_eq(Transit.open_stops(LINE, str(_d.arrival.to), open), [FROM] as Array[String])
	var winch: Dictionary = _npc(FROM, "winch")
	assert_eq(str(winch.get("show_flag", "")), str(_d.unlock_flag), "the winch man turns up with the line")
	assert_eq(str(Dialogue.get_entry(str(winch.dialogue)).get("action", "")), "transit " + LINE)
	assert_eq(str(Dialogue.get_entry(str(_npc(str(_d.arrival.to), "winch").dialogue)).get("action", "")), "transit " + LINE)

## Walks the world from Whitecairn: warps both ways, the rope once its flag is set.
func test_every_quivermoor_map_is_reached_from_whitecairn() -> void:
	var open: Dictionary = {str(_d.unlock_flag): true}
	var seen: Dictionary = {FROM: true}
	var queue: Array[String] = [FROM]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		var next: Array[String] = []
		for w: Dictionary in MapData.load_map(cur).warps:
			next.append(str(w.to))
		for lid: String in Transit.lines():
			if cur in Transit.stops(lid) and lid == LINE:
				next.append_array(Transit.open_stops(lid, cur, open))
		for n: String in next:
			if not seen.has(n) and MapData.load_map(n).region == "quivermoor":
				seen[n] = true
				queue.append(n)
	for id: String in _all_ids():
		assert_true(seen.has(id), "%s is reached from Whitecairn" % id)

func test_every_spot_on_every_map_is_walked_to() -> void:
	var ids: PackedStringArray = MapData.all_ids()
	var mine: Dictionary = {}
	for id: String in _all_ids():
		mine[id] = true
	var errors: PackedStringArray = []
	WorldValidator.check_reachability(errors, ids)
	WorldValidator.check_secrets(errors, ids)
	WorldValidator.check_transit(errors, ids, _layout.get("lines", {}))
	WorldValidator.check_schedules(errors, ids)
	WorldValidator.check_squares(errors, ids, _layout)
	WorldValidator.check_shapes(errors, ids, _layout)
	var own: PackedStringArray = []
	for e: String in errors:
		for id: String in mine:
			if e.contains("'%s'" % id) or e.contains(LINE):
				own.append(e)
				break
	assert_eq(own.size(), 0, "\n".join(own))
	var entries: Dictionary = WorldValidator.entry_cells(ids)
	for id: String in mine:
		assert_false((entries.get(id, []) as Array).is_empty(), "%s has a way in" % id)

func test_each_rift_warden_seals_the_flag_the_story_waits_on() -> void:
	var needs: Dictionary = {}
	for c: Dictionary in _d.story:
		needs[str(c.sets)] = true
	for r: Dictionary in _d.rifts:
		var w: Dictionary = {}
		for x: Dictionary in _d.wardens:
			if str(x.id) == str(r.warden):
				w = x
		var npc: Dictionary = _npc(str(r.id), "warden_" + str(r.warden))
		assert_false(npc.is_empty(), "%s stands on %s" % [r.warden, r.id])
		assert_eq("rift_%s_sealed" % npc.get("warden", ""), str(r.flag), "sealing %s sets its flag" % r.id)
		assert_true(needs.has(str(r.flag)) or str(r.flag) == str(Region5.rift(str((_d.story as Array).back().rift)).flag), "%s moves the story" % r.flag)
		var team: Array = npc.get("team", [])
		assert_eq(team.size(), (w.team as Array).size(), str(r.warden))
		for i: int in mini(team.size(), (w.team as Array).size()):
			assert_eq(str(team[i].species), Region5.slot_species(w.team[i]), str(r.warden))
			assert_eq(int(team[i].level), int(w.team[i].level), str(r.warden))

func test_rift_doors_open_chapter_by_chapter() -> void:
	# Each Rift's road out of its town is shut until the chapter before it is done.
	for c: Dictionary in _d.story:
		if not c.has("rift"):
			continue
		var r: Dictionary = Region5.rift(str(c.rift))
		var town: MapData = MapData.load_map(str(r.near))
		var door: Array[Vector2i] = []
		for w: Dictionary in town.warps:
			if str(w.to) == str(r.id):
				door.append(Vector2i(int(w.x), int(w.y)))
		assert_false(door.is_empty(), "%s leads to %s" % [r.near, r.id])
		for b: Dictionary in town.blocks:
			if Vector2i(int(b.x), int(b.y)) in door:
				assert_eq(str(b.open_flag), str(c.needs), "%s opens with %s" % [r.id, c.needs])
		town.apply_blocks({})
		for d: Vector2i in door:
			assert_false(town.is_walkable(d), "%s is shut at first" % r.id)
		town.apply_blocks({str(c.needs): true})
		for d: Vector2i in door:
			assert_true(town.is_walkable(d), "%s opens" % r.id)

func test_story_people_start_and_end_the_chain() -> void:
	var first: Dictionary = (_d.story as Array).front()
	var last: Dictionary = (_d.story as Array).back()
	var reeve: Dictionary = _npc(str(first.at), "ashby")
	assert_false(reeve.is_empty(), "Reeve Ashby waits in %s" % first.at)
	assert_string_contains(str(Dialogue.get_entry(str(reeve.dialogue)).get("action", "")), "set_flag " + str(first.sets))
	var nell: Dictionary = _npc(str(last.at), "nell")
	assert_eq(str(nell.get("show_flag", "")), str(Region5.rift(str(last.rift)).flag), "Nell turns up once the last Rift is sealed")
	assert_string_contains(str(Dialogue.get_entry(str(nell.dialogue)).get("action", "")), "set_flag " + str(_d.finale_flag))
	var flags: Dictionary = {str(_d.finale_flag): true}
	EraManager.mark_finales(flags)
	assert_true(flags.get("era5_finale_done", false), "her flag is the Era V finale")

func test_whole_world_validator_passes_for_quivermoor() -> void:
	var own: PackedStringArray = []
	var mine: Array[String] = _all_ids()
	mine.append_array(["whitecairn", LINE])
	for e: String in WorldValidator.validate():
		for id: String in mine:
			if e.contains("'%s'" % id):
				own.append(e)
				break
	assert_eq(own.size(), 0, "\n".join(own))

func test_layout_edges_and_map_ids_are_new() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_layout(errors, MapData.all_ids(), _layout)
	var own: PackedStringArray = []
	for e: String in errors:
		for id: String in _all_ids():
			if e.contains("'%s'" % id):
				own.append(e)
				break
	assert_eq(own.size(), 0, "\n".join(own))
	var r: Dictionary = (_layout.regions as Dictionary).get("quivermoor", {})
	var halcyra: Dictionary = (_layout.regions as Dictionary).get("halcyra", {})
	assert_gt(int(r.origin[0]), int(halcyra.origin[0]) + int(halcyra.size[0]) - 1, "Quivermoor right of Halcyra")
	for k: String in ["towns", "routes", "rifts"]:
		for e: Dictionary in _d[k]:
			assert_lt(int(e.pos[0]), int(r.size[0]), str(e.id))
			assert_lt(int(e.pos[1]), int(r.size[1]), str(e.id))

func test_wild_routes_roll_their_own_table() -> void:
	for r: Dictionary in _d.routes:
		var m: MapData = MapData.load_map(str(r.id))
		assert_eq(m.encounter_table, str(r.id))
		assert_almost_eq(EncounterTable.rate(str(r.id)), 0.12, 0.001)
		var on_map: Dictionary = {}
		for c: Vector2i in WorldValidator.wild_cells(m):
			on_map[EncounterTable.ground_at(m, c)] = true
		var spawns: Array = EncounterTable.table(str(r.id)).get("spawns", [])
		assert_eq(spawns.size(), (r.slots as Array).size(), "%s table has one spawn per slot" % r.id)
		for i: int in mini(spawns.size(), (r.slots as Array).size()):
			var s: Dictionary = r.slots[i]
			var sp: Dictionary = spawns[i]
			assert_true(str(s.ground) in EncounterTable.GROUND_NAMES, "%s ground" % s.slot)
			assert_true(on_map.has(str(s.ground)), "%s has %s to hide in" % [r.id, s.ground])
			assert_eq(str(sp.species), Region5.slot_species(s), str(s.slot))
			assert_eq(int(sp.weight), int(s.weight), str(s.slot))
			assert_eq(str(sp.ground), str(s.ground), str(s.slot))
			assert_eq([int(sp.min), int(sp.max)], [int(r.ring[0]), int(r.ring[1])], str(s.slot))
		assert_between(m.secrets.size(), 3, 5, str(r.id))
