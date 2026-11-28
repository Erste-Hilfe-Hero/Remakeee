extends GutTest
## KAMPF_PLAN_1000 items 30 and 416 (boss save point), 31 (a battle picked up after a restart),
## 632 (no rush), 908 (tap guard) and 912 (pause at any time).

const Side = BattleModel.Side

func _team(species: Array[String], level: int = 12) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for s: String in species:
		out.append(BattleFixtures.make(s, level))
	return out

# --- Boss save point (30, 416) ------------------------------------------------------------------

func test_boss_and_warden_battles_get_a_save_point() -> void:
	assert_true(BattleCheckpoint.save_point_due({"boss": "ember_maw"}))
	assert_true(BattleCheckpoint.save_point_due({"warden": true, "name": "Orrin"}))
	assert_false(BattleCheckpoint.save_point_due({}), "a wild battle needs none")
	assert_false(BattleCheckpoint.save_point_due({"name": "Hiker", "money": 40}), "nor a plain Wayfarer")
	assert_false(BattleCheckpoint.save_point_due({"boss": "x", "friendly": true}), "a friendly raid changes nothing to save")
	assert_ne(BattleCheckpoint.save_point_line(true), BattleCheckpoint.save_point_line(false))

# --- Picking a battle up (31) -------------------------------------------------------------------

func test_only_plain_wild_battles_off_rift_born_are_kept() -> void:
	var tamer: int = GameState.Difficulty.TAMER
	assert_true(BattleCheckpoint.resumable(true, {}, tamer))
	assert_true(BattleCheckpoint.resumable(true, {"ambush": true}, tamer))
	assert_false(BattleCheckpoint.resumable(false, {}, tamer), "a Wayfarer's caller waits for the result")
	assert_false(BattleCheckpoint.resumable(true, {"backdrop": "voice", "name": "x"}, tamer), "a fixed meeting has its own aftermath")
	assert_false(BattleCheckpoint.resumable(true, {}, GameState.Difficulty.RIFT_BORN), "closing the app is a loss there (item 630)")

func test_open_battle_goes_on_exactly_after_a_save_and_load() -> void:
	var party: Array[Spirling] = _team(["Kindlop", "Puddlet"])
	var inv: Dictionary = {"tonic": 2}
	var m: BattleModel = BattleFixtures.model(party, _team(["Zippit"], 14), true, 99)
	m.inventory = inv
	m.xp_mult = 1.5
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "field")
	var inputs: Array = []
	var records: Dictionary = {}
	BattleCheckpoint.open(records, snap, inputs, m)
	assert_true(BattleCheckpoint.is_open(records))
	m.start()
	var turns: Array[BattleAction] = [BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_item(Side.PLAYER, "tonic", 0)]
	for a: BattleAction in turns:
		inputs.append(BattleReplay.action_to_dict(a))
		m.submit_turn(a)
	assert_eq((records[BattleCheckpoint.OPEN_KEY].inputs as Array).size(), 2, "every turn is in the record at once")
	# The app closes: the save is JSON, and the journey's team and satchel are mid-battle.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(records))
	var my_party: Array[Spirling] = _team(["Kindlop", "Puddlet"], 3)
	var my_inv: Dictionary = {"tonic": 1}
	var rec: Dictionary = BattleCheckpoint.take(saved, GameState.Difficulty.TAMER)
	assert_false(rec.is_empty())
	assert_false(BattleCheckpoint.is_open(saved), "taken once, never twice")
	var back: BattleModel = BattleCheckpoint.restore(rec, my_party, my_inv)
	assert_not_null(back)
	assert_same(back.party(Side.PLAYER), my_party, "the journey's own team fights on")
	assert_same(back.inventory, my_inv)
	assert_eq(int(my_inv.get("tonic", 0)), 2, "the satchel is back to before the battle")
	assert_eq(my_party[0].level, 12)
	assert_almost_eq(back.xp_mult, 1.5, 0.001, "growth settings come along")
	back.start()
	for v: Variant in rec.inputs:
		back.submit_turn(BattleReplay.action_from_dict(v))
	assert_eq(back.turn, m.turn)
	assert_eq(my_party[0].hp, party[0].hp, "the same turns give the same battle")
	assert_eq(back.active_spirling(Side.FOE).hp, m.active_spirling(Side.FOE).hp)
	assert_eq(int(my_inv.get("tonic", 0)), int(inv.get("tonic", 0)))
	BattleCheckpoint.close(records)
	assert_false(BattleCheckpoint.is_open(records))

func test_nothing_is_picked_up_on_rift_born_or_from_junk() -> void:
	var m: BattleModel = BattleFixtures.model(_team(["Kindlop"]), _team(["Zippit"]))
	var records: Dictionary = {}
	BattleCheckpoint.open(records, BattleReplay.snapshot(m, "battle", ""), [], m)
	assert_true(BattleCheckpoint.take(records, GameState.Difficulty.RIFT_BORN).is_empty())
	assert_false(BattleCheckpoint.is_open(records))
	assert_true(BattleCheckpoint.take({BattleCheckpoint.OPEN_KEY: "junk"}, GameState.Difficulty.STORY).is_empty())
	assert_true(BattleCheckpoint.take({}, GameState.Difficulty.STORY).is_empty())

# --- Tap guard (908) ----------------------------------------------------------------------------

func test_tap_guard_steps() -> void:
	assert_eq(BattleCalm.delay_ms(0), 0, "off by default: nothing changes")
	assert_eq(BattleCalm.next_delay(BattleCalm.INPUT_DELAYS_MS.size() - 1), 0, "the last step wraps to off")
	for i: int in range(1, BattleCalm.INPUT_DELAYS_MS.size()):
		assert_gt(BattleCalm.delay_ms(i), BattleCalm.delay_ms(i - 1))
	assert_eq(BattleCalm.guard_ms(ListPicker.TAP_GUARD_MS, 0), ListPicker.TAP_GUARD_MS, "a list keeps its own guard")
	assert_eq(BattleCalm.guard_ms(ListPicker.TAP_GUARD_MS, 3), BattleCalm.delay_ms(3))
	assert_false(BattleCalm.input_ready(1000, 1000 + BattleCalm.delay_ms(2) - 1, 2))
	assert_true(BattleCalm.input_ready(1000, 1000 + BattleCalm.delay_ms(2), 2))
	assert_true(BattleCalm.input_ready(1000, 1000, 0))

func test_command_menu_waits_out_the_guard() -> void:
	var before: int = GameState.input_delay
	var menu := CommandMenu.new()
	add_child_autofree(menu)
	GameState.input_delay = 3
	menu.set_enabled(true)
	assert_false(menu.ready_for_input(), "a tap right after the menu shows picks nothing")
	GameState.input_delay = 0
	assert_true(menu.ready_for_input())
	GameState.input_delay = before

func test_new_settings_are_kept_and_listed() -> void:
	var was: Array = [GameState.input_delay, GameState.no_rush]
	GameState.input_delay = 2
	GameState.no_rush = true
	var d: Dictionary = GameState.settings_to_dict()
	GameState.input_delay = 0
	GameState.no_rush = false
	GameState.settings_from_dict(d)
	assert_eq(GameState.input_delay, 2)
	assert_true(GameState.no_rush)
	var keys: Array = []
	for r: Array in MenuHost.controls_rows():
		keys.append(r[0])
	assert_has(keys, "no_rush")
	assert_has(keys, "input_delay")
	var battle: Array = []
	for r: Array in BattleComfort.option_rows():
		battle.append(r[0])
	assert_has(battle, "no_rush")
	assert_true(BattleComfort.toggle_option("input_delay"))
	assert_eq(GameState.input_delay, 3)
	assert_true(BattleComfort.toggle_option("no_rush"))
	assert_false(GameState.no_rush)
	GameState.input_delay = was[0]
	GameState.no_rush = was[1]

# --- No rush (632) ------------------------------------------------------------------------------

func test_no_rush_keeps_the_text_waiting() -> void:
	assert_true(BattleCalm.text_auto(2.0, false, false, false), "fast speed moves the text on")
	assert_false(BattleCalm.text_auto(2.0, false, false, true), "unless No rush is on")
	assert_true(BattleCalm.text_auto(1.0, true, false, true), "Auto is the player's own choice")
	assert_false(BattleCalm.text_auto(4.0, true, true, false), "nothing moves while away or paused")
	assert_false(BattleCalm.text_auto(1.0, false, false, false))

func test_no_rush_makes_every_bond_the_calm_echo() -> void:
	for style: String in GameState.BOND_STYLES:
		assert_eq(BattleCalm.bond_style(style, true), "calm")
		assert_eq(BattleCalm.bond_style(style, false), style)

# --- Pause (912) --------------------------------------------------------------------------------

func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e

func test_pause_opens_on_the_menu_button_and_closes_on_a_tap() -> void:
	assert_true(BattleCalm.pause_toggle(_action(GameState.MENU_ACTION), false))
	assert_false(BattleCalm.pause_toggle(_action(&"ui_accept"), false), "confirm alone never pauses")
	assert_true(BattleCalm.pause_toggle(_action(&"ui_accept"), true))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	assert_false(BattleCalm.pause_toggle(down, true), "the finger going down stays on the panel")
	assert_true(BattleCalm.pause_toggle(up, true))
	assert_eq(BattleCalm.pause_lines().size(), 3)

func test_pause_stops_the_whole_battle_and_lets_it_go_on() -> void:
	var p := BattlePause.new()
	add_child_autofree(p)
	var seen: Array[bool] = []
	p.changed.connect(func(on: bool) -> void: seen.append(on))
	p.open()
	assert_true(p.is_paused())
	assert_true(get_tree().paused)
	assert_eq(p.process_mode, Node.PROCESS_MODE_ALWAYS, "the panel still hears the tap")
	p.close()
	assert_false(p.is_paused())
	assert_false(get_tree().paused)
	assert_eq(seen, [true, false] as Array[bool])
