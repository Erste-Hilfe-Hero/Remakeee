extends GutTest
## Battle UX helpers: matchup knowledge, move button lines, battle speed settings.

const BF = preload("res://tests/helpers/BattleFixtures.gd")

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_matchup_unknown_until_learned() -> void:
	var foe: Spirling = Spirling.new(Database.species("Mossling"), 5)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), -1.0)
	GameState.learn_matchup(Elements.E.EMBER, "Mossling", 2.0)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), 2.0)

func test_story_difficulty_knows_every_matchup() -> void:
	GameState.difficulty = GameState.Difficulty.STORY
	var foe: Spirling = Spirling.new(Database.species("Mossling"), 5)
	assert_eq(GameState.known_multiplier(Elements.E.EMBER, foe), Elements.multiplier(Elements.E.EMBER, foe.elements()))

func test_matchups_survive_save_round_trip() -> void:
	GameState.learn_matchup(Elements.E.TIDE, "Kindlop", 2.0)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(d)
	assert_eq(float(GameState.known_matchups.get("%d:Kindlop" % Elements.E.TIDE, -1.0)), 2.0)

func test_matchup_tags() -> void:
	assert_eq(CommandMenu.matchup_tag(-1.0), "")
	assert_eq(CommandMenu.matchup_tag(1.0), "")
	assert_eq(CommandMenu.matchup_tag(2.0), "x2")
	assert_eq(CommandMenu.matchup_tag(4.0), "x4")
	assert_eq(CommandMenu.matchup_tag(0.5), "x.5")
	assert_eq(CommandMenu.matchup_tag(0.25), "x.25")

func test_move_line_shows_cost_tag_and_missing_energy() -> void:
	var mv: MoveData = BF.move(Elements.E.EMBER, 40)
	mv.energy_cost = 3
	assert_eq(CommandMenu.move_line(mv, 10, 2.0), "3E x2")
	assert_eq(CommandMenu.move_line(mv, 10, -1.0), "3E")
	assert_eq(CommandMenu.move_line(mv, 2, 2.0), "need 3E")

func test_battle_speed_cycles_and_old_setting_migrates() -> void:
	GameState.battle_speed = 0
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 2.0)
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 4.0)
	GameState.cycle_battle_speed()
	assert_eq(GameState.battle_speed_scale(), 1.0)
	GameState.settings_from_dict({"fast_forward": true})
	assert_eq(GameState.battle_speed, 1)
	GameState.settings_from_dict({"battle_speed": 2, "auto_battle": true})
	assert_eq(GameState.battle_speed, 2)
	assert_true(GameState.auto_battle)
	assert_eq(GameState.auto_mode, BattleComfort.AutoMode.WILD, "an old Auto on means Wild only (plan Chimora 100, item 22)")
	GameState.settings_from_dict({})
	assert_eq(GameState.battle_speed, 0)
	assert_false(GameState.auto_battle)

func test_auto_battle_ai_returns_legal_player_action() -> void:
	var m: BattleModel = BF.model([BF.make("Kindlop", 8)], [BF.make("Mossling", 6)])
	m.start()
	var a: BattleAction = BattleAI.new(1).choose(m, BattleModel.Side.PLAYER)
	assert_true(m.is_legal(a))

# --- Auto tab (plan Chimora 100, items 15-23) ------------------------------------------------------

func test_auto_setting_has_three_steps_and_survives_a_round_trip() -> void:
	for mode: int in [BattleComfort.AutoMode.OFF, BattleComfort.AutoMode.WILD, BattleComfort.AutoMode.STORY]:
		GameState.auto_mode = mode
		var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.settings_to_dict()))
		assert_eq(bool(d.auto_battle), mode > 0, "the old key is still written")
		GameState.auto_mode = 0
		GameState.settings_from_dict(d)
		assert_eq(GameState.auto_mode, mode)
	GameState.settings_from_dict({"auto_battle": false})
	assert_eq(GameState.auto_mode, BattleComfort.AutoMode.OFF)
	GameState.auto_mode = BattleComfort.AutoMode.STORY
	assert_eq(MenuHost.settings_rows("game").filter(func(r: Array) -> bool: return r[0] == "auto_battle")[0][1], "Auto: All story battles")
	GameState.auto_mode = 0

func test_auto_kind_per_battle() -> void:
	assert_eq(BattleComfort.auto_kind(true, {}), "wild")
	var team: Array[Spirling] = [BF.make("Mossling", 5)]
	var wayfarer: Dictionary = TrainerData.battle_info({"trainer": "Hauler Tobin", "team": []}, team, 1)
	assert_eq(BattleComfort.auto_kind(false, wayfarer), "wayfarer")
	var warden: Dictionary = TrainerData.battle_info({"trainer": "Orrin", "warden": "ember", "team": []}, team, 1)
	assert_eq(BattleComfort.auto_kind(false, warden), "boss")
	var boss: Dictionary = TrainerData.battle_info({"trainer": "Heart", "boss": "ember_heart", "team": []}, team, 1)
	assert_eq(BattleComfort.auto_kind(false, boss), "boss")
	var rival: Dictionary = wayfarer.duplicate()
	rival["rival"] = true
	assert_eq(BattleComfort.auto_kind(false, rival), "boss")
	var horde: Dictionary = TrainerData.battle_info({"trainer": "Swarm", "wild": true, "team": []}, team, 1)
	assert_eq(BattleComfort.auto_kind(true, horde), "wild")
	# Real opponents and record runs: no Auto.
	assert_eq(BattleComfort.auto_kind(false, {"name": "League rival", "friendly": true}), "off", "League echo duel")
	assert_eq(BattleComfort.auto_kind(false, {"name": "Raid", "friendly": true}), "off", "raid, tourney, live duel")
	assert_eq(BattleComfort.auto_kind(false, {"name": "Trial", "friendly": true, "warden": true}), "off", "Trials")
	assert_eq(BattleComfort.auto_kind(true, {"friendly": true}), "off")
	assert_eq(BattleComfort.auto_kind(false, BossHall.battle_info({"name": "Heart", "boss": "ember_heart"})), "off", "Boss Hall record")
	assert_eq(BattleComfort.auto_kind(false, {"name": "Floor 3", "ai": 2, "money": 10}), "off", "Tower floor")
	assert_eq(BattleComfort.auto_kind(false, {"name": "Giant", "ai": 3, "boss": "x", "warden": true}), "off", "Weekly Giant, Master tour")

func test_auto_starts_on_per_setting_and_bosses_ask() -> void:
	assert_false(BattleComfort.auto_starts_on("wild", BattleComfort.AutoMode.OFF))
	assert_true(BattleComfort.auto_starts_on("wild", BattleComfort.AutoMode.WILD))
	assert_false(BattleComfort.auto_starts_on("wayfarer", BattleComfort.AutoMode.WILD))
	assert_true(BattleComfort.auto_starts_on("wayfarer", BattleComfort.AutoMode.STORY))
	assert_false(BattleComfort.auto_starts_on("boss", BattleComfort.AutoMode.STORY), "a boss always starts off")
	assert_false(BattleComfort.auto_starts_on("off", BattleComfort.AutoMode.STORY))
	assert_eq(BattleComfort.auto_tier("boss", GameState.Difficulty.TAMER), 2)
	assert_eq(BattleComfort.auto_tier("boss", GameState.Difficulty.STORY), 1, "Story keeps tier 1")
	assert_eq(BattleComfort.auto_tier("wild", GameState.Difficulty.VETERAN), 1)
	assert_eq(BattleComfort.auto_mode_after_tap("wild", BattleComfort.AutoMode.OFF, true), BattleComfort.AutoMode.WILD)
	assert_eq(BattleComfort.auto_mode_after_tap("wild", BattleComfort.AutoMode.STORY, false), BattleComfort.AutoMode.OFF)
	assert_eq(BattleComfort.auto_mode_after_tap("boss", BattleComfort.AutoMode.WILD, true), BattleComfort.AutoMode.WILD, "only this battle")

func test_auto_hands_back_a_new_kind_to_bond() -> void:
	var m: BattleModel = BF.model([BF.make("Kindlop", 8)], [BF.make("Mossling", 6)])
	assert_true(BattleComfort.auto_yields_bond(m, {}), "Mossling is not bonded yet")
	assert_false(BattleComfort.auto_yields_bond(m, {"Mossling": {"seen": true, "bonded": true}}))
	var t: BattleModel = BF.model([BF.make("Kindlop", 8)], [BF.make("Mossling", 6)], false)
	assert_false(BattleComfort.auto_yields_bond(t, {}), "a Wayfarer's Spirling cannot be called")

func test_give_up_is_no_main_command() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/CommandMenu.gd")
	assert_false(src.contains("command_label(\"Give up\")"), "plan Chimora 100 item 43: not next to Item")
	assert_eq(BattleComfort.more_pages("More", true).back(), "Give up")
	assert_does_not_have(BattleComfort.more_pages("More"), "Give up")

## A whole Wayfarer battle on Auto: no "Who steps out?" list, no order asked (items 21, 23).
func test_full_auto_battle_needs_no_tap() -> void:
	GameState.tips_enabled = false
	GameState.battle_speed = 2
	GameState.auto_mode = BattleComfort.AutoMode.STORY
	GameState.reduce_motion = true
	# A team that loses: every faint needs a replacement, and Auto picks each one.
	var mine: Array[Spirling] = [BF.make("Kindlop", 5), BF.make("Puddlet", 5), BF.make("Mossling", 5)]
	var theirs: Array[Spirling] = [BF.make("Smoldrake", 18), BF.make("Shalebat", 18)]
	var m := BattleModel.new(mine, theirs, false, 5, 1)
	m.trainer_name = "Hauler Tobin"
	m.set_meta("quick", true)
	var host := Control.new()
	host.size = Vector2(144, 256)
	add_child_autofree(host)
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	scene.auto_kind = BattleComfort.auto_kind(false, {"story": true})
	host.add_child(scene)
	var saw_list: bool = false
	var saw_menu: bool = false
	for i: int in 20000:
		if m.is_finished():
			break
		saw_list = saw_list or scene._picker.visible
		saw_menu = saw_menu or scene._waiting_orders
		scene._text.advance_now()
		await wait_process_frames(1)
	assert_true(m.is_finished(), "the battle ended on its own")
	assert_false(saw_list, "no list opened (no \"Who steps out?\")")
	assert_false(saw_menu, "no order was asked for")
	assert_true(scene.auto_used)
	assert_gte(mine.filter(func(sp: Spirling) -> bool: return sp.is_fainted()).size(), 2, "Auto sent out a replacement after a faint")
	GameState.auto_mode = 0
