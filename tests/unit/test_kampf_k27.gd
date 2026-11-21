extends GutTest
## KAMPF_PLAN_1000 items 138 (Hesper relearns forgotten arts), 145 (kind symbol on the art rows),
## 158/159 (favourite mark and art order) and 179 (statuses stay after a battle, except on Story).

var _money: int

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	_money = GameState.money

func after_each() -> void:
	GameState.money = _money

func _duel(mine: Spirling, foe: Spirling) -> BattleModel:
	return BattleFixtures.model([mine] as Array[Spirling], [foe] as Array[Spirling], true)

# --- 179: statuses after the battle ---

func test_open_ended_statuses_linger_and_timed_ones_do_not() -> void:
	for st: String in ["scorch", "root", "jolt"]:
		assert_true(StatusRules.lingers(st), st)
		assert_eq(StatusRules.RULES[st].turns, [0, 0], st + " is open-ended")
	for st: String in ["soak", "daze", "drowse", "spent", "marked", "muddle"]:
		assert_false(StatusRules.lingers(st), st)

func test_only_story_clears_every_status() -> void:
	assert_false(StatusRules.keeps_after_battle("scorch", GameState.Difficulty.STORY))
	for d: int in [GameState.Difficulty.TAMER, GameState.Difficulty.VETERAN, GameState.Difficulty.RIFT_BORN]:
		assert_true(StatusRules.keeps_after_battle("scorch", d), str(d))
		assert_false(StatusRules.keeps_after_battle("soak", d), str(d))

func test_end_battle_keeps_a_lingering_status_only_when_asked() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 12)
	s.status = "scorch"
	s.stages["atk"] = 2
	s.end_battle(true)
	assert_eq(s.status, "scorch")
	assert_true(s.stages.is_empty(), "the rest of the battle state still goes")
	s.end_battle()
	assert_eq(s.status, "", "the default clears it, as before")
	s.status = "soak"
	s.status_turns = 2
	s.end_battle(true)
	assert_eq(s.status, "", "a timed status ends with the battle")
	assert_eq(s.status_turns, 0)
	s.status = "root"
	s.hp = 0
	s.end_battle(true)
	assert_eq(s.status, "", "a worn-out Spirling keeps nothing")

func test_the_model_keeps_the_status_only_with_keep_status() -> void:
	for keep: bool in [false, true]:
		var mine: Spirling = BattleFixtures.make("Kindlop", 12)
		var m: BattleModel = _duel(mine, BattleFixtures.make("Mossling", 5))
		m.keep_status = keep
		mine.status = "jolt"
		m.outcome = BattleModel.Outcome.WIN
		m._phase_rewards()
		assert_eq(mine.status, "jolt" if keep else "", "keep_status %s" % keep)
	assert_false(BattleModel.new([] as Array[Spirling], [] as Array[Spirling], true, 1, 0).keep_status, "sims and duels clear as before")

func test_a_lingering_status_is_saved() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 12)
	s.status = "root"
	var back: Spirling = Spirling.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.status, "root")
	var d: Dictionary = s.to_dict()
	d["status"] = "soak"
	assert_eq(Spirling.from_dict(d).status, "", "only a lingering status loads")
	d["status"] = "made_up"
	assert_eq(Spirling.from_dict(d).status, "")

func test_cure_items_work_outside_battle() -> void:
	var s: Spirling = GameState.party[0]
	s.status = "scorch"
	GameState.add_item("wake_bell", 1)
	assert_eq(GameState.use_item_outside_battle("wake_bell", s), "", "the wrong cure does nothing")
	assert_eq(GameState.item_count("wake_bell"), 1, "and is not used up")
	GameState.add_item("cooling_gel", 1)
	assert_string_contains(GameState.use_item_outside_battle("cooling_gel", s), "is cured")
	assert_eq(s.status, "")
	assert_eq(GameState.item_count("cooling_gel"), 0)
	s.status = "jolt"
	GameState.add_item("remedy", 1)
	assert_false(GameState.use_item_outside_battle("remedy", s).is_empty(), "the all-round cure takes any status")
	assert_eq(s.status, "")
	assert_eq(GameState.use_item_outside_battle("remedy", s), "", "nothing to cure")

func test_team_row_names_the_status() -> void:
	var s: Spirling = GameState.party[0]
	s.status = "scorch"
	assert_string_contains(str(MenuHost.party_entry(s).hint), "Scorch")
	s.status = ""
	assert_false(str(MenuHost.party_entry(s).hint).contains("Scorch"))

func test_rest_still_cures_and_the_guide_says_so() -> void:
	var s: Spirling = GameState.party[0]
	s.status = "root"
	s.restore()
	assert_eq(s.status, "")
	assert_string_contains("\n".join(BattleGuide.status_lines()), "On Story every status ends with the battle.")

# --- 138: Hesper relearns forgotten arts ---

func _forgetful() -> Spirling:
	return BattleFixtures.make("Kindlop", 20, ["Bowl Over"])

func test_hesper_relearns_for_the_fee() -> void:
	var s: Spirling = _forgetful()
	var names: Array[String] = GameState.relearnable(s)
	assert_true("Cinder Nip" in names)
	GameState.money = GameState.TEACHER_FEE + 10
	assert_true(GameState.relearn_at_teacher(s, "Cinder Nip"))
	assert_eq(GameState.money, 10)
	assert_true(s.moves.any(func(m: MoveData) -> bool: return m.move_name == "Cinder Nip"))

func test_hesper_wants_her_coins_and_charges_nothing_for_nothing() -> void:
	var s: Spirling = _forgetful()
	GameState.money = GameState.TEACHER_FEE - 1
	assert_false(GameState.relearn_at_teacher(s, "Cinder Nip"), "too poor")
	assert_eq(s.moves.size(), 1)
	GameState.money = GameState.TEACHER_FEE
	assert_false(GameState.relearn_at_teacher(s, "Bowl Over"), "already known")
	assert_false(GameState.relearn_at_teacher(s, "Slow Quake"), "not at this Ring")
	assert_eq(GameState.money, GameState.TEACHER_FEE)

func test_hesper_swaps_out_an_art_when_full() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20, ["Bowl Over", "Heat Haze", "Kindle Up", "Dusk Rake"])
	GameState.money = GameState.TEACHER_FEE
	assert_false(GameState.relearn_at_teacher(s, "Cinder Nip"), "full and nothing picked to forget")
	assert_eq(GameState.money, GameState.TEACHER_FEE)
	assert_true(GameState.relearn_at_teacher(s, "Cinder Nip", 0))
	assert_eq(s.moves[0].move_name, "Cinder Nip")
	assert_eq(GameState.money, 0)

func test_the_paid_memory_still_needs_its_unlock() -> void:
	var saved: Dictionary = Billing.state
	Billing.state = {}
	GameState.money = 99999
	assert_false(GameState.relearn(_forgetful(), "Cinder Nip"), "Move Memory is not owned")
	Billing.state = saved

func test_hesper_offers_the_lesson_after_her_shop() -> void:
	var e: Dictionary = Dialogue.get_entry("lighthouse/hesper")
	assert_true(str(e.get("action", "")).begins_with("shop "), "the crystal shop stays")
	assert_eq(str(e.get("next", "")), "hesper_relearn")
	var lesson: Dictionary = Dialogue.get_entry("lighthouse/hesper_relearn")
	var actions: Array[String] = []
	for c: Dictionary in Dialogue.choices_for(lesson, {}):
		actions.append(str(c.get("action", "")))
	assert_true("relearn" in actions)
	assert_true("relearn" in StoryValidator.known_actions())

# --- 145: kind symbols on the art rows ---

func test_each_kind_has_its_own_symbol_inside_5x5() -> void:
	var seen: Array[String] = []
	for kind: int in [MoveData.Kind.PHYSICAL, MoveData.Kind.FOCUS, MoveData.Kind.STATUS]:
		var px: Array = BattleHelp.kind_icon(kind)
		assert_gt(px.size(), 4, str(kind))
		for p: Variant in px:
			assert_true(int(p[0]) >= 0 and int(p[0]) < BattleHelp.KIND_ICON_SIZE and int(p[1]) >= 0 and int(p[1]) < BattleHelp.KIND_ICON_SIZE)
		assert_false(str(px) in seen, "symbols differ")
		seen.append(str(px))

# --- 158, 159: favourite mark and art order ---

func test_favourite_mark_differs_from_the_focus_mark() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 12, ["Bowl Over", "Cinder Breath"])
	assert_ne(BattleComfort.FAV_MARK, BattleHelp.kind_mark(MoveData.Kind.FOCUS))
	assert_eq(BattleComfort.fav_mark(s, s.moves[1]), "", "no favourite yet")
	BattleComfort.toggle_favourite(s, 1)
	assert_eq(BattleComfort.fav_mark(s, s.moves[1]), BattleComfort.FAV_MARK)
	assert_eq(BattleComfort.fav_mark(s, s.moves[0]), "")
	assert_true(BattleComfort.move_art(s, 1, 0), "the order can change")
	assert_eq(BattleComfort.fav_mark(s, s.moves[0]), BattleComfort.FAV_MARK, "the mark follows its art")
