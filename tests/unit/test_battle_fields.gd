extends GutTest
## Battle plan, step 2 (docs/KAMPF_PLAN_1000.md): more Rift fields, field effects on status and
## healing, element reactions, and a fuzz run over many random battles.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func _one(species: String, level: int, moves: Array[String] = []) -> Array[Spirling]:
	var out: Array[Spirling] = [BattleFixtures.make(species, level, moves)]
	return out

func test_every_field_has_a_resonance_move() -> void:
	var called: Dictionary = {}
	for mv: MoveData in Database.moves.values():
		for fx: Dictionary in mv.effects:
			if StringName(fx.get("id", "")) == &"set_field":
				called[str(fx.field)] = true
	for id: String in BattleRules.FIELDS:
		assert_true(called.has(id), "a move calls %s" % id)
		var f: Dictionary = BattleRules.FIELDS[id]
		assert_true(Elements.E.has(str(f.boost)), id)
		assert_true(Elements.E.has(str(f.weaken)), id)
		assert_ne(str(f.boost), str(f.weaken), id)

func test_new_fields_boost_their_element() -> void:
	assert_eq(BattleRules.field_mult("static_veil", E.VOLT), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("pollen_drift", E.BLOOM), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("dawn_glow", E.LUMEN), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("dawn_glow", E.UMBRA), BattleRules.FIELD_WEAKEN)

func test_high_tide_keeps_scorch_off() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop", 15, ["Cinder Nip"]), _one("Mossling", 15))
	m.field = "high_tide"
	m.start()
	m._events = []
	assert_false(m.apply_status(1, "scorch"))
	var failed: BattleEvent = BattleFixtures.first_of(m._events, BattleEvent.Type.STATUS_FAILED)
	assert_eq(failed.describe(), "The High Tide keeps %s safe." % m.active_spirling(1).display_name())
	assert_true(m.apply_status(1, "soak"), "only Scorch is kept off")

func test_pollen_drift_mends_bloom_spirlings_only() -> void:
	var mo: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var ki: Spirling = BattleFixtures.make("Kindlop", 20, ["Bowl Over"])
	# Mossling's own trait also heals, so compare against a battle without the field.
	var gains: Array[int] = []
	for f: String in ["", "pollen_drift"]:
		mo.hp = mo.max_hp() / 2
		ki.hp = ki.max_hp() / 2
		var m: BattleModel = BattleFixtures.model([mo] as Array[Spirling], [ki] as Array[Spirling])
		m.field = f
		m.start()
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
		gains.append(mo.hp - mo.max_hp() / 2)
		if f == "pollen_drift":
			assert_eq(ki.hp, ki.max_hp() / 2, "an Ember Spirling does not mend")
	assert_gt(gains[1], gains[0])

func test_volt_hits_soaked_foes_harder() -> void:
	var z: Spirling = BattleFixtures.make("Zippit", 20, ["Arc Bolt"])
	var p: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([z] as Array[Spirling], [p] as Array[Spirling])
	m.start()
	var dry: int = CommandMenu.damage_pct(m, z, p, z.moves[0])
	p.status = "soak"
	assert_gt(CommandMenu.damage_pct(m, z, p, z.moves[0]), dry, "the preview shows the reaction")
	z.energy = Spirling.MAX_ENERGY
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var r: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.REACTION)
	assert_not_null(r)
	assert_eq(r.describe(), "The charge races through the soaked %s!" % p.display_name())

func test_tide_douses_scorch() -> void:
	var t: Spirling = BattleFixtures.make("Puddlet", 30, ["Fizz Pop"])
	var k: Spirling = BattleFixtures.make("Calderox", 40, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model([t] as Array[Spirling], [k] as Array[Spirling])
	m.start()
	k.status = "scorch"
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.REACTION))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.STATUS_CURED))
	assert_eq(k.status, "")

func test_no_reaction_without_the_status() -> void:
	var mv: MoveData = Database.move("Arc Bolt")
	var p: Spirling = BattleFixtures.make("Mossling", 20)
	assert_true(BattleRules.reaction(mv, p).is_empty())
	p.status = "jolt"
	assert_true(BattleRules.reaction(mv, p).is_empty())

# --- Fuzz ---------------------------------------------------------------------------------

const POOL: Array[String] = ["Kindlop", "Smoldrake", "Puddlet", "Riptail", "Mossling", "Thornback", "Zippit",
	"Glimmerax", "Shalebat", "Zephlet", "Wickit", "Lumenewt", "Mirkmole", "Kelpup"]

func _team(rng: RandomNumberGenerator, n: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for i: int in n:
		out.append(BattleFixtures.make(POOL[rng.randi_range(0, POOL.size() - 1)], rng.randi_range(10, 45)))
	return out

func test_fuzz_random_battles_stay_sound() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var fields: Array = [""] + BattleRules.FIELDS.keys()
	for b: int in 60:
		var mine: Array[Spirling] = _team(rng, rng.randi_range(1, 5))
		var theirs: Array[Spirling] = _team(rng, rng.randi_range(1, 5))
		var wild: bool = rng.randf() < 0.4
		var m: BattleModel = BattleFixtures.model(mine, theirs, wild, b, rng.randi_range(0, 3))
		m.front_size = [rng.randi_range(1, mini(2, mine.size())), rng.randi_range(1, mini(2, theirs.size()))]
		m.field = str(fields[rng.randi_range(0, fields.size() - 1)])
		m.bench_share = 0.5
		if not wild and rng.randf() < 0.25:
			m.foe_boss = "ashen_heart"
			m.front_size[1] = 1
		var me := BattleAI.new(3)
		m.start()
		var turns: int = 0
		while not m.is_finished() and turns < 300:
			if m.needs_player_switch():
				var c: Array[int] = m.swap_candidates(0, m.switch_slot())
				m.submit_switch(c[rng.randi_range(0, c.size() - 1)])
				continue
			var acts: Array[BattleAction] = []
			for slot: int in m.player_slots():
				var legal: Array[BattleAction] = m.legal_actions(0, slot)
				var a: BattleAction = me.choose(m, 0, slot) if rng.randf() < 0.6 else legal[rng.randi_range(0, legal.size() - 1)]
				if a.kind == BattleAction.Kind.RUN:
					a = BattleAction.make_rest(0, slot)
				acts.append(a)
			m.submit_actions(acts)
			turns += 1
			for side: int in 2:
				for s: Spirling in m.party(side):
					assert_between(s.hp, 0, s.max_hp(), "battle %d: HP in range" % b)
					assert_between(s.energy, 0, m.energy_cap_of(side, s), "battle %d: Energy in range" % b)
			assert_true(m.field.is_empty() or BattleRules.FIELDS.has(m.field), "battle %d: known field" % b)
		assert_true(m.is_finished(), "battle %d ends" % b)
