extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, item 451): the delayed_hit effect.

func before_all() -> void:
	Database.load_all()

func _model(foes: Array[Spirling]) -> BattleModel:
	var me: Spirling = BattleFixtures.make("Lumenewt", 40, ["Omen Bell", "Prism Ray"] as Array[String])
	me.energy = Spirling.MAX_ENERGY
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], foes, false, 451, 0)
	m.items_allowed = false
	return m

func _rest_both(m: BattleModel) -> Array[BattleEvent]:
	return m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))

func test_parse_makes_a_delayed_effect_and_the_art_sits_on_the_curve() -> void:
	var mv: MoveData = Database.move("Omen Bell")
	assert_true(mv.has_effect(&"delayed_hit"))
	assert_true(EffectRegistry.has_effect(&"delayed_hit"))
	assert_true(Database.species("Lumenewt").learnset_moves.has(mv))

func test_lands_two_turns_later_with_the_numbers_of_the_use_turn() -> void:
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Bowl Over"] as Array[String])
	var m: BattleModel = _model([foe] as Array[Spirling])
	m.start()
	m.active_spirling(0).energy = Spirling.MAX_ENERGY
	var full: int = foe.hp
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.DELAYED_SET))
	assert_eq(BattleFixtures.first_of(ev, BattleEvent.Type.DELAYED_SET).describe(), "Omen Bell will land in 2 turns!")
	assert_eq(foe.hp, full, "nothing lands on the use turn")
	assert_eq(m.delayed_hits.size(), 1)
	var held: int = int(m.delayed_hits[0].amount)
	assert_gt(held, 0)
	# Stats raised after the use don't change the hit on its way.
	m.change_stage(0, "foc", 2)
	_rest_both(m)
	assert_eq(foe.hp, full, "still on its way one turn later")
	ev = _rest_both(m)
	var hit: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.DELAYED_HIT)
	assert_not_null(hit)
	assert_eq(hit.describe(), "Omen Bell lands on %s!" % foe.display_name())
	assert_eq(full - foe.hp, mini(held, full))
	assert_eq(m.delayed_hits.size(), 0)

func test_hits_whoever_stands_in_the_slot_then() -> void:
	var a: Spirling = BattleFixtures.make("Calderox", 40, ["Bowl Over"] as Array[String])
	var b: Spirling = BattleFixtures.make("Riptail", 40, ["Bowl Over"] as Array[String])
	var m: BattleModel = _model([a, b] as Array[Spirling])
	m.start()
	m.active_spirling(0).energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_swap(1, 1))
	assert_eq(m.active_spirling(1), b)
	var a_hp: int = a.hp
	_rest_both(m)
	assert_lt(b.hp, b.max_hp(), "the newcomer takes it")
	assert_eq(a.hp, a_hp, "the one that left is safe")

func test_a_plain_art_queues_nothing() -> void:
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Bowl Over"] as Array[String])
	var m: BattleModel = _model([foe] as Array[Spirling])
	m.start()
	m.submit_turn(BattleAction.make_move(0, 1), BattleAction.make_rest(1))
	assert_eq(m.delayed_hits.size(), 0, "a plain art does not queue")

func test_ai_scores_it_below_an_instant_hit_of_the_same_size() -> void:
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Bowl Over"] as Array[String])
	var m: BattleModel = _model([foe] as Array[Spirling])
	m.start()
	var ai := BattleAI.new(1)
	assert_lt(ai.score_move(m, 0, 0), ai.score_move(m, 0, 1) * 1.5)
