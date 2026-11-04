extends GutTest
## New game start (boy/girl, name), the prologue partner pick and Mirela's map book.

func before_each() -> void:
	Database.load_all()

func test_new_game_without_starter_waits_for_prologue() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "  Mara ", 1, "", 1)
	assert_eq(GameState.tamer_name, "Mara")
	assert_eq(GameState.tamer_look, 1)
	assert_eq(GameState.tamer_sprite(), "tamer_f")
	assert_true(GameState.party.is_empty())
	assert_false(GameState.has_flag("got_starter"))
	GameState.choose_starter(Database.STARTERS[1])
	assert_eq(GameState.party.size(), 1)
	assert_eq(GameState.starter, Database.STARTERS[1])
	assert_true(GameState.has_flag("got_starter"))

func test_empty_name_uses_default_for_look() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "", 0, "", 0)
	assert_eq(GameState.tamer_name, GameState.DEFAULT_NAMES[0])
	GameState.new_game(GameState.Difficulty.TAMER, " ", 1, "", 1)
	assert_eq(GameState.tamer_name, GameState.DEFAULT_NAMES[1])

func test_look_survives_save_round_trip() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 1, Database.STARTERS[0], 1)
	var d: Dictionary = GameState.to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Other", 0, Database.STARTERS[0], 0)
	GameState.from_dict(d)
	assert_eq(GameState.tamer_look, 1)
	assert_eq(GameState.tamer_name, "Mara")

func test_old_save_without_look_is_boy() -> void:
	GameState.from_dict({"tamer": {"name": "Old", "color": 2}})
	assert_eq(GameState.tamer_look, 0)
	assert_eq(GameState.tamer_sprite(), "tamer")

func test_both_tamer_sheets_exist() -> void:
	for s: String in GameState.TAMER_SPRITES:
		assert_not_null(GridWalker.sheet_for(s), "missing sheet for %s" % s)

func test_signs_follow_flags() -> void:
	var m: MapData = MapData.load_map("lighthouse")
	var stairs := Vector2i(8, 1)
	assert_eq(str(m.sign_at(stairs, {}).dialogue), "lighthouse/stairs")
	assert_eq(str(m.sign_at(stairs, {"pages_all": true}).dialogue), "lighthouse/lamp_room")
	assert_eq(str(m.sign_at(stairs, {"pages_all": true, "mirela_lamp": true}).dialogue), "lighthouse/stairs")

func test_every_page_has_a_spot_and_text() -> void:
	var found: Dictionary = {}
	for f: String in DirAccess.get_files_at("res://data/maps"):
		var m: MapData = MapData.load_map(f.get_basename())
		for s: Dictionary in m.signs:
			var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
			var act: String = str(e.get("action", ""))
			if act.begins_with("page "):
				found[act.split(" ")[1]] = true
				assert_eq(str(s.get("hide_flag", "")), "page_" + act.split(" ")[1], "page sign should vanish once found")
	var kestra: Dictionary = Dialogue.get_entry("map_house/kestra")
	found[str(kestra.get("action", "")).split(" ")[1]] = true
	for i: int in range(1, Overworld.PAGE_COUNT + 1):
		assert_true(found.has(str(i)), "page %d is placed nowhere" % i)
		assert_false(Dialogue.lines_for(Dialogue.get_entry("story/page_%d" % i), {}).is_empty())

func test_page_count_and_side_progress() -> void:
	var flags: Dictionary = {"aldo_gift": true, "page_1": true, "page_4": true}
	assert_eq(Overworld.pages_found(flags), 2)
	var pages: Dictionary = {}
	for g: Dictionary in QuestLog.open_side_goals(flags):
		if g.id == "pages":
			pages = g
	assert_false(pages.is_empty())
	assert_string_contains(QuestLog.side_text(pages, flags), "(2/6)")
	assert_string_contains(QuestLog.summary(flags), "(2/6)")

func test_aldo_changes_after_dock() -> void:
	var m: MapData = MapData.load_map("lighthouse")
	# Exactly one Aldo stands on the cell in each state.
	for flags: Dictionary in [{}, {"kestra_dock_talk": true}]:
		var n: int = 0
		for def: Dictionary in m.npcs:
			if def.has("hide_flag") and bool(flags.get(str(def.hide_flag), false)):
				continue
			if def.has("show_flag") and not bool(flags.get(str(def.show_flag), false)):
				continue
			n += 1 if str(def.id).begins_with("aldo") else 0
		assert_eq(n, 1)

func test_chapters_name_every_main_goal() -> void:
	for g: Variant in QuestLog.main_goals():
		assert_false(str((g as Dictionary).get("chapter", "")).is_empty(), "goal %s has no chapter" % g.id)
	assert_string_contains(QuestLog.summary({}), "Prologue")
