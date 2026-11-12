extends GutTest
## Plan area 8: Master Wayfarers, the postgame list and the ring cap after Act I.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.VETERAN, "Tess", 0, "Kindlop")

func test_eight_masters_one_per_element_ring_45_to_55() -> void:
	assert_eq(Masters.list().size(), 8)
	var els: Dictionary = {}
	var maps: Dictionary = {}
	for m: Dictionary in Masters.list():
		els[str(m.element)] = true
		maps[str(m.map)] = true
		assert_true(Elements.E.has(str(m.element)))
		assert_between(Masters.level(m), Masters.MIN_RING, Masters.MAX_RING)
		assert_true(MapData.exists(str(m.map)), str(m.map))
		var entry: Dictionary = Dialogue.get_entry("masters/" + str(m.id))
		assert_eq(str(entry.get("action", "")), "master " + str(m.id))
		assert_false((entry.get("win_lines", []) as Array).is_empty())
	assert_eq(els.size(), 8, "each master has their own element")
	assert_eq(maps.size(), 8, "each master stands somewhere else")

func test_masters_stand_on_free_cells_after_both_rifts() -> void:
	for m: Dictionary in Masters.list():
		var map: MapData = MapData.load_map(str(m.map))
		var cell := Vector2i(int(m.x), int(m.y))
		assert_true(map.is_walkable(cell), "%s stands on a walkable cell" % m.id)
		var here: int = 0
		for n: Dictionary in map.npcs:
			if Vector2i(int(n.x), int(n.y)) == cell:
				here += 1
				if str(n.id) == "master_" + str(m.id):
					assert_eq(str(n.show_flag), Masters.SHOW_FLAG)
		assert_eq(here, 1, "nobody else stands on %s" % m.id)
		for w: Dictionary in map.warps:
			assert_ne(Vector2i(int(w.x), int(w.y)), cell)
	for e: String in WorldValidator.validate():
		assert_false(e.contains("master_"), e)

func test_teams_are_fixed_and_themed() -> void:
	for m: Dictionary in Masters.list():
		var a: Array[Spirling] = Masters.team(str(m.id))
		var b: Array[Spirling] = Masters.team(str(m.id))
		assert_eq(a.size(), Masters.TEAM_SIZE)
		var e: int = int(Elements.E[str(m.element)])
		var themed: int = 0
		for k: int in a.size():
			assert_eq(a[k].data.species_name, b[k].data.species_name, "same team every time")
			assert_between(a[k].level, Masters.MIN_RING - 2, Masters.MAX_RING)
			if e in a[k].data.elements:
				themed += 1
		assert_gt(themed, 0, "%s fields their element" % m.id)

func test_first_win_pays_80_then_20_once_a_week() -> void:
	var id: String = str(Masters.list()[0].id)
	assert_false(Masters.beaten(id))
	Masters.win(id)
	assert_eq(GameState.waymarks, Masters.FIRST_WAYMARKS)
	assert_true(Masters.beaten(id))
	assert_false(Masters.pays_now(id))
	Masters.win(id)
	assert_eq(GameState.waymarks, Masters.FIRST_WAYMARKS, "nothing more this week")
	var all: Dictionary = GameState.records["masters"]
	all[id]["week"] = "2000-W01"
	assert_true(Masters.pays_now(id))
	Masters.win(id)
	assert_eq(GameState.waymarks, Masters.FIRST_WAYMARKS + Masters.WEEKLY_WAYMARKS)
	assert_string_contains(Masters.profile(Masters.find(id)), "3 wins")

func test_cap_opens_after_act_one() -> void:
	GameState.seal_rift("cinder")
	GameState.seal_rift("tide")
	assert_lt(GameState.level_cap(), Masters.MIN_RING)
	GameState.set_flag(GameState.ACT1_END_FLAG)
	assert_eq(GameState.progress_cap(), Spirling.STORY_RING)
	assert_eq(GameState.level_cap(), Spirling.LEVEL_SANITY, "no top ring after Act I")

func test_postgame_list_after_act_one() -> void:
	assert_eq(Postgame.lines(), [] as Array[String])
	GameState.set_flag(GameState.ACT1_END_FLAG)
	var lines: Array[String] = Postgame.lines()
	assert_gt(lines.size(), 5)
	assert_string_contains("\n".join(lines), "Mend both Rifts")
	GameState.set_flag(Masters.SHOW_FLAG)
	Masters.win(str(Masters.list()[0].id))
	assert_string_contains("\n".join(Postgame.lines()), "1/8")
	assert_string_contains(PauseMenu.goals_text(), "After the story")

func test_master_achievements() -> void:
	for m: Dictionary in Masters.list():
		Masters.win(str(m.id))
	Achievements.check()
	for id: String in ["master_first", "master_half", "master_all"]:
		assert_true(Achievements.unlocked().has(id), id)
