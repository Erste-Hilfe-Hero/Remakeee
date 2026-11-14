extends GutTest
## Battle plan (docs/KAMPF_PLAN_1000.md) items 920 and 936: a battle can be played with a screen
## reader (every control a player can reach has a spoken name, the bond call is said in words),
## and the foe AI decides within its time budget.

var _settings: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	Loc.set_language("en")

func after_each() -> void:
	GameState.settings_from_dict(_settings)
	Loc.set_language("en")

# --- 920: screen reader ---------------------------------------------------------------------

## Every visible control a player can press or focus, below [param n].
func _reachable(n: Node, out: Array[Control]) -> void:
	for c: Node in n.get_children():
		if c is Control and not (c as Control).is_visible_in_tree():
			continue
		if c is BaseButton or (c is Control and (c as Control).focus_mode != Control.FOCUS_NONE):
			out.append(c as Control)
		_reachable(c, out)

func _spoken(c: Control) -> String:
	if not c.accessibility_name.is_empty():
		return c.accessibility_name
	if c is Button:
		return (c as Button).text
	return ""

func _settled_scene(front: int) -> BattleScene:
	GameState.reduce_motion = true
	var m: BattleModel = load("res://tools/era_battle_shots_runner.gd").formation_model([front, front])
	var host := Control.new()
	host.size = Vector2(270, 480)
	add_child_autofree(host)
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	host.add_child(scene)
	await wait_process_frames(3)
	for i: int in 1800:
		if scene._menu != null and scene._menu._content != null and scene._menu._content.visible:
			break
		scene._text.advance_now()
		await wait_process_frames(1)
	return scene

func test_every_reachable_battle_control_has_a_spoken_name() -> void:
	for front: int in [1, 2]:
		var scene: BattleScene = await _settled_scene(front)
		assert_true(scene._menu._content.visible, "%dv%d: the command menu opened" % [front, front])
		var reach: Array[Control] = []
		_reachable(scene, reach)
		assert_gt(reach.size(), 2, "the command rows are reachable")
		for c: Control in reach:
			assert_false(_spoken(c).strip_edges().is_empty(), "%dv%d: %s has no spoken name" % [front, front, c.get_path()])
		for b: Button in scene._menu._move_buttons:
			if b.is_visible_in_tree():
				assert_false(b.accessibility_description.is_empty(), "art buttons carry their info card")

func test_battle_text_and_strips_reach_screen_readers() -> void:
	var scene: BattleScene = await _settled_scene(1)
	assert_eq(scene._text._label.accessibility_live, AccessibilityServer.LIVE_POLITE, "the log is read as it appears")
	var m: BattleModel = scene.model
	for side: int in 2:
		var sp: SpirlingSprite = scene._sprite(side, 0)
		assert_eq(sp.accessibility_name, m.active_spirling(side).display_name())

func _bond(sky: bool) -> BondMinigame:
	var g := BondMinigame.new()
	add_child_autofree(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	g.rng = rng
	g._plan = {"phases": [[0, 2, 1, 0]], "afterglow": -1, "state": "none", "sky": sky, "element": 0}
	g._all_taps.clear()
	return g

func test_the_bond_call_is_said_in_words() -> void:
	var g: BondMinigame = _bond(false)
	assert_eq(g._hint.accessibility_live, AccessibilityServer.LIVE_POLITE)
	g._start_phase(0)
	assert_eq(g._hint.text, "Listen to the call...")
	assert_eq(g._hint.accessibility_name, "Listen to the call... The call: Diamond, Triangle, Square, Diamond.")
	g._process(BondEcho.call_duration(4) + BondEcho.GAP_TIME + 0.01)
	assert_eq(g._phase, BondMinigame.Phase.ECHO)
	assert_string_contains(g._hint.accessibility_name, "left Diamond, up Square, right Triangle")
	# The keys the reader names are the keys that answer: left, up, right.
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_left"]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = true
		g._unhandled_input(e)
	assert_eq(g._phase, BondMinigame.Phase.RESULT, "a flawless echo by keys alone")
	assert_eq(g._hint.accessibility_name, BondEcho.result_words(1.0))

func test_sky_marks_have_their_own_words_and_german_follows() -> void:
	assert_eq(BondMinigame.spoken_call([0, 1, 2], true), "The call: Moon, Star, Spark.")
	Loc.set_language("de")
	assert_eq(BondMinigame.spoken_call([0, 1, 2], false), "Der Ruf: Raute, Quadrat, Dreieck.")
	assert_eq(BondMinigame.spoken_keys(true), "Spiel nach mit den Tasten: links Mond, oben Stern, rechts Funke.")

func test_mine_says_that_any_tap_counts() -> void:
	var g: BondMinigame = _bond(false)
	g.run_mine(g._plan)
	assert_string_contains(g._hint.accessibility_name, "Any tap or the accept key counts.")

# --- 936: AI speed --------------------------------------------------------------------------

## Plays [param m] for up to [param turns] turns: before each turn [param ai] picks for every
## foe slot and each pick is timed; the player rests or uses its first art.
func _time_ai(ai: BattleAI, m: BattleModel, turns: int) -> Dictionary:
	var times: Array[int] = []
	for t: int in turns:
		if m.is_finished():
			break
		if m.needs_player_switch():
			m.submit_switch(m.swap_candidates(0, m.switch_slot())[0])
			continue
		for slot: int in m.standing_slots(BattleModel.Side.FOE):
			var t0: int = Time.get_ticks_usec()
			ai.choose(m, BattleModel.Side.FOE, slot)
			times.append(Time.get_ticks_usec() - t0)
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			var legal: Array[BattleAction] = m.legal_actions(0, slot)
			var a: BattleAction = legal[0]
			for b: BattleAction in legal:
				if b.kind == BattleAction.Kind.MOVE:
					a = b
					break
			acts.append(a)
		m.submit_actions(acts)
	var worst: int = 0
	var sum: int = 0
	for us: int in times:
		worst = maxi(worst, us)
		sum += us
	return {"decisions": times.size(), "worst_ms": worst / 1000.0, "mean_ms": sum / 1000.0 / maxi(times.size(), 1)}

func test_ai_decides_within_its_budget() -> void:
	for front: int in [1, 3]:
		for level: int in [1, 2, 3]:
			var m: BattleModel = load("res://tools/era_battle_shots_runner.gd").formation_model([front, front])
			m.start()
			var r: Dictionary = _time_ai(BattleAI.new(level), m, 12)
			assert_gt(int(r.decisions), 0)
			assert_lt(float(r.worst_ms), BattleAI.THINK_BUDGET_MS,
				"AI %d in %dv%d: worst decision %.1f ms" % [level, front, front, float(r.worst_ms)])
			gut.p("AI %d %dv%d: %d decisions, mean %.2f ms, worst %.2f ms" % [level, front, front, int(r.decisions), float(r.mean_ms), float(r.worst_ms)])
