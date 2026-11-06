extends GutTest
## Plan area 8, P2 batch: prepared master teams (plan 3291), weekly variants (3300) and the
## master round in the lighthouse (3292).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Online.clock_offset = 0

func test_every_master_has_three_valid_teams() -> void:
	assert_eq(Masters.list().size(), 8)
	for m: Dictionary in Masters.list():
		var teams: Array = m.get("teams", [])
		assert_eq(teams.size(), 3, str(m.id))
		for t: Variant in teams:
			assert_eq((t as Array).size(), Masters.TEAM_SIZE, str(m.id))
			for e: Dictionary in t:
				var sd: SpirlingData = Database.species(str(e.species))
				assert_not_null(sd, str(e.species))
				assert_between(int(e.level), Masters.MIN_RING - 2, Masters.MAX_RING)
				assert_between((e.moves as Array).size(), 1, 4)
				for mv: Variant in e.moves:
					assert_not_null(Database.move(str(mv)), str(mv))
				if e.has("held"):
					assert_true(BattleRules.is_holdable(str(e.held)), str(e.held))
					assert_false(bool(Database.item(str(e.held)).get("shop", false)), "no shop mementos")

func test_team_uses_the_prepared_arts() -> void:
	var m: Dictionary = Masters.list()[0]
	var team: Array[Spirling] = Masters.team(str(m.id))
	var first: Array = (m.teams as Array)[0]
	for i: int in team.size():
		assert_eq(team[i].data.species_name, str(first[i].species))
		assert_eq(team[i].moves.map(func(mv: MoveData) -> String: return mv.move_name), first[i].moves)

func test_variants_change_from_the_week_after_the_first_win() -> void:
	var id: String = str(Masters.list()[0].id)
	assert_eq(Masters.variant(id), 0, "unbeaten: the first team")
	Masters.win(id)
	assert_eq(Masters.variant(id), 0, "same week: still the first team")
	var seen: Dictionary = {}
	for w: int in 12:
		Online.clock_offset = (w + 1) * 7 * 86400
		var v: int = Masters.variant(id)
		assert_between(v, 0, 2)
		assert_eq(v, Masters.variant(id), "the same for the whole week")
		seen[v] = true
	assert_gt(seen.size(), 1, "the teams rotate")

func test_master_round_opens_after_all_eight_and_pays_once() -> void:
	assert_false(Masters.round_open())
	for m: Dictionary in Masters.list():
		Masters.win(str(m.id))
	assert_true(Masters.round_open())
	var before: int = GameState.waymarks
	Masters.finish_round(5)
	assert_eq(GameState.waymarks, before, "a partial round pays nothing")
	assert_eq(Masters.round_best(), 5)
	Masters.finish_round(8)
	assert_eq(GameState.waymarks, before + Masters.ROUND_WAYMARKS)
	Masters.finish_round(8)
	assert_eq(GameState.waymarks, before + Masters.ROUND_WAYMARKS, "only the first clear pays")
