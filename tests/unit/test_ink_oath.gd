extends GutTest
## The Ink Oath: once per battle against another Wayfarer, stages and Energy at once, a debt
## collected when it comes due, and nothing outlasts the battle.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _p(names: Array[String], level: int = 30) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(BattleFixtures.make(n, level))
	return out

func _model(wild: bool) -> BattleModel:
	var m := BattleModel.new(_p(["Talusk", "Kindlop"]), _p(["Talusk"]), wild, 7, 1)
	m.start()
	return m

func _count(events: Array[BattleEvent], t: BattleEvent.Type) -> int:
	var n: int = 0
	for e: BattleEvent in events:
		n += 1 if e.type == t else 0
	return n

func test_data_is_sane() -> void:
	var o: Dictionary = BattleRules.oath()
	assert_gt(int(o.turns), 0)
	for stat: String in (o.stages as Dictionary).keys() + (o.debt as Dictionary).keys():
		assert_true(stat in BattleRules.STAGE_STATS, stat)

func test_only_against_wayfarers_and_never_offered_to_the_ai() -> void:
	var wild: BattleModel = _model(true)
	assert_false(wild.can_oath(Side.PLAYER))
	assert_false(wild.is_legal(BattleAction.make_oath(Side.PLAYER)))
	var m: BattleModel = _model(false)
	assert_true(m.can_oath(Side.PLAYER))
	for a: BattleAction in m.legal_actions(Side.PLAYER):
		assert_ne(a.kind, BattleAction.Kind.OATH, "kept out of legal_actions for the AI")

func test_oath_gives_stages_and_energy_once() -> void:
	var m: BattleModel = _model(false)
	var me: Spirling = m.active_spirling(Side.PLAYER)
	me.energy = 0
	var events: Array[BattleEvent] = m.submit_turn(BattleAction.make_oath(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	assert_eq(_count(events, T.OATH), 1)
	var o: Dictionary = BattleRules.oath()
	for stat: String in o.stages:
		assert_eq(me.stage(stat), int(o.stages[stat]), stat)
	assert_true(me.energy >= int(o.energy), "the oath pays its Energy at once")
	assert_false(m.can_oath(Side.PLAYER), "once per battle")

func test_debt_comes_due_after_the_turns() -> void:
	var m: BattleModel = _model(false)
	var me: Spirling = m.active_spirling(Side.PLAYER)
	m.submit_turn(BattleAction.make_oath(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	var due: int = 0
	var o: Dictionary = BattleRules.oath()
	for i: int in int(o.turns):
		for e: BattleEvent in m.submit_turn(BattleAction.make_rest(Side.PLAYER), BattleAction.make_rest(Side.FOE)):
			if e.type == T.OATH and bool(e.data.get("due", false)):
				due += 1
	assert_eq(due, 1)
	for stat: String in o.debt:
		assert_eq(me.stage(stat), int(o.debt[stat]) + int(o.stages.get(stat, 0)), stat)

func test_nothing_outlasts_the_battle() -> void:
	var m: BattleModel = _model(false)
	var me: Spirling = m.active_spirling(Side.PLAYER)
	m.submit_turn(BattleAction.make_oath(Side.PLAYER), BattleAction.make_rest(Side.FOE))
	me.end_battle()
	assert_eq(me.oath_turns, 0)
	assert_eq(me.stage("atk"), 0)

func test_oath_text_in_english_and_german() -> void:
	var e := BattleEvent.new(T.OATH, {"name": "Talusk"})
	assert_string_contains(e.describe(), "Talusk")
	var de: Dictionary = Loc.load_table("de").strings
	for k: String in ["sworn_text", "due_text"]:
		assert_true(de.has(str(BattleRules.oath()[k])), k)
	assert_true(de.has("Oath"))
