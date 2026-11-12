extends GutTest
## Solenne side content, part two (Act IV toward 20 h, tools/art/world/solenne_more.py): the
## Glasswind Flats, the Caravanserai with the Wayfarer ladder, the Mirage Kiln, the bells, the
## census, and the three Act IV betrayals of the Sandglass Crew's country.

const KILN: Array[String] = ["mirage_kiln", "mirage_kiln@1", "mirage_kiln@2"]
const GOALS: Array[String] = ["s4_ladder", "s4_bells", "s4_bell_line", "s4_twin", "s4_census", "s4_poacher",
	"s4_mirrors", "s4_kiln", "s4_varro"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _goal(id: String) -> Dictionary:
	for g: Variant in QuestLog.data().get("side", []):
		if str((g as Dictionary).id) == id:
			return g
	return {}

func _npc(map_id: String, id: String) -> Dictionary:
	for n: Dictionary in MapData.load_map(map_id).npcs:
		if str(n.get("id", "")) == id:
			return n
	return {}

func test_flats_open_west_of_ochrewell_after_the_tower_rift() -> void:
	var flats: MapData = MapData.load_map("glasswind_flats")
	assert_not_null(flats)
	assert_eq(flats.region, "solenne")
	assert_true(flats.outdoor)
	assert_eq(flats.encounter_table, "glasswind_flats")
	var town: MapData = MapData.load_map("ochrewell")
	var gate: Array = town.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "glasswind_flats")
	assert_eq(gate.size(), 1)
	var lock: Array = town.blocks.filter(func(b: Dictionary) -> bool: return int(b.x) == int(gate[0].x) and int(b.y) == int(gate[0].y))
	assert_eq(str(lock[0].open_flag), "rift_tower_sealed")
	var ways: Dictionary = {}
	for w: Dictionary in flats.warps:
		ways[str(MapData.split_id(str(w.to))[0])] = true
	assert_eq(ways.keys().size(), 3, "Ochrewell, the caravanserai and the kiln")
	assert_eq(WorldValidator.validate(), PackedStringArray())

func test_kiln_is_three_floors_with_its_own_kinds() -> void:
	for mid: String in KILN:
		var m: MapData = MapData.load_map(mid)
		assert_not_null(m, mid)
		assert_eq(m.encounter_table, "mirage_kiln", mid)
	for t: String in ["glasswind_flats", "mirage_kiln"]:
		for sp: Variant in EncounterTable.table(t).spawns:
			assert_eq(Database.species(str((sp as Dictionary).species)).region, "solenne", "%s: %s" % [t, sp.species])
	assert_eq(WorldValidator.check_rarity_weights(), PackedStringArray())

func test_lens_rows_open_the_stairs() -> void:
	var steps: Dictionary = {}
	for mid: String in KILN:
		for s: Dictionary in MapData.load_map(mid).signs:
			var action: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
			if action.begins_with("bell "):
				var p: PackedStringArray = action.split(" ")
				assert_eq(p[4], "lens")
				steps[p[1]] = int(p[3])
	assert_eq(steps, {"kiln_lens_1": 3, "kiln_lens_2": 4})
	assert_eq(Overworld.SWITCH_LINES["lens"].size(), 4)
	assert_eq(GameState.press_switch("kiln_lens_1", 2, 3), GameState.SwitchResult.WRONG, "out of order starts over")
	for n: int in [1, 2, 3]:
		assert_eq(GameState.press_switch("kiln_lens_1", n, 3), GameState.SwitchResult.SOLVED if n == 3 else GameState.SwitchResult.STEP)

func test_ladder_has_eight_rungs_in_order() -> void:
	var rungs: Dictionary = {}
	for mid: String in ["glasswind_flats", "caravanserai"]:
		for n: Dictionary in MapData.load_map(mid).npcs:
			var f: String = str(n.get("beaten_flag", ""))
			if f.begins_with("ladder_rung_"):
				assert_true(TrainerData.is_trainer(n), f)
				rungs[int(f.get_slice("_", 2))] = n
	assert_eq(rungs.size(), 8)
	for i: int in range(2, 9):
		assert_eq(str((rungs[i] as Dictionary).get("show_flag", "")), "ladder_rung_%d" % (i - 1), "rung %d waits for rung %d" % [i, i - 1])
	assert_has(_npc("glasswind_flats", "pell").get("win_flags", []), "c4_pell_warned", "Old Pell warns about the purse")
	assert_eq((_goal("s4_ladder").progress as Array).size(), 8)

func test_three_betrayals_and_a_shortcut() -> void:
	var warn: Dictionary = {"sabine_purse": "c4_pell_warned", "tamsin_twin": "c4_ott_warned", "venn_chains": "c4_ledger_read"}
	for id: String in warn:
		var def: Dictionary = Trust.betrayal(id)
		assert_eq(int(def.get("act", 0)), 4, id)
		assert_eq(Trust.betrayal_result(def, {}, {}), "struck", id)
		assert_eq(Trust.betrayal_result(def, {warn[id]: true}, {}), "caught", id)
		assert_true(StoryBattles.has(str(Trust.effects(def, "struck").get("battle", ""))), id + " struck ends in a duel")
	assert_eq(str(Trust.figure("venn").get("clan", "")), "sandglass")
	assert_true(Trust.betrays(Trust.trust("varro"), Trust.use("varro")), "Varro sells the shortcut unless trusted")
	assert_false(Trust.betrays(Trust.trust("ott"), Trust.use("ott")))
	assert_eq(Trust.validate(), PackedStringArray())

func test_collect_nine_bells_and_eight_kinds() -> void:
	var bells: int = 0
	for mid: String in ["glasswind_flats"] + KILN:
		for s: Dictionary in MapData.load_map(mid).signs:
			if str(s.dialogue).get_file().begins_with("bell_"):
				bells += 1
	assert_eq(bells, 9)
	assert_eq((_goal("s4_bells").progress as Array).size(), 9)
	var census: Array = _goal("s4_census").progress
	assert_eq(census.size(), 8)
	var end: Dictionary = Dialogue.get_entry("glasswind_side/ilse_end")
	var flags: Dictionary = {}
	for f: Variant in census:
		assert_false(Dialogue.check(end.get("if"), flags))
		flags[str(f)] = true
	assert_true(Dialogue.check(end.get("if"), flags))

func test_side_goals_are_listed_with_stages() -> void:
	for id: String in GOALS:
		assert_false(_goal(id).is_empty(), id)
	assert_eq((_goal("s4_bell_line").stages as Array).size(), 4)
	assert_eq((_goal("s4_twin").stages as Array).size(), 4)
	# The scarf only moves the twin goal on while it is at its first step.
	var scarf: Dictionary = Dialogue.get_entry("mirage_kiln/scarf")
	assert_true(Dialogue.check(scarf.get("if"), {"s4_twin_asked": true}))
	assert_false(Dialogue.check(scarf.get("if"), {}))

func test_story_duels_climb_toward_venn() -> void:
	var last: int = 0
	for id: String in ["varro_ambush", "tamsin_crew", "hesper_line", "oren_signal", "kiln_venn"]:
		var top: int = 0
		for e: Variant in StoryBattles.get_def(id).team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
			top = maxi(top, int(e.level))
		assert_gte(top, last, id)
		assert_lte(top, GameState.LEVEL_CAPS[GameState.LEVEL_CAPS.size() - 1], id)
		last = top
	assert_has(StoryBattles.get_def("kiln_venn").get("win_flags", []), "kiln_venn_beaten")
