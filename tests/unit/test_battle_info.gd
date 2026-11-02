extends GutTest
## Battle plan, step 3 (docs/KAMPF_PLAN_1000.md): move info card and traits that show themselves.

func before_all() -> void:
	Database.load_all()

func test_move_info_lists_numbers_and_effects() -> void:
	var t: String = CommandMenu.move_info(Database.move("Cinder Breath"))
	assert_string_contains(t, "Cinder Breath")
	assert_string_contains(t, "power 65")
	assert_string_contains(t, "Accuracy 95%")
	assert_string_contains(t, "4 Energy")
	assert_string_contains(t, "10% chance: Inflicts Scorch.")

func test_move_info_for_special_moves() -> void:
	assert_string_contains(CommandMenu.move_info(Database.move("Breeze Slice")), "Acts before other moves.")
	assert_string_contains(CommandMenu.move_info(Database.move("Squall")), "Reaches every foe.")
	assert_string_contains(CommandMenu.move_info(Database.move("Overcharge")), "leftover Energy")
	assert_string_contains(CommandMenu.move_info(Database.move("Kindle Up")), "Raises its own ATK by 1.")
	assert_string_contains(CommandMenu.move_info(Database.move("Candle Ward")), "Heals 30% of its HP.")
	assert_string_contains(CommandMenu.move_info(Database.move("Ash Call")), "Lays Ash Storm for %d turns." % BattleRules.RESONANCE_TURNS)

func test_every_move_has_an_info_card() -> void:
	for mv: MoveData in Database.moves.values():
		var lines: PackedStringArray = CommandMenu.move_info(mv).split("\n")
		# Name, kind line, accuracy line, close hint, plus one line per known effect.
		assert_gte(lines.size(), 4 + mv.effects.size(), mv.move_name)

func test_immunity_reveals_the_trait_once() -> void:
	var w: Spirling = BattleFixtures.make("Wickit", 15)
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 15)] as Array[Spirling], [w] as Array[Spirling])
	m.start()
	m._events = []
	m.apply_status(1, "drowse")
	var t: BattleEvent = BattleFixtures.first_of(m._events, BattleEvent.Type.TRAIT)
	assert_not_null(t)
	assert_eq(str(t.data.trait), w.data.trait_id)
	assert_string_contains(t.describe(), str(BattleRules.trait_info(w.data.trait_id).label))
	m._events = []
	m.apply_status(1, "drowse")
	assert_null(BattleFixtures.first_of(m._events, BattleEvent.Type.TRAIT), "only the first time")

func test_regen_trait_shows_at_end_of_turn_and_resets_after_battle() -> void:
	var mo: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var z: Spirling = BattleFixtures.make("Kindlop", 20, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([mo] as Array[Spirling], [z] as Array[Spirling])
	m.start()
	mo.hp = mo.max_hp() / 2
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.TRAIT))
	assert_true(mo.has_meta("trait_shown"))
	m.outcome = BattleModel.Outcome.FLED
	m._phase_rewards()
	assert_false(mo.has_meta("trait_shown"), "every battle starts hidden again")
