extends GutTest
## Battle plan, first step (docs/KAMPF_PLAN_1000.md): Resonance fields, boss phases, the Calm rule,
## Bench lessons, the Master AI (tier 3) and the damage preview.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func _one(species: String, level: int, moves: Array[String]) -> Array[Spirling]:
	var out: Array[Spirling] = [BattleFixtures.make(species, level, moves)]
	return out

# --- Resonance fields ---------------------------------------------------------------

func test_resonance_moves_carry_a_field() -> void:
	for pair: Array in [["Ash Call", "ash_storm"], ["Tide Call", "high_tide"], ["Murk Call", "deep_murk"]]:
		var mv: MoveData = Database.move(str(pair[0]))
		assert_not_null(mv, str(pair[0]))
		assert_false(mv.is_damaging())
		assert_eq(StringName(mv.effects[0].id), &"set_field")
		assert_eq(str(mv.effects[0].field), str(pair[1]))

func test_resonance_field_lasts_then_the_place_field_returns() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Smoldrake", 30, ["Ash Call"]), _one("Mossling", 30, ["Bowl Over"]))
	m.field = "deep_murk"
	m.start()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.FIELD))
	assert_eq(m.field, "ash_storm")
	assert_eq(m.field_turns, BattleRules.RESONANCE_TURNS - 1, "the first turn already counts")
	var ended: BattleEvent = null
	for i: int in BattleRules.RESONANCE_TURNS:
		ev = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
		if ended == null:
			ended = BattleFixtures.first_of(ev, BattleEvent.Type.FIELD_END)
	assert_not_null(ended, "the Resonance field fades")
	assert_eq(ended.describe(), "The Ash Storm fades away.")
	assert_eq(m.field, "deep_murk", "the place's own field comes back")
	assert_eq(m.field_turns, 0)

func test_resonance_field_powers_the_boosted_element() -> void:
	var a: Spirling = BattleFixtures.make("Smoldrake", 30, ["Cinder Nip", "Ash Call"])
	var b: Spirling = BattleFixtures.make("Mossling", 30, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	var plain: int = CommandMenu.damage_pct(m, a, b, a.moves[0])
	m.submit_turn(BattleAction.make_move(0, 1), BattleAction.make_rest(1))
	assert_gt(CommandMenu.damage_pct(m, a, b, a.moves[0]), plain)

func test_resonance_moves_are_learnable() -> void:
	var learners: Dictionary = {"Ash Call": 0, "Tide Call": 0, "Murk Call": 0}
	for sd: SpirlingData in Database.spirlings.values():
		for mv: MoveData in sd.learnset_moves:
			if learners.has(mv.move_name):
				learners[mv.move_name] += 1
	for name: String in learners:
		assert_gt(int(learners[name]), 0, name)

# --- Boss phases -----------------------------------------------------------------------

func test_boss_wakes_once_at_half_hp() -> void:
	var boss: Spirling = BattleFixtures.make("Smoldrake", 14, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model(_one("Puddlet", 14, ["Fizz Pop"]), [boss] as Array[Spirling], false)
	m.foe_boss = "ashen_heart"
	m.start()
	assert_eq(m.deal_damage(1, boss.max_hp() / 4), boss.max_hp() / 4)
	assert_false(m.boss_phase_done)
	m._events = []
	m.deal_damage(1, boss.max_hp() / 3)
	var phase: BattleEvent = BattleFixtures.first_of(m._events, BattleEvent.Type.BOSS_PHASE)
	assert_not_null(phase)
	assert_eq(phase.describe(), str(BattleRules.boss_phase("ashen_heart").text))
	assert_eq(boss.stage("atk"), 1)
	assert_eq(boss.stage("spd"), 1)
	assert_eq(m.field, "ash_storm")
	assert_eq(m.base_field, "ash_storm", "the phase field holds for the rest of the battle")
	m._events = []
	m.deal_damage(1, 1)
	assert_null(BattleFixtures.first_of(m._events, BattleEvent.Type.BOSS_PHASE), "only once")

func test_every_boss_has_a_valid_phase() -> void:
	for id: String in BattleRules.BOSSES:
		var p: Dictionary = BattleRules.boss_phase(id)
		assert_false(p.is_empty(), id)
		assert_between(float(p.at), 0.1, 0.9)
		assert_true(BattleRules.FIELDS.has(str(p.field)), id)
		for stat: String in p.stage:
			assert_true(stat in BattleRules.STAGE_STATS)

# --- Calm rule ---------------------------------------------------------------------------

func test_calm_rule_only_one_drowse_per_side_vs_tamers() -> void:
	var foes: Array[Spirling] = [BattleFixtures.make("Mossling", 15), BattleFixtures.make("Zippit", 15)]
	var m: BattleModel = BattleFixtures.model(_one("Kindlop", 15, ["Cinder Nip"]), foes, false)
	m.front_size = [1, 2]
	m.start()
	assert_true(m.apply_status(1, "drowse", 0))
	m._events = []
	assert_false(m.apply_status(1, "drowse", 1), "a second sleeper is blocked")
	var failed: BattleEvent = BattleFixtures.first_of(m._events, BattleEvent.Type.STATUS_FAILED)
	assert_true(bool(failed.data.get("clause", false)))
	assert_string_contains(failed.describe(), "Calm rule")
	assert_true(m.apply_status(1, "soak", 1), "other statuses still land")

func test_calm_rule_does_not_apply_in_the_wild() -> void:
	var foes: Array[Spirling] = [BattleFixtures.make("Mossling", 15), BattleFixtures.make("Zippit", 15)]
	var m: BattleModel = BattleFixtures.model(_one("Kindlop", 15, ["Cinder Nip"]), foes, true)
	m.front_size = [1, 2]
	m.start()
	assert_true(m.apply_status(1, "drowse", 0))
	assert_true(m.apply_status(1, "drowse", 1))

# --- Bench lessons -----------------------------------------------------------------------

func _bench_battle(share: float) -> Array[Spirling]:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 30, ["Cinder Nip"]), BattleFixtures.make("Puddlet", 5), BattleFixtures.make("Zippit", 5)]
	mine[2].hp = 0
	var foe: Spirling = BattleFixtures.make("Mossling", 2, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model(mine, [foe] as Array[Spirling], true)
	m.bench_share = share
	m.start()
	for i: int in 5:
		if not m.is_finished():
			m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.outcome, BattleModel.Outcome.WIN)
	return mine

func test_bench_lessons_share_xp_with_healthy_bench() -> void:
	var off: Array[Spirling] = _bench_battle(0.0)
	assert_eq(off[1].xp, BattleFixtures.make("Puddlet", 5).xp, "off: the bench learns nothing")
	var on: Array[Spirling] = _bench_battle(0.5)
	assert_gt(on[1].xp, off[1].xp, "on: the bench learns")
	assert_lt(on[1].xp - off[1].xp, on[0].xp - BattleFixtures.make("Kindlop", 30).xp + 1, "less than the fighter")
	assert_eq(on[2].xp, off[2].xp, "a worn-out Spirling learns nothing")

func test_bench_lessons_setting_round_trips() -> void:
	var keep_b: bool = GameState.bench_xp
	var keep_d: bool = GameState.damage_preview
	GameState.bench_xp = false
	GameState.damage_preview = false
	var d: Dictionary = GameState.settings_to_dict()
	GameState.settings_from_dict({})
	assert_true(GameState.bench_xp, "on by default")
	assert_true(GameState.damage_preview, "on by default")
	GameState.settings_from_dict(d)
	assert_false(GameState.bench_xp)
	assert_false(GameState.damage_preview)
	assert_eq(GameState.bench_share(), 0.0)
	GameState.bench_xp = keep_b
	GameState.damage_preview = keep_d

# --- Master AI ---------------------------------------------------------------------------

func test_rift_born_uses_the_master_ai() -> void:
	assert_eq(GameState.AI_LEVELS[GameState.Difficulty.RIFT_BORN], 3)
	assert_eq(GameState.AI_LEVELS[GameState.Difficulty.VETERAN], 2)

func test_master_ai_skips_status_on_immune_foes() -> void:
	# Wickit (Light Sleeper) can't be Drowsed: the master scores the status part as worthless.
	var me: Spirling = BattleFixtures.make("Mirkmole", 15, ["Hush"])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], _one("Wickit", 15, ["Wick Flicker"]), false)
	m.start()
	var greedy: float = BattleAI.new(2).score_move(m, 0, 0, 0)
	var master: float = BattleAI.new(3).score_move(m, 0, 0, 0)
	assert_gt(greedy, 0.0, "the plain greedy tier still counts the status")
	assert_eq(master, 0.0, "the master knows it can't land")

func test_field_value_favours_the_own_side() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Smoldrake", 30, ["Cinder Nip", "Ash Call"]), _one("Puddlet", 30, ["Fizz Pop"]))
	m.start()
	var ai := BattleAI.new(3)
	assert_gt(ai.field_value(m, 0, "ash_storm"), 0.0, "boosts own Ember, weakens the foe's Tide")
	assert_lt(ai.field_value(m, 0, "high_tide"), 0.0)
	m.field = "ash_storm"
	assert_eq(ai.field_value(m, 0, "ash_storm"), 0.0, "already in place")

func test_master_ai_calls_a_helpful_field() -> void:
	var me: Spirling = BattleFixtures.make("Smoldrake", 30, ["Ash Call", "Heat Haze"])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], _one("Puddlet", 30, ["Fizz Pop"]), false)
	m.start()
	var ai := BattleAI.new(3)
	assert_gt(ai.score_move(m, 0, 0, 0), 0.0, "Ash Call has value when it helps")

func test_master_ai_does_not_set_up_under_threat() -> void:
	var me: Spirling = BattleFixtures.make("Kindlop", 10, ["Kindle Up"])
	var foe: Spirling = BattleFixtures.make("Riptail", 40, ["Undertow"])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling], false)
	m.start()
	foe.energy = Spirling.MAX_ENERGY
	assert_gt(BattleAI.new(3).threat_to(m, 0, 0), BattleAI.SETUP_THREAT)
	assert_eq(BattleAI.new(3).score_move(m, 0, 0, 0), 0.0, "no setup while a big hit looms")
	assert_gt(BattleAI.new(1).score_move(m, 0, 0, 0), 0.0, "the greedy tier still likes it")

func test_master_ai_battles_finish() -> void:
	for seed_value: int in 6:
		var m: BattleModel = BattleFixtures.model(
			[BattleFixtures.make("Smoldrake", 30, ["Cinder Nip", "Ash Call", "Kindle Up"])] as Array[Spirling],
			[BattleFixtures.make("Riptail", 30, ["Fizz Pop", "Tide Call", "Undertow"])] as Array[Spirling], false, seed_value, 3)
		var player := BattleAI.new(3)
		m.start()
		var turns: int = 0
		while not m.is_finished() and turns < 200:
			m.submit_turn(player.choose(m, 0, 0))
			turns += 1
		assert_true(m.is_finished(), "seed %d" % seed_value)

# --- Damage preview ---------------------------------------------------------------------

func test_damage_preview_line() -> void:
	var mv: MoveData = Database.move("Cinder Nip")
	assert_eq(CommandMenu.move_line(mv, 9, 2.0, false, 40), "%dE ~40%%" % mv.energy_cost)
	assert_eq(CommandMenu.move_line(mv, 9, 2.0, false, -1), "%dE x2" % mv.energy_cost, "off: the matchup tag")
	assert_eq(CommandMenu.move_line(mv, 0, 2.0, false, 40), "need %dE" % mv.energy_cost)
	var status: MoveData = Database.move("Ash Call")
	assert_eq(CommandMenu.move_line(status, 9, 1.0, false, 40), "%dE" % status.energy_cost, "no preview for status moves")

func test_damage_preview_matches_the_estimate() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	m.start()
	var pct: int = CommandMenu.damage_pct(m, a, b, a.moves[0])
	var want: int = roundi(DamageCalc.estimate(a, b, a.moves[0]) * 100.0 / b.max_hp())
	assert_eq(pct, clampi(want, 1, 100))
	assert_eq(CommandMenu.damage_pct(m, a, b, Database.move("Ash Call")), -1)
