extends GutTest
## Plan area 2, items 678-679: the Warden turning point.

func _team(names: Array, lvl: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n: String in names:
		out.append(Spirling.new(Database.species(n), lvl, rng))
	return out

func _model(rule: String, foes: int = 3) -> BattleModel:
	var names: Array = ["Kindlop", "Zippit", "Shalebat"].slice(0, foes)
	var m := BattleModel.new(_team(["Kindlop", "Zippit"], 20), _team(names, 20), false, 11, 0)
	m.trainer_name = "Warden Test"
	m.foe_rule = rule
	m.start()
	return m

func _drop_foe(m: BattleModel) -> Array[BattleEvent]:
	m._events = []
	var foe: Spirling = m.active_spirling(BattleModel.Side.FOE)
	m.deal_damage(BattleModel.Side.FOE, foe.hp)
	return m._events

func _has(events: Array[BattleEvent], t: BattleEvent.Type, key: String = "") -> bool:
	for e: BattleEvent in events:
		if e.type == t and (key.is_empty() or e.data.has(key)):
			return true
	return false

func test_turns_at_second_to_last() -> void:
	var m := _model("ember_pulse")
	var ev := _drop_foe(m)
	assert_false(m.rule_turned, "two foes still stand")
	m.slots[BattleModel.Side.FOE][0] = 1
	ev = _drop_foe(m)
	assert_true(m.rule_turned)
	assert_true(_has(ev, BattleEvent.Type.RULE, "turning"), "turning banner")
	var line_kinds: Array = []
	for e: BattleEvent in ev:
		if e.type == BattleEvent.Type.BATTLE_LINE:
			line_kinds.append(str(e.data.kind))
	assert_eq(line_kinds, ["turning"], "the fixed line replaces the profile's last line")
	# Happens once.
	m.rule_turned = true
	assert_false(m._turn_rules())

func _foe_gain(turned: bool, full: bool) -> int:
	var m := _model("ember_pulse", 2)
	m.rule_turned = turned
	m.rule_turn_full = full
	var foe: Spirling = m.active_spirling(BattleModel.Side.FOE)
	foe.energy = 0
	m._end_of_turn_for(BattleModel.Side.FOE, 0)
	return foe.energy

func test_ember_pulse_full_gives_two() -> void:
	assert_eq(_foe_gain(true, true), _foe_gain(false, true) + 1, "Veteran and up: +1 on top every turn")
	assert_eq(_foe_gain(true, false), _foe_gain(false, false), "Tamer: no extra per turn")

func test_tamer_turning_is_one_surge() -> void:
	var m := _model("ember_pulse", 3)
	_drop_foe(m)
	m.slots[BattleModel.Side.FOE][0] = 1
	var foe: Spirling = m.party(BattleModel.Side.FOE)[2]
	m.slots[BattleModel.Side.FOE][0] = 2
	var before: int = foe.energy
	m.party(BattleModel.Side.FOE)[1].hp = 0
	m._turn_rules()
	assert_eq(foe.energy, mini(Spirling.MAX_ENERGY, before + 1))

func test_replay_keeps_full() -> void:
	var m := _model("ember_pulse", 2)
	m.rule_turn_full = true
	assert_true(bool(BattleReplay.snapshot(m, "", "").get("rule_turn_full", false)))

func test_soft_rules_never_turn() -> void:
	for r: String in ["ember_pulse_soft", "undertow_soft", "ash_rain"]:
		var m := _model(r, 2)
		_drop_foe(m)
		assert_false(m.rule_turned, r)

func test_undertow_drags_next_player_in() -> void:
	var m := _model("undertow", 2)
	_drop_foe(m)
	assert_true(m.rule_turned)
	var nxt: Spirling = m.party(BattleModel.Side.PLAYER)[1]
	var before: int = nxt.stage("atk")
	m._swap_in(BattleModel.Side.PLAYER, 1, 0)
	assert_eq(nxt.stage("atk"), before - 1)
	# Only the next one.
	var first: Spirling = m.party(BattleModel.Side.PLAYER)[0]
	var b2: int = first.stage("atk")
	m._swap_in(BattleModel.Side.PLAYER, 0, 0)
	assert_eq(first.stage("atk"), b2)

func test_wild_never_turns() -> void:
	var m := BattleModel.new(_team(["Kindlop"], 20), _team(["Zippit", "Kindlop"], 20), true, 3, 0)
	m.foe_rule = "ember_pulse"
	m.start()
	_drop_foe(m)
	assert_false(m.rule_turned)

func test_describe() -> void:
	var e := BattleEvent.new(BattleEvent.Type.RULE, {"label": "Undertow", "text": "x", "turning": true})
	assert_eq(e.describe(), "Turning point, Undertow: x")
