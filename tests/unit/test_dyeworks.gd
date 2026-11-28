extends GutTest
## Act II: the Drowned Dyeworks under Stillwater and its side content (data/dialogue/dyeworks.json,
## data/maps/dyeworks.json): valve rooms, the ledger and who you trust with it, Aunt Prim's
## betrayal, Widow Wenna's favour, the rival Tansy, the dye feud, seals and shift bells.

const SIDE_GOALS: Array[String] = ["dyeworks", "dye_ledger", "dye_feud", "dye_seals", "hatch_shift", "rival_tansy"]
const ACT2_PLACES: Array[String] = ["Stillwater", "Corvane Quay", "Drowned Dyeworks"]

var _snapshot: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_snapshot = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_snapshot)

func _levels() -> Array[String]:
	var out: Array[String] = []
	for id: String in MapData.all_ids():
		if str(MapData.split_id(id)[0]) == "dyeworks":
			out.append(id)
	return out

func _side(id: String) -> Dictionary:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id) == id:
			return g
	return {}

## Every NPC or sign on [param map_id], from the map file and from data/story_npcs.json.
func _all(map_id: String, kind: String) -> Array:
	var m: MapData = MapData.load_map(map_id)
	return m.npcs if kind == "npcs" else m.signs

## Flags and story vars after the action string [param action] (set_flag and trust only).
func _run(action: String, flags: Dictionary, vars: Dictionary) -> void:
	for one: String in action.split(";", false):
		var p: PackedStringArray = one.strip_edges().split(" ", false)
		if p.size() >= 2 and p[0] == "set_flag":
			flags[p[1]] = true
		elif p.size() >= 3 and p[0] == "trust":
			var eff: Dictionary = {"trust": {p[1]: int(p[2])}}
			if p.size() > 3:
				eff["use"] = {p[1]: int(p[3])}
			Trust.apply_values(eff, vars)

func test_five_levels_in_corvane() -> void:
	var levels: Array[String] = _levels()
	assert_eq(levels.size(), 5)
	for id: String in levels:
		assert_eq(MapData.load_map(id).region, "corvane", id)

func test_the_stillwater_jetty_leads_down_and_back() -> void:
	var still: MapData = MapData.load_map("stillwater")
	var down: Dictionary = still.warp_at(Vector2i(5, 9))
	assert_eq(str(down.get("to", "")), "dyeworks")
	assert_eq(still.kind_at(Vector2i(5, 9)), TilesetFactory.Kind.STAIRS)
	var hatch: MapData = MapData.load_map("dyeworks")
	assert_eq(str(hatch.warp_at(Vector2i(5, 8)).get("to", "")), "stillwater")

func test_valves_in_plate_order_open_each_room() -> void:
	var solved: int = 0
	for id: String in _levels():
		var m: MapData = MapData.load_map(id)
		var colour_at_step: Dictionary = {}
		var puzzle: String = ""
		var total: int = 0
		var plate: String = ""
		for s: Dictionary in m.signs:
			var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
			var act: PackedStringArray = str(e.get("action", "")).split(" ")
			if act[0] == "bell":
				assert_eq(act[4], "valve", id)
				puzzle = act[1]
				total = int(act[3])
				var line: String = Dialogue.lines_for(e, {})[0]
				colour_at_step[int(act[2])] = line.trim_prefix("A valve crusted with ").trim_suffix(" dye.")
			elif str(s.dialogue).ends_with("_plate"):
				plate = Dialogue.lines_for(e, {})[0]
		if puzzle == "":
			continue
		solved += 1
		assert_eq(colour_at_step.size(), total, id)
		var at: int = -1
		for n: int in range(1, total + 1):
			var pos: int = plate.find(str(colour_at_step[n]))
			assert_gt(pos, at, "%s: step %d comes next on the plate" % [id, n])
			at = pos
		GameState.flags.erase(puzzle)
		GameState.switch_progress.erase(puzzle)
		assert_eq(GameState.press_switch(puzzle, 2, total), GameState.SwitchResult.WRONG)
		for n: int in range(1, total + 1):
			GameState.press_switch(puzzle, n, total)
		assert_true(GameState.has_flag(puzzle), id)
		for b: Dictionary in m.blocks:
			assert_eq(str(b.open_flag), puzzle)
	assert_eq(solved, 4, "four valve rooms below the counting room")

func test_hint_board_gives_a_tip_after_failing() -> void:
	var e: Dictionary = Dialogue.get_entry("dyeworks/hint_board")
	var after: Array[String] = Dialogue.lines_for(e, {DungeonHints.hint_flag("dyeworks"): true})
	assert_ne(Dialogue.lines_for(e, {}), after)
	assert_true(after[0].begins_with("Tip: "))

func test_side_goals_exist_and_count_for_act_two() -> void:
	for id: String in SIDE_GOALS:
		var g: Dictionary = _side(id)
		assert_false(g.is_empty(), id)
		assert_ne(str(g.get("show", "")), "", id)
		assert_ne(str(g.get("done", "")), "", id)
		assert_true(str(g.get("where", "")) in ACT2_PLACES, "%s: %s" % [id, g.get("where", "")])

func test_ten_seals_each_gone_once_taken() -> void:
	var g: Dictionary = _side("dye_seals")
	assert_eq((g.progress as Array).size(), 10)
	var seen: Dictionary = {}
	for map_id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(map_id)
		if m == null:
			continue
		for s: Dictionary in m.signs:
			var f: String = str(Dialogue.get_entry(str(s.dialogue)).get("flag", ""))
			if f.begins_with("seal_"):
				assert_false(seen.has(f), "%s placed once" % f)
				seen[f] = true
				assert_eq(str(s.get("hide_flag", "")), f, "a seal is gone once taken")
	for f: Variant in g.progress:
		assert_true(seen.has(str(f)), str(f))

func test_hatch_clocks_out_after_three_bells_and_warns_you() -> void:
	var e: Dictionary = Dialogue.get_entry("dyeworks/hatch_check")
	assert_false(Dialogue.check(e.get("if"), {"shift_bell_1": true, "shift_bell_2": true}))
	assert_true(Dialogue.check(e.get("if"), {"shift_bell_1": true, "shift_bell_2": true, "shift_bell_3": true}))
	assert_true(str(e.action).contains("set_flag hatch_warned"))
	var bells: int = 0
	for id: String in _levels():
		for s: Dictionary in MapData.load_map(id).signs:
			if str(s.dialogue).begins_with("dyeworks/shift_bell_"):
				bells += 1
	assert_eq(bells, 3)

func test_ledger_waits_for_cardew_and_offers_take_or_burn() -> void:
	var e: Dictionary = Dialogue.get_entry("dyeworks/ledger_desk")
	assert_false(Dialogue.check(e.get("if"), {}))
	assert_true(Dialogue.check(e.get("if"), {"beat_cardew": true}))
	assert_false(Dialogue.check(e.get("if"), {"beat_cardew": true, "dye_ledger_taken": true}))
	var acts: Array[String] = []
	for c: Dictionary in e.choices:
		acts.append(str(c.action))
	assert_true(acts[0].contains("set_flag dye_ledger_taken"))
	assert_true(acts[1].contains("set_flag dye_ledger_done"), "burning ends the goal")
	var cardew: Dictionary = {}
	for n: Dictionary in MapData.load_map("dyeworks@4").npcs:
		if str(n.id) == "cardew":
			cardew = n
	assert_eq(str(cardew.get("beaten_flag", "")), "beat_cardew")

func test_prim_sells_the_ledger_unless_you_were_warned() -> void:
	var b: Dictionary = Trust.betrayal("prim_ledger")
	assert_eq(int(b.act), 2)
	assert_eq(Trust.betrayal_result(b, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(b, {"hatch_warned": true}, {}), "caught")
	assert_eq(Trust.betrayal_result(b, {"tansy_slip": true}, {}), "caught")
	var struck: Dictionary = Trust.effects(b, "struck")
	assert_lt(int(struck.coins), 0)
	assert_true(StoryBattles.has(str(struck.battle)))
	assert_gt(int(Trust.effects(b, "caught").coins), 0)
	assert_true(str(Dialogue.get_entry("dyeworks/prim_hand").action).contains("betrayal prim_ledger"))

func test_tansy_lets_slip_after_the_second_bout() -> void:
	for n: int in range(1, 4):
		assert_true(StoryBattles.has("tansy_%d" % n), "tansy_%d" % n)
	assert_eq(str(Dialogue.get_entry("dyeworks/tansy_2_defeat").flag), "tansy_slip")
	var t2: Dictionary = {}
	for n: Dictionary in MapData.load_map("dyeworks@2").npcs:
		if str(n.id) == "tansy_2":
			t2 = n
	assert_eq(str(t2.get("show_flag", "")), "beat_story_tansy_1")

func test_beating_wennas_nephews_for_coin_makes_her_sell_you() -> void:
	var def: Dictionary = Trust.favor("wenna_ledger")
	var vars: Dictionary = {}
	assert_ne(Trust.resolve(def, Trust.trust_in("wenna", vars), Trust.use_in("wenna", vars), 0.9), "betray", "an honest widow at first")
	var flags: Dictionary = {}
	_run(str(Dialogue.get_entry("dyeworks/lark_check").action), flags, vars)
	assert_eq(Trust.resolve(def, Trust.trust_in("wenna", vars), Trust.use_in("wenna", vars), 0.9), "betray", "the bookie's coin has a price")
	assert_true(StoryBattles.has(str(Trust.effects(def, "betray").battle)))
	var w: Dictionary = Dialogue.get_entry("dyeworks/wenna")
	assert_eq(str((Dialogue.variants(w)[0] as Dictionary).flag), "feud_paid", "she tells you before you hand it over")

func test_six_cousins_are_the_feud_goal() -> void:
	var want: Array = _side("dye_feud").progress
	var found: Dictionary = {}
	for map_id: String in ["corvane_quay", "stillwater", "greyreach"]:
		for n: Dictionary in _all(map_id, "npcs"):
			if str(n.get("id", "")).begins_with("cousin_"):
				assert_true(n.has("trainer"), str(n.id))
				found[str(n.beaten_flag)] = true
	assert_eq(found.size(), 6)
	for f: Variant in want:
		assert_true(found.has(str(f)), str(f))

func test_dyeworks_has_no_dead_references() -> void:
	var bad: PackedStringArray = []
	for err: String in StoryValidator.validate():
		if err.contains("dyeworks") or err.contains("prim") or err.contains("wenna") or err.contains("tansy"):
			bad.append(err)
	assert_eq(bad, PackedStringArray())
