extends GutTest
## Vellmarch made playable (tools/art/world/vellmarch.py from data/region2.json): the towns, roads
## and four Rifts exist as maps, the Night Barge links the quay to Brindlewick after the finale,
## everything is reachable, and the Wardens seal their Rifts and offer a rematch like Era I.

const BARGE: String = "vellmarch_night_barge"

var _d: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	_d = Region2.data()

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

func test_every_sheet_place_is_a_vellmarch_map() -> void:
	var places: Dictionary = WorldValidator.load_layout().maps
	assert_has(WorldValidator.REGIONS, "vellmarch")
	for id: String in _ids():
		assert_true(MapData.exists(id), id)
		var m: MapData = MapData.load_map(id)
		assert_eq(m.region, "vellmarch", id)
		assert_eq(str((places.get(id, {}) as Dictionary).get("region", "")), "vellmarch", id)
		assert_eq(EraManager.region_era(m.region), EraManager.Era.WASH, "%s is drawn in Era II" % id)
	for t: Dictionary in _d.towns:
		var m: MapData = MapData.load_map(str(t.id))
		assert_eq(m.display_name, str(t.name))
		assert_true(m.outdoor and m.heal_point.x >= 0, str(t.id))

func test_the_barge_runs_both_ways_after_the_finale() -> void:
	assert_eq(str(_d.arrival.line), BARGE)
	assert_eq(Transit.stops(BARGE), ["brindlewick", "cindergate_quay"] as Array[String])
	assert_eq(Transit.open_stops(BARGE, "brindlewick", {}), [] as Array[String], "shut before the finale")
	var done: Dictionary = {"story_complete": true}
	assert_eq(Transit.open_stops(BARGE, "brindlewick", done), ["cindergate_quay"] as Array[String])
	assert_eq(Transit.open_stops(BARGE, "cindergate_quay", done), ["brindlewick"] as Array[String])
	var quay: MapData = MapData.load_map("cindergate_quay")
	assert_true(quay.is_walkable(Transit.arrival(BARGE, "cindergate_quay").cell))
	# Warps both ways from the quay: every road out leads back to it.
	for w: Dictionary in quay.warps:
		var back: Array = MapData.load_map(str(w.to)).warps.filter(func(x: Dictionary) -> bool: return str(x.to) == "cindergate_quay")
		assert_gt(back.size(), 0, "%s leads back to the quay" % w.to)

func test_every_place_is_reached_from_the_quay_and_back() -> void:
	var errors: PackedStringArray = []
	WorldValidator.check_reachability(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())
	var seen: Dictionary = {"cindergate_quay": true}
	var queue: Array[String] = ["cindergate_quay"]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for w: Dictionary in MapData.load_map(cur).warps:
			var to: String = str(w.to)
			if not seen.has(to) and to in _ids():
				seen[to] = true
				queue.append(to)
	for id: String in _ids():
		assert_true(seen.has(id), "%s is reached on foot from the quay" % id)
	var entries: Dictionary = WorldValidator.entry_cells(MapData.all_ids())
	for r: Dictionary in _d.rifts:
		var w: Dictionary = Region2.wardens().filter(func(x: Dictionary) -> bool: return str(x.rift) == str(r.id))[0]
		var m: MapData = MapData.load_map(str(r.id))
		var reach: Dictionary = WorldValidator.reachable_cells(m, entries.get(str(r.id), []))
		var npc: Dictionary = _npc(str(r.id), "warden_" + str(w.id))
		var c := Vector2i(int(npc.x), int(npc.y))
		var near: bool = false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			near = near or reach.has(c + d)
		assert_true(near, "%s can be walked up to" % w.name)

func test_rift_gates_open_in_the_sheet_order() -> void:
	var want: Dictionary = {"lock_rift": "v2_ch1_done", "foundry_rift": "v2_rift_lock_sealed",
		"masque_rift": "v2_rift_foundry_sealed", "vault_rift": "v2_rift_masque_sealed"}
	for r: Dictionary in _d.rifts:
		var town: MapData = MapData.load_map(str(r.near))
		var gate: Array = town.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == str(r.id))
		assert_eq(gate.size(), 2, "%s has a gate to %s" % [r.near, r.id])
		var c := Vector2i(int(gate[0].x), int(gate[0].y))
		town.apply_blocks({})
		assert_false(town.is_walkable(c), "%s shut at first" % r.id)
		town.apply_blocks({str(want[r.id]): true})
		assert_true(town.is_walkable(c), "%s opens with %s" % [r.id, want[r.id]])
	var wren: Dictionary = _npc("cindergate_quay", "wren")
	assert_eq(str(Dialogue.get_entry(str(wren.dialogue)).get("action", "")), "set_flag v2_ch1_done")

func test_wardens_follow_the_sheet_and_seal_their_rift() -> void:
	for w: Dictionary in Region2.wardens():
		var r: Dictionary = Region2.rift(str(w.rift))
		var npc: Dictionary = _npc(str(w.rift), "warden_" + str(w.id))
		assert_false(npc.is_empty(), str(w.id))
		assert_eq(str(npc.warden), str(w.rift).trim_suffix("_rift"))
		assert_eq(str(npc.trainer), str(w.name))
		assert_eq((npc.team as Array).size(), (w.team as Array).size(), str(w.id))
		for i: int in (w.team as Array).size():
			assert_eq(str(npc.team[i].species), Region2.slot_species(w.team[i]))
			assert_eq(int(npc.team[i].level), int(w.team[i].level))
		var chapter: Array = (_d.story as Array).filter(func(c: Dictionary) -> bool: return str(c.get("rift", "")) == str(w.rift))
		assert_eq(npc.win_flags, [str(r.flag), str(chapter[0].sets)], str(w.id))
		assert_eq(npc.mend_items, [str(w.reward.item)])
		assert_eq(str(npc.rematch_after), "vellmarch_done")
		assert_eq(int(npc.money), int(w.money))
		for k: String in ["dialogue", "intro", "defeat"]:
			assert_true(Dialogue.exists(str(npc[k])), "%s %s" % [w.id, k])
	# Sealing all four ends the arc the way Region2 reads it.
	var flags: Dictionary = {"story_complete": true}
	for w: Dictionary in Region2.wardens():
		for f: Variant in _npc(str(w.rift), "warden_" + str(w.id)).win_flags:
			flags[str(f)] = true
	assert_true(Region2.next_warden(flags).is_empty())
	assert_true(flags.has("vellmarch_done"))

func test_rematches_open_after_vellmarch() -> void:
	var entries: Array = WardenRematch.region_entries()
	assert_eq(entries.size(), 4)
	for e: Dictionary in entries:
		var npc: Dictionary = _npc(str(e.map), str(e.npc))
		assert_eq(WardenRematch.entry_for(str(e.map), str(e.npc)), e)
		assert_eq(str(e.warden), str(npc.warden))
		var flags: Dictionary = {TrainerData.beaten_flag(npc, str(e.map)): true, "story_complete": true}
		assert_false(WardenRematch.can_challenge(npc, str(e.map), flags), "%s waits for vellmarch_done" % e.npc)
		flags["vellmarch_done"] = true
		assert_true(WardenRematch.can_challenge(npc, str(e.map), flags), str(e.npc))
		flags[WardenRematch.won_flag(e)] = true
		assert_false(WardenRematch.can_challenge(npc, str(e.map), flags), "won once")
		var team: Array[Spirling] = TrainerData.build_team(WardenRematch.rematch_def(npc, e), "", RandomNumberGenerator.new())
		assert_eq(team.size(), 6)
	assert_eq(WardenRematch.entries().size(), 12, "the story list stays the twelve Era I Wardens")

func test_roads_roll_the_sheet_slots_in_their_ring() -> void:
	for r: Dictionary in _d.routes:
		var m: MapData = MapData.load_map(str(r.id))
		assert_eq(m.encounter_table, str(r.id))
		var species: Array[String] = EncounterTable.species_on(str(r.id))
		for s: Dictionary in r.slots:
			assert_has(species, Region2.slot_species(s), str(r.id))
		for sp: Dictionary in EncounterTable.table(str(r.id)).spawns:
			assert_between(int(sp.min), int(r.ring[0]), int(r.ring[1]), "%s %s" % [r.id, sp.species])
			assert_between(int(sp.max), int(r.ring[0]), int(r.ring[1]), "%s %s" % [r.id, sp.species])
	var errors: PackedStringArray = []
	WorldValidator.check_table_balance(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())

func test_texts_have_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	var keep: Array = Loc.load_table("de").get("keep", [])
	for id: String in _ids():
		var m: MapData = MapData.load_map(id)
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
