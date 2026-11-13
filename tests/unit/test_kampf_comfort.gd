extends GutTest
## Battle plan batch 2 (docs/KAMPF_PLAN_1000.md items 568-629): guide pages, item and growth
## lines, boss phase mark, undo, favourite art and order, heal hint, settings in battle, big
## buttons and the pause on interruption (BattleHelp, BattleComfort, BattleInfo).

var _billing: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	_billing = Billing.state

func after_each() -> void:
	Billing.state = _billing
	GameState.big_buttons = false

func _duel(mine: Spirling, foe: Spirling, wild: bool = true) -> BattleModel:
	return BattleFixtures.model([mine] as Array[Spirling], [foe] as Array[Spirling], wild)

# --- Guide (568, 569, 570, 583, 591, 597) ---

func test_matchup_rows_list_learned_matchups_in_order() -> void:
	assert_eq(BattleHelp.matchup_rows({}).size(), 1, "an empty lexicon says so")
	GameState.learn_matchup(Elements.E.TIDE, "Kindlop", 2.0)
	GameState.learn_matchup(Elements.E.EMBER, "Mossling", 0.5)
	var rows: Array[Dictionary] = BattleHelp.matchup_rows(GameState.known_matchups)
	assert_eq(rows.size(), 2)
	assert_eq(str(rows[0].text), "Ember on Mossling: x.5", "sorted by element")
	assert_eq(str(rows[1].text), "Tide on Kindlop: x2")
	assert_eq(str(rows[1].hint), "Hits hard.")

func test_rule_rows_use_the_real_numbers() -> void:
	var text: String = ""
	for r: Dictionary in BattleHelp.rule_rows():
		assert_false(str(r.text).is_empty())
		assert_false(str(r.hint).is_empty())
		text += str(r.text) + "\n"
	assert_string_contains(text, "start %d" % Spirling.START_ENERGY)
	assert_string_contains(text, "%d turns" % BattleRules.RESONANCE_TURNS)
	assert_string_contains(text, "! physical, * focus, ~ status")

func test_stat_rows_look_ahead_and_leave_the_spirling_alone() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	var before: int = s.atk()
	var rows: Array[Dictionary] = BattleHelp.stat_rows(s)
	assert_eq(rows.size(), BattleHelp.STAT_SHORT.size())
	assert_eq(s.level, 10)
	assert_eq(s.atk(), before)
	var mgt: String = str(rows[1].text)
	assert_true(mgt.begins_with("MGT %d" % before), mgt)
	assert_string_contains(mgt, "R11 %d" % BattleHelp.stats_at(s, 11).atk)
	assert_string_contains(mgt, "R15 %d" % BattleHelp.stats_at(s, 15).atk)
	assert_gte(int(BattleHelp.stats_at(s, 15).atk), before)

func test_one_set_of_stat_abbreviations() -> void:
	# The team summary (MenuHost) writes the same four words.
	var summary: String = FileAccess.get_file_as_string("res://scripts/ui/MenuHost.gd")
	for key: String in ["atk", "def", "foc", "spd"]:
		assert_string_contains(summary, BattleHelp.STAT_SHORT[key] + " %d", key)

func test_kind_marks_show_on_the_info_card() -> void:
	assert_eq(BattleHelp.kind_mark(MoveData.Kind.PHYSICAL), "!")
	assert_eq(BattleHelp.kind_mark(MoveData.Kind.FOCUS), "*")
	assert_eq(BattleHelp.kind_mark(MoveData.Kind.STATUS), "~")
	var mv: MoveData = Database.move("Cinder Breath")
	assert_string_contains(CommandMenu.move_info(mv), BattleHelp.kind_mark(mv.kind) + " ")

func test_search_finds_rows_in_any_case() -> void:
	GameState.learn_matchup(Elements.E.TIDE, "Kindlop", 2.0)
	var all: Array[Dictionary] = BattleHelp.all_rows(GameState.known_matchups, GameState.records, BattleFixtures.make("Kindlop", 5))
	assert_eq(BattleHelp.search(all, "").size(), 0)
	var found: Array[Dictionary] = BattleHelp.search(all, "kindlop")
	assert_gte(found.size(), 1)
	assert_true(BattleHelp.search(all, "SWAPPING").size() >= 1, "rules are searched too")
	assert_eq(BattleHelp.search(all, "zzzz").size(), 0)

# --- Facts page additions (576, 578) and the phase mark (598) ---

func test_held_and_growth_lines() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 12)
	var foe: Spirling = BattleFixtures.make("Mossling", 10)
	var m: BattleModel = _duel(me, foe)
	assert_eq(BattleInfo.held_line(me), "")
	assert_true(BattleRules.is_holdable("spark_coil"))
	me.held = "spark_coil"
	assert_eq(BattleInfo.held_line(me), "Kindlop holds: %s" % str(Database.item("spark_coil").name))
	assert_string_contains(BattleInfo.facts(m, {}), "holds: ")
	var expected: int = int(float(foe.data.xp_yield) * foe.level / BattleModel.XP_LEVEL_DIV * m.xp_mult)
	assert_eq(BattleInfo.growth_preview(m), expected)
	var trainer: BattleModel = _duel(BattleFixtures.make("Kindlop", 12), BattleFixtures.make("Mossling", 10), false)
	assert_eq(BattleInfo.growth_preview(trainer), int(float(foe.data.xp_yield) * foe.level / BattleModel.XP_LEVEL_DIV * BattleModel.TRAINER_XP_MULT * trainer.xp_mult))

func test_phase_mark_only_while_a_phase_is_to_come() -> void:
	var m: BattleModel = _duel(BattleFixtures.make("Kindlop", 12), BattleFixtures.make("Mossling", 12))
	assert_eq(BattleInfo.phase_mark(m), -1.0, "no boss")
	var boss: String = ""
	for id: String in BattleRules.BOSSES:
		if not BattleRules.boss_phase(id).is_empty():
			boss = id
			break
	if boss.is_empty():
		pass_test("no boss with a phase in the data")
		return
	m.foe_boss = boss
	var at: float = BattleInfo.phase_mark(m)
	assert_almost_eq(at, BattleRules.boss_phase_at(boss, m.boss_difficulty), 0.001)
	assert_between(at, 0.01, 0.99)
	m.boss_phase_done = true
	assert_eq(BattleInfo.phase_mark(m), -1.0, "gone once the phase came")

# --- Undo (604) ---

func test_undo_takes_back_the_last_order_and_its_swap() -> void:
	var out: Array[BattleAction] = [BattleAction.make_move(0, 0, 0), BattleAction.make_swap(0, 3, 1)]
	var taken: Array[int] = [3]
	assert_true(BattleComfort.undo(out, taken))
	assert_eq(out.size(), 1)
	assert_eq(taken, [] as Array[int], "the swap target is free again")
	assert_true(BattleComfort.undo(out, taken))
	assert_false(BattleComfort.undo(out, taken), "nothing left")

# --- Favourite and order (605, 606) ---

func test_favourite_art_and_order() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 12, ["Bowl Over", "Cinder Breath"])
	assert_eq(BattleComfort.favourite_row(s), -1)
	assert_true(BattleComfort.toggle_favourite(s, 1))
	assert_eq(BattleComfort.favourite_row(s), 1)
	assert_true(str(BattleComfort.art_rows(s)[1].text).begins_with("* "))
	assert_eq(BattleComfort.first_row(-1, s), 1, "no art used yet: the favourite")
	assert_eq(BattleComfort.first_row(0, s), 0, "the last art wins")
	assert_true(BattleComfort.move_art(s, 1, 0))
	assert_eq(s.moves[0].move_name, "Cinder Breath")
	assert_eq(BattleComfort.favourite_row(s), 0, "the favourite follows its art")
	assert_false(BattleComfort.move_art(s, 0, 5))
	assert_false(BattleComfort.toggle_favourite(s, 0), "toggled off")

func test_favourite_survives_saving() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 12, ["Bowl Over", "Cinder Breath"])
	s.fav_art = "Cinder Breath"
	var back: Spirling = Spirling.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(back.fav_art, "Cinder Breath")
	assert_eq(back.moves[1].move_name, "Cinder Breath")

# --- Heal hint (607) ---

func test_heal_hint_picks_the_smallest_item_that_mends_fully() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 30)
	var b: Spirling = BattleFixtures.make("Mossling", 30)
	assert_true(BattleComfort.heal_hint([a, b], {"tonic": 3}).is_empty(), "nobody hurt")
	b.hp = 10
	var hint: Dictionary = BattleComfort.heal_hint([a, b], {"tonic": 1})
	assert_eq(hint.target, b)
	assert_eq(str(hint.item), "tonic")
	assert_string_contains(BattleComfort.heal_line(hint), "10/%d" % b.max_hp())
	assert_true(BattleComfort.heal_hint([a, b], {}).is_empty(), "nothing to heal with")
	b.hp = 0
	assert_true(BattleComfort.heal_hint([a, b], {"tonic": 1}).is_empty(), "defeated ones need a revive, not a heal")

# --- Settings in battle (621) and big buttons (623) ---

func test_battle_settings_toggle() -> void:
	Billing.state = {"unlocks": {}}
	var keys: Array[String] = []
	for r: Array in BattleComfort.option_rows():
		keys.append(str(r[0]))
	assert_false("preview" in keys, "a shop setting not bought stays out")
	Billing.state = {"unlocks": {"damage_preview": 1}}
	keys.clear()
	for r: Array in BattleComfort.option_rows():
		keys.append(str(r[0]))
	assert_true("preview" in keys)
	var speed: int = GameState.battle_speed
	assert_true(BattleComfort.toggle_option("speed"))
	assert_ne(GameState.battle_speed, speed)
	assert_true(BattleComfort.toggle_option("big"))
	assert_true(GameState.big_buttons)
	assert_false(BattleComfort.toggle_option("nope"))

func test_big_buttons_make_the_menu_taller_and_are_saved() -> void:
	var era: int = 1
	assert_eq(BattleComfort.menu_height(era, false), EraBattleHud.menu_height(era))
	assert_eq(BattleComfort.menu_height(era, true), EraBattleHud.menu_height(era) + (Spirling.MAX_MOVES + 1) * BattleComfort.BIG_EXTRA)
	GameState.big_buttons = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.big_buttons = false
	GameState.settings_from_dict(d)
	assert_true(GameState.big_buttons)

# --- Interruption (629) ---

func test_interruption_signals() -> void:
	assert_eq(BattleComfort.interruption(Node.NOTIFICATION_APPLICATION_PAUSED), 1)
	assert_eq(BattleComfort.interruption(Node.NOTIFICATION_APPLICATION_FOCUS_OUT), 1)
	assert_eq(BattleComfort.interruption(Node.NOTIFICATION_APPLICATION_RESUMED), -1)
	assert_eq(BattleComfort.interruption(Node.NOTIFICATION_APPLICATION_FOCUS_IN), -1)
	assert_eq(BattleComfort.interruption(Node.NOTIFICATION_READY), 0)
