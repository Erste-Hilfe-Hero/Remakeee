extends GutTest
## Plan area 8, P2 batch: vows (plan 3406-3409) and the stair best under the Iron Oath (3400).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_three_vows_in_data() -> void:
	assert_eq(Vows.list().size(), 3)
	for id: String in ["no_shop", "no_keepsake", "starter_stays"]:
		assert_false(Vows.find(id).is_empty(), id)

func test_take_only_before_the_first_rift() -> void:
	assert_true(Vows.can_take())
	assert_true(Vows.take("no_shop"))
	assert_false(Vows.take("no_shop"), "once")
	GameState.seal_rift("cinder")
	assert_false(Vows.can_take())
	assert_false(Vows.take("no_keepsake"))

func test_kept_vows_pay_at_the_end_of_act_one() -> void:
	Vows.take("no_shop")
	Vows.take("no_keepsake")
	Vows.take("starter_stays")
	assert_true(Vows.settle().is_empty(), "nothing before the end of Act I")
	Vows.broke("no_shop")
	assert_eq(Vows.status("no_shop"), "broken")
	assert_true(Vows.give_up("no_keepsake"))
	GameState.set_flag(GameState.ACT1_END_FLAG)
	var before: int = GameState.waymarks
	Vows.settle()
	assert_eq(GameState.waymarks - before, Vows.KEPT_WAYMARKS, "only the kept vow pays")
	assert_eq(Vows.status("starter_stays"), "kept")
	Vows.settle()
	assert_eq(GameState.waymarks - before, Vows.KEPT_WAYMARKS, "once")

func test_keepsake_breaks_the_vow() -> void:
	Vows.take("no_keepsake")
	GameState.add_item("bark_wrap")
	GameState.set_held(GameState.party[0], "bark_wrap")
	assert_eq(Vows.status("no_keepsake"), "broken")

func test_starter_leaving_breaks_the_vow() -> void:
	Vows.take("starter_stays")
	var other := Spirling.new(Database.species("Mossling"), 5)
	GameState.party.append(other)
	GameState.deposit(1)
	assert_true(Vows.is_active("starter_stays"), "another Spirling may go")
	GameState.party.append(Spirling.new(Database.species("Mossling"), 5))
	GameState.deposit(0)
	assert_eq(Vows.status("starter_stays"), "broken")

func test_oath_best_in_records() -> void:
	GameState.iron_oath = true
	GameState.records["gauntlet_best_oath"] = 7
	assert_string_contains(PauseMenu.records_text(), Loc.t("Under the Iron Oath: floor %d of %d") % [7, Gauntlet.FLOORS])
