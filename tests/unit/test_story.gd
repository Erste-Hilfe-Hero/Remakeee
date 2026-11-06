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

# --- Act I ending (plan area 4, items 1405-1413) ---------------------------------------------

func test_act1_no_longer_ends_in_a_dead_goal() -> void:
	for g: Variant in QuestLog.main_goals():
		assert_false((g as Dictionary).get("done", []).is_empty(), "goal %s can never be done" % g.id)

func test_ferry_only_needs_the_rifts_and_the_lamp() -> void:
	# The Rift hearts stay optional (item 1411).
	var flags: Dictionary = {"aldo_gift": true, "met_kestra": true, "rift_cinder_sealed": true, "rift_tide_sealed": true,
		"kestra_dock_talk": true, "aldo_dock_told": true, "mirela_lamp": true}
	assert_eq(QuestLog.current(flags).id, "crossing")

func test_ferry_sign_changes_once_open() -> void:
	var e: Dictionary = Dialogue.get_entry("brindlewick/ferry")
	assert_true(Dialogue.lines_for(e, {}).has("No crossings while the lake is restless."))
	assert_true(Dialogue.lines_for(e, {"ferry_corvane_open": true}).has("Crossings resume. Ferryman: Aldo."))

func test_act1_scenes_open_the_ferry() -> void:
	var finale: Dictionary = ScenePlayer.load_scene("act1_finale")
	var flags: Array = []
	for st: Dictionary in finale.steps:
		if st.has("flag"):
			flags.append(st.flag)
	assert_has(flags, "ferry_corvane_open")
	for id: String in ["prologue", "mirela_lamp", "act1_finale", "ferry_crossing"]:
		assert_true(ScenePlayer.exists(id), "scene %s missing" % id)

func test_old_save_with_lit_lamp_gets_the_ferry() -> void:
	GameState.from_dict({"tamer": {"name": "Old"}, "flags": {"mirela_lamp": true}})
	assert_true(GameState.has_flag("ferry_corvane_open"))

func test_kestra_dock_choice_counts_once() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)
	var e: Dictionary = Dialogue.get_entry("brindlewick/kestra_dock")
	assert_eq(Dialogue.choices_for(e, GameState.flags).size(), 2)
	GameState.set_flag("kestra_dock_talk")
	assert_eq(Dialogue.choices_for(e, GameState.flags).size(), 0, "no second chance to farm trust")
	GameState.record_choice("kestra_dock", "together")
	assert_string_contains(Dialogue.lines_for(e, GameState.flags)[0], "Save me a seat")

func test_aldo_has_a_line_per_chapter() -> void:
	var e: Dictionary = Dialogue.get_entry("lighthouse/aldo")
	var seen: Dictionary = {}
	var flags: Dictionary = {}
	for f: String in ["aldo_gift", "met_kestra", "rift_cinder_sealed", "rift_tide_sealed"]:
		flags[f] = true
		seen[Dialogue.lines_for(e, flags)[0]] = true
	assert_eq(seen.size(), 4)

func test_chapter_cards_show_once_with_the_act() -> void:
	var goals: Array = QuestLog.main_goals()
	var lamp: int = -1
	for i: int in goals.size():
		if goals[i].id == "lamp":
			lamp = i
	var card: Array[String] = QuestLog.card_for(lamp, lamp + 1, {})
	assert_eq(card, ["Act II: The Colours of Corvane", "Chapter 6: The Landing"] as Array[String])
	assert_eq(QuestLog.card_for(0, 1, {}), ["Chapter 1: The Map House"] as Array[String])
	assert_true(QuestLog.card_for(0, 1, {QuestLog.card_flag(goals[1]): true}).is_empty())
	assert_string_contains(QuestLog.summary({}), "Act I: The Hush of Veydal")
