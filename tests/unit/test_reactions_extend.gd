extends GutTest
## Plan area 2: field_extend (461), the new reaction rows (566, 567, 569, 570) and the
## stages_full_hp key (606).

func before_all() -> void:
	Database.load_all()

func _fight(move: String, foe_status: String) -> Dictionary:
	var me: Spirling = BattleFixtures.make("Zippit", 20, [move])
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	m.start()
	foe.status = foe_status
	foe.status_turns = 3
	me.energy = Spirling.MAX_ENERGY
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	return {"m": m, "foe": foe, "ev": ev}

func test_no_two_reaction_rows_share_a_pair() -> void:
	var seen: Dictionary = {}
	for r: Dictionary in BattleRules.REACTIONS:
		var k: String = "%s/%s" % [r.element, r.status]
		assert_false(seen.has(k), "only one row for %s" % k)
		seen[k] = true
		assert_true(Elements.E.has(str(r.element)), k)
		assert_true(StatusRules.RULES.has(str(r.status)), k)
		assert_true(r.has("mult") or r.has("cure") or r.has("stage"), "%s does something" % k)

func test_stone_grounds_jolt() -> void:
	var f: Dictionary = _fight("Pebble Toss", "jolt")
	var r: BattleEvent = BattleFixtures.first_of(f.ev, BattleEvent.Type.REACTION)
	assert_not_null(r)
	assert_eq(r.describe(), "The stone grounds the charge in %s!" % f.foe.display_name())
	assert_eq(f.foe.status, "", "Jolt ends")

func test_gale_dries_soak_and_slows() -> void:
	var f: Dictionary = _fight("Breeze Slice", "soak")
	assert_not_null(BattleFixtures.first_of(f.ev, BattleEvent.Type.REACTION))
	assert_eq(f.foe.status, "")
	assert_eq(int(f.foe.stages.get("spd", 0)), -1, "Pace drops by one")

func test_lumen_wakes_drowse_and_hits_harder() -> void:
	var mv: MoveData = Database.move("Wick Flicker")
	var foe: Spirling = BattleFixtures.make("Calderox", 40)
	foe.status = "drowse"
	assert_eq(float(BattleRules.reaction(mv, foe).get("mult", 1.0)), 1.3)
	var f: Dictionary = _fight("Wick Flicker", "drowse")
	assert_not_null(BattleFixtures.first_of(f.ev, BattleEvent.Type.REACTION))
	assert_eq(f.foe.status, "", "it wakes up")

func test_one_reaction_per_hit() -> void:
	var f: Dictionary = _fight("Breeze Slice", "soak")
	var n: int = 0
	for e: BattleEvent in f.ev:
		if e.type == BattleEvent.Type.REACTION:
			n += 1
	assert_eq(n, 1)

func _extend_model() -> BattleModel:
	var me: Spirling = BattleFixtures.make("Zippit", 20, ["Pebble Toss"])
	var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	m.start()
	me.moves[0] = Database.parse_move({"name": "Hold Test", "element": "VOLT", "kind": "STATUS", "power": 0,
		"accuracy": 1.0, "energy": 2, "effect": "field_extend", "effect_amount": 2})
	me.energy = Spirling.MAX_ENERGY
	return m

func test_field_extend_adds_two_turns() -> void:
	var m: BattleModel = _extend_model()
	m.set_field("static_veil")
	var before: int = m.field_turns
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field_turns, before + 2 - 1, "two more turns, minus this turn's tick")
	var e: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.FIELD_EXTENDED)
	assert_not_null(e)
	assert_eq(e.describe(), "The Static Veil holds on for 2 more turns!")

func test_field_extend_fails_without_a_field() -> void:
	var m: BattleModel = _extend_model()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var e: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.FIELD_EXTENDED)
	assert_not_null(e)
	assert_eq(e.describe(), "There is no Resonance field to hold.")
	assert_eq(m.field, "")

func test_full_vigor_gives_two_stages() -> void:
	for full: bool in [true, false]:
		var me: Spirling = BattleFixtures.make("Kindlop", 20, ["Kindle Up"])
		var foe: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"])
		var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
		m.start()
		if not full:
			me.hp -= 1
		me.energy = Spirling.MAX_ENERGY
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		assert_eq(int(me.stages.get("atk", 0)), 2 if full else 1, "full Vigor %s" % full)
