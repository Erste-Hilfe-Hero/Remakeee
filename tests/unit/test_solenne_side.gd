extends GutTest
## Solenne side content (Act IV): the Brass Veil clan in the trust system, the Veil Cistern
## dungeon, Corin's three rival duels, the seals and IOUs to collect, and the two Act IV betrayals.

const FLOORS: Array[String] = ["veil_cistern", "veil_cistern@1", "veil_cistern@2"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.reset()

func _refs(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for mid: String in FLOORS:
		for s: Dictionary in MapData.load_map(mid).signs:
			if str(s.dialogue).get_file().begins_with(prefix):
				out.append(str(s.dialogue))
	for s: Variant in StoryPlacements.data().get("ochrewell", {}).get("signs", []):
		if str((s as Dictionary).dialogue).get_file().begins_with(prefix):
			out.append(str((s as Dictionary).dialogue))
	return out

func test_brass_veil_is_a_clan_with_its_people() -> void:
	assert_true(Trust.data().clans.has("brass_veil"))
	for id: String in ["kaia", "lusk", "corin"]:
		assert_eq(str(Trust.figure(id).get("clan", "")), "brass_veil", id)
	for id: String in ["qadir", "saffi", "dunya", "mags"]:
		assert_eq(int(Trust.figure(id).get("act", 0)), 4, id)
	assert_eq(Trust.validate(), PackedStringArray())

func test_two_scripted_betrayals_in_act_four() -> void:
	for id: String in ["kaia_deed", "lusk_vault"]:
		assert_eq(int(Trust.betrayal(id).get("act", 0)), 4, id)
	# Dunya's warning turns Kaia's deed from struck into caught.
	var def: Dictionary = Trust.betrayal("kaia_deed")
	assert_eq(Trust.betrayal_result(def, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(def, {"c4_dunya_warned": true}, {}), "caught")
	assert_eq(Trust.betrayal_result(Trust.betrayal("lusk_vault"), {"c4_qadir_warned": true}, {}), "caught")

func test_veil_traitors_betray_by_default() -> void:
	# Corin and Saffi are worth more sold than kept until the player earns their trust.
	assert_true(Trust.betrays(Trust.trust("corin"), Trust.use("corin")))
	assert_true(Trust.betrays(Trust.trust("saffi"), Trust.use("saffi")))
	assert_false(Trust.betrays(Trust.trust("qadir"), Trust.use("qadir")))

func test_cistern_is_a_three_floor_dungeon_under_ochrewell() -> void:
	for mid: String in FLOORS:
		assert_not_null(MapData.load_map(mid), mid)
	var town: MapData = MapData.load_map("ochrewell")
	var door: Array = town.warps.filter(func(w: Dictionary) -> bool: return str(w.to) == "veil_cistern")
	assert_eq(door.size(), 1)
	var lock: Array = town.blocks.filter(func(b: Dictionary) -> bool: return int(b.x) == int(door[0].x) and int(b.y) == int(door[0].y))
	assert_eq(str(lock[0].open_flag), "veil_factor_beaten", "the door opens once Lusk is beaten in town")
	assert_eq(WorldValidator.validate(), PackedStringArray())

func test_valve_rows_open_the_stairs() -> void:
	var steps: Dictionary = {}
	for mid: String in FLOORS:
		for s: Dictionary in MapData.load_map(mid).signs:
			var action: String = str(Dialogue.get_entry(str(s.dialogue)).get("action", ""))
			if action.begins_with("bell "):
				var p: PackedStringArray = action.split(" ")
				assert_eq(p[4], "valve")
				steps[p[1]] = int(p[3])
	assert_eq(steps, {"cistern_valve_1": 3, "cistern_valve_2": 4})
	for n: int in [1, 2, 3]:
		assert_eq(GameState.press_switch("cistern_valve_1", n, 3), GameState.SwitchResult.SOLVED if n == 3 else GameState.SwitchResult.STEP)

func test_collect_eight_seals_and_five_ious() -> void:
	assert_eq(_refs("seal_").size(), 8)
	assert_eq(_refs("iou_").size(), 5)
	var goals: Dictionary = {}
	for g: Dictionary in QuestLog.data().get("side", []):
		goals[str(g.id)] = g
	for id: String in ["s4_veil", "s4_rival", "s4_seals", "s4_ious", "s4_graves"]:
		assert_true(goals.has(id), id)
	assert_eq((goals["s4_seals"].progress as Array).size(), 8)
	assert_eq((goals["s4_ious"].progress as Array).size(), 5)

func test_rival_and_boss_levels_climb() -> void:
	var last: int = 38
	for id: String in ["veil_corin_1", "veil_corin_2", "veil_vault", "veil_corin_3"]:
		var top: int = 0
		for e: Variant in StoryBattles.get_def(id).team:
			assert_not_null(Database.species(str(e.species)), "%s: %s" % [id, e.species])
			top = maxi(top, int(e.level))
		assert_gt(top, last, id)
		assert_lte(top, GameState.LEVEL_CAPS[GameState.LEVEL_CAPS.size() - 1], id)
		last = top
