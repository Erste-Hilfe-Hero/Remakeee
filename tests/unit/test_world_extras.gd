extends GutTest
## World extras: fast travel, side quests, lamp puzzle blocks, gauntlet, level cap title.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_travel_lists_other_rests_and_saves() -> void:
	assert_true(GameState.travel_targets("rest_spring").is_empty())
	GameState.visit_rest("rest_spring", Vector2i(4, 5))
	GameState.visit_rest("thornridge", Vector2i(9, 4))
	assert_eq(GameState.travel_targets("rest_spring"), ["thornridge"] as Array[String])
	var d: Dictionary = GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(GameState.travel_targets("fernstair").size(), 2)

func test_old_saves_count_their_last_rest() -> void:
	var d: Dictionary = GameState.to_dict()
	d.erase("rests")
	d["heal_map"] = "thornridge"
	d["heal_cell"] = [9, 4]
	GameState.from_dict(d)
	assert_true(GameState.visited_rests.has("thornridge"))

func test_switch_order() -> void:
	assert_eq(GameState.press_switch("p", 2, 3), GameState.SwitchResult.WRONG)
	assert_eq(GameState.press_switch("p", 1, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch("p", 3, 3), GameState.SwitchResult.WRONG, "skipped 2, resets")
	assert_eq(GameState.press_switch("p", 1, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch("p", 2, 3), GameState.SwitchResult.STEP)
	assert_eq(GameState.press_switch("p", 3, 3), GameState.SwitchResult.SOLVED)
	assert_true(GameState.has_flag("p"))

func test_hollow_block_opens_with_its_flag() -> void:
	var m: MapData = MapData.load_map("murk_hollow")
	m.apply_blocks(GameState.flags)
	assert_false(m.is_walkable(Vector2i(7, 2)), "closed rock")
	GameState.set_flag("hollow_lamps")
	assert_true(m.apply_blocks(GameState.flags))
	assert_true(m.is_walkable(Vector2i(7, 2)))
	assert_false(m.apply_blocks(GameState.flags), "no change the second time")

func test_hollow_store_only_reachable_through_the_gate() -> void:
	var m: MapData = MapData.load_map("murk_hollow")
	m.apply_blocks({})
	var passable: Callable = func(c: Vector2i) -> bool: return m.is_walkable(c)
	assert_true(PathFinder.find(Vector2i(5, 3), Vector2i(9, 2), passable).is_empty(), "store sealed while the gate is shut")
	m.apply_blocks({"hollow_lamps": true})
	assert_false(PathFinder.find(Vector2i(5, 3), Vector2i(9, 2), passable).is_empty())

func test_quest_dialogue_refs_exist() -> void:
	for ref: String in ["brindlewick/fisher", "fernstair/hiker", "saltmarsh/reedcutter"]:
		var e: Dictionary = Dialogue.get_entry(ref)
		assert_true(str(e.get("action", "")).begins_with("quest_show"), ref)
		var parts: PackedStringArray = str(e.action).split(" ")
		assert_not_null(Database.species(parts[2]), "%s asks for a real species" % ref)
		assert_false(Database.item(parts[3]).is_empty(), "%s rewards a real item" % ref)

func test_gauntlet_teams_scale_and_are_seeded() -> void:
	var a := Gauntlet.new(9, 40)
	var b := Gauntlet.new(9, 40)
	var ta: Array[Spirling] = a.team(29)
	var tb: Array[Spirling] = b.team(29)
	assert_eq(ta.size(), Gauntlet.TEAM_SIZE)
	for i: int in ta.size():
		assert_eq(ta[i].data.species_name, tb[i].data.species_name, "same seed, same echoes")
		assert_eq(ta[i].level, 40, "the top floor meets the ring cap")
		assert_false(ta[i].data.evolves_to != null and ta[i].data.evolve_level > 0 and ta[i].data.evolve_level <= 40, "no unevolved forms past their level")
	assert_eq(a.level_for(0), 31)
	assert_false(Database.item(a.reward_item()).is_empty())

func test_menu_title_shows_cap_only_when_capped() -> void:
	assert_false(PauseMenu.menu_title().contains("Cap"))
	GameState.difficulty = GameState.Difficulty.VETERAN
	assert_true(PauseMenu.menu_title().contains("Ring limit"))
