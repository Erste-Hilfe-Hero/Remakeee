extends GutTest
## Pins the damage curve, effectiveness, STAB and crit.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func test_neutral_40_power_takes_15_to_25_percent_at_same_level() -> void:
	# Stone attacker into Ember-free, Stone-neutral defender: Gale vs Gale with a Stone move is neutral, no STAB.
	var sd: SpirlingData = BattleFixtures.balanced_species(60, [E.GALE])
	var mv: MoveData = BattleFixtures.move(E.STONE, 40)
	for level: int in [3, 5, 10, 20, 35, 50, 75, 100]:
		var a: Spirling = BattleFixtures.from_species(sd, level)
		var d: Spirling = BattleFixtures.from_species(sd, level)
		var low: float = DamageCalc.raw(a, d, mv, DamageCalc.ROLL_MIN, false) / d.max_hp()
		var high: float = DamageCalc.raw(a, d, mv, DamageCalc.ROLL_MAX, false) / d.max_hp()
		assert_between(low, 0.15, 0.25, "L%d min roll = %.3f" % [level, low])
		assert_between(high, 0.15, 0.25, "L%d max roll = %.3f" % [level, high])

func test_effectiveness_multiplies_damage() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20)
	var bloom: Spirling = BattleFixtures.make("Mossling", 20)
	var tide: Spirling = BattleFixtures.make("Puddlet", 20)
	var mv: MoveData = BattleFixtures.move(E.EMBER, 50)
	var vs_bloom: float = DamageCalc.raw(a, bloom, mv, 1.0, false)
	var neutral_target: Spirling = BattleFixtures.make("Zippit", 20)
	assert_eq(DamageCalc.effectiveness(bloom, mv), 2.0)
	assert_eq(DamageCalc.effectiveness(tide, mv), 0.5)
	assert_eq(DamageCalc.effectiveness(neutral_target, mv), 1.0)
	# Same defender stats: only effectiveness differs.
	var unboosted: float = vs_bloom / 2.0
	assert_almost_eq(unboosted * 0.5 / 0.5, vs_bloom / 2.0, 0.001)

func test_effectiveness_table_all_pairs() -> void:
	for atk: int in E.values():
		for def: int in E.values():
			var m: float = Elements.single(atk, def)
			var strong: bool = def in Elements.STRONG[atk]
			var weak: bool = atk in Elements.STRONG[def]
			var expected: float = 1.0
			if strong and not weak:
				expected = 2.0
			elif weak and not strong:
				expected = 0.5
			assert_eq(m, expected, "%s -> %s" % [E.keys()[atk], E.keys()[def]])

func test_stab_is_1_25() -> void:
	var sd: SpirlingData = BattleFixtures.balanced_species(60, [E.EMBER])
	var a: Spirling = BattleFixtures.from_species(sd, 20)
	var d: Spirling = BattleFixtures.from_species(BattleFixtures.balanced_species(60, [E.GALE]), 20)
	var with_stab: float = DamageCalc.raw(a, d, BattleFixtures.move(E.EMBER, 40), 1.0, false)
	var without: float = DamageCalc.raw(a, d, BattleFixtures.move(E.STONE, 40), 1.0, false)
	assert_almost_eq(with_stab / without, 1.25, 0.0001)

func test_crit_is_1_4() -> void:
	var a: Spirling = BattleFixtures.make("Zippit", 20)
	var d: Spirling = BattleFixtures.make("Zephlet", 20)
	var mv: MoveData = BattleFixtures.move(E.STONE, 40)
	var normal: float = DamageCalc.raw(a, d, mv, 1.0, false)
	var crit: float = DamageCalc.raw(a, d, mv, 1.0, true)
	assert_almost_eq(crit / normal, 1.4, 0.0001)

func test_crit_rate_is_about_one_in_twelve() -> void:
	var a: Spirling = BattleFixtures.make("Zippit", 20)
	var d: Spirling = BattleFixtures.make("Zephlet", 20)
	var mv: MoveData = BattleFixtures.move(E.STONE, 40)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var crits: int = 0
	var n: int = 8000
	for i: int in n:
		if DamageCalc.compute(a, d, mv, rng).crit:
			crits += 1
	assert_between(float(crits) / n, 0.07, 0.097)

func test_scorch_cuts_physical_attack() -> void:
	var a: Spirling = BattleFixtures.make("Mossling", 20)
	var d: Spirling = BattleFixtures.make("Zippit", 20)
	var mv: MoveData = BattleFixtures.move(E.STONE, 40)
	var before: float = DamageCalc.raw(a, d, mv, 1.0, false)
	a.status = "scorch"
	var after: float = DamageCalc.raw(a, d, mv, 1.0, false)
	assert_lt(after, before)
	var focus_mv: MoveData = BattleFixtures.move(E.STONE, 40, MoveData.Kind.FOCUS)
	a.status = ""
	var f_before: float = DamageCalc.raw(a, d, focus_mv, 1.0, false)
	a.status = "scorch"
	assert_eq(DamageCalc.raw(a, d, focus_mv, 1.0, false), f_before, "Scorch does not touch FOC")

func test_status_moves_deal_no_damage() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20)
	var d: Spirling = BattleFixtures.make("Zippit", 20)
	var rng := RandomNumberGenerator.new()
	assert_eq(int(DamageCalc.compute(a, d, Database.move("Hush"), rng).damage), 0)
