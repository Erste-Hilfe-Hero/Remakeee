extends GutTest
## Act II side content in Corvane: the Rook Vault dungeon, the rival Nib, side goals,
## collectibles and the scripted betrayals (data/dialogue/corvane_side.json, rook_vault.json).

const SIDE_GOALS: Array[String] = ["rival_nib", "gaunt_debts", "glum_funeral", "grey_feathers",
	"quay_bounties", "fixed_race", "rook_vault"]

var _snapshot: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_snapshot = GameState.to_dict()

func after_each() -> void:
	GameState.from_dict(_snapshot)

func _rooms() -> Array[String]:
	var out: Array[String] = []
	for id: String in MapData.all_ids():
		if str(MapData.split_id(id)[0]) == "rook_vault":
			out.append(id)
	return out

func _side(id: String) -> Dictionary:
	var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	for g: Dictionary in q.side:
		if str(g.id) == id:
			return g
	return {}

func test_rook_vault_has_four_rooms_in_corvane() -> void:
	var rooms: Array[String] = _rooms()
	assert_eq(rooms.size(), 4)
	for id: String in rooms:
		assert_eq(MapData.load_map(id).region, "corvane", id)

func test_greyreach_leads_into_the_vault() -> void:
	var m: MapData = MapData.load_map("greyreach")
	var found: bool = false
	for w: Dictionary in m.warps:
		found = found or str(w.to) == "rook_vault"
	assert_true(found)

func test_feathers_in_the_wall_order_open_each_room() -> void:
	for id: String in _rooms():
		var m: MapData = MapData.load_map(id)
		var kind_at_step: Dictionary = {}
		var puzzle: String = ""
		var total: int = 0
		var wall: String = ""
		for s: Dictionary in m.signs:
			var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
			var act: PackedStringArray = str(e.get("action", "")).split(" ")
			if act[0] == "bell":
				assert_eq(act[4], "feather", id)
				puzzle = act[1]
				total = int(act[3])
				var line: String = Dialogue.lines_for(e, {})[0]
				kind_at_step[int(act[2])] = line.trim_prefix("A ").split(" rook feather")[0]
			elif str(s.dialogue).ends_with("_wall"):
				wall = Dialogue.lines_for(e, {})[0]
		if puzzle == "":
			continue
		assert_eq(kind_at_step.size(), total, id)
		var at: int = -1
		for n: int in range(1, total + 1):
			var pos: int = wall.find("the %s feather" % kind_at_step[n])
			assert_gt(pos, at, "%s: step %d comes next on the wall" % [id, n])
			at = pos
		GameState.flags.erase(puzzle)
		GameState.switch_progress.erase(puzzle)
		assert_eq(GameState.press_switch(puzzle, 2, total), GameState.SwitchResult.WRONG)
		for n: int in range(1, total + 1):
			GameState.press_switch(puzzle, n, total)
		assert_true(GameState.has_flag(puzzle), id)
		for b: Dictionary in m.blocks:
			assert_eq(str(b.open_flag), puzzle)

func test_vault_hint_board_shows_a_tip_after_failing() -> void:
	var e: Dictionary = Dialogue.get_entry("rook_vault/hint_board")
	var after: Array[String] = Dialogue.lines_for(e, {DungeonHints.hint_flag("rook_vault"): true})
	assert_ne(Dialogue.lines_for(e, {}), after)
	assert_true(after[0].begins_with("Tip: "))

func test_side_goals_exist_and_show() -> void:
	for id: String in SIDE_GOALS:
		var g: Dictionary = _side(id)
		assert_false(g.is_empty(), id)
		assert_ne(str(g.get("show", "")), "", id)
		assert_ne(str(g.get("done", "")), "", id)

func test_rival_appears_after_each_win() -> void:
	for n: int in range(1, 6):
		assert_true(StoryBattles.has("nib_%d" % n), "nib_%d" % n)
	var placed: Dictionary = {}
	for map_id: Variant in StoryPlacements.data():
		var d: Variant = StoryPlacements.data()[map_id]
		if d is Dictionary:
			for n: Dictionary in (d as Dictionary).get("npcs", []):
				if str(n.get("id", "")).begins_with("nib_"):
					placed[str(n.id)] = n
	for n: int in range(2, 5):
		assert_eq(str(placed["nib_%d" % n].show_flag), "beat_story_nib_%d" % (n - 1))
	var last: MapData = MapData.load_map("rook_vault@3")
	var nib: Dictionary = {}
	for n: Dictionary in last.npcs:
		if str(n.get("id", "")) == "nib_5":
			nib = n
	assert_eq(str(nib.get("show_flag", "")), "beat_story_nib_4")

func test_twelve_feathers_to_collect() -> void:
	var g: Dictionary = _side("grey_feathers")
	assert_eq((g.progress as Array).size(), 12)
	var seen: Dictionary = {}
	for map_id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(map_id)
		if m == null:
			continue
		for s: Dictionary in m.signs:
			var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
			var f: String = str(e.get("flag", ""))
			if f.begins_with("feather_"):
				seen[f] = true
				assert_eq(str(s.get("hide_flag", "")), f, "a feather is gone once taken")
	assert_eq(seen.size(), 12)

func test_betrayals_are_caught_with_the_warning() -> void:
	for id: String in ["nib_sale", "gaunt_cut"]:
		var b: Dictionary = Trust.betrayal(id)
		assert_eq(int(b.act), 2, id)
		assert_eq(str(b.rule), "warned", id)
		assert_true(StoryBattles.has(str(Trust.effects(b, "struck").battle)), id)
	assert_eq(Trust.betrayal("nib_sale").warned_by, ["nib_warned"])
	assert_eq(Trust.betrayal("gaunt_cut").warned_by, ["brask_warned"])

func test_corbin_warns_about_nib_after_the_third_bout() -> void:
	var e: Dictionary = Dialogue.get_entry("corvane_side/corbin_nib")
	assert_false(Dialogue.check(e.get("if"), {}))
	assert_true(Dialogue.check(e.get("if"), {"beat_story_nib_3": true}))
	assert_eq(str(e.flag), "nib_warned")

func test_side_dialogue_has_no_dead_references() -> void:
	var bad: PackedStringArray = []
	for err: String in StoryValidator.validate():
		if err.contains("corvane_side") or err.contains("rook_vault") or err.contains("nib") or err.contains("ambush_"):
			bad.append(err)
	assert_eq(bad, PackedStringArray())
