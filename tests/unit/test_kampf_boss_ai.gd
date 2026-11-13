extends GutTest
## docs/KAMPF_PLAN_1000.md areas "Bosse und Wardens" (402-440) and "Gegner-KI" (441-480).

const Side := BattleModel.Side

func before_all() -> void:
	Database.load_all()

func _boss_model(boss_id: String = "ashen_heart", difficulty: int = GameState.Difficulty.TAMER) -> BattleModel:
	var mine: Array[Spirling] = [BattleFixtures.make("Puddlet", 14, ["Fizz Pop"])]
	var boss: Spirling = BattleFixtures.make("Smoldrake", 14, ["Cinder Nip"])
	var m: BattleModel = BattleFixtures.model(mine, [boss] as Array[Spirling], false)
	m.front_size = [1, 1]
	m.foe_boss = boss_id
	m.boss_difficulty = difficulty
	m.start()
	return m

func _phase_texts(events: Array[BattleEvent]) -> Array[String]:
	var out: Array[String] = []
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.BOSS_PHASE:
			out.append(e.describe())
	return out

# --- Bosse und Wardens ----------------------------------------------------------

func test_every_boss_has_a_late_phase_and_a_hold_field() -> void:
	for id: String in BattleRules.BOSSES:
		assert_false(BossRules.late_phases(id).is_empty(), id)
		var late: Dictionary = BossRules.late_phases(id)[0]
		assert_lt(float(late.at), BattleRules.boss_phase_at(id, GameState.Difficulty.RIFT_BORN), id)
		assert_true(BattleRules.FIELDS.has(BossRules.HOLD_FIELD[id]), id)
		assert_ne(BossRules.HOLD_FIELD[id], str(BattleRules.boss_phase(id).get("field", "")), "%s: its own phase field can't hold it" % id)
		assert_true(Lexicon.has_entry(BossRules.LEXICON[id]), id)

func test_third_phase_starts_at_a_quarter() -> void:
	var m: BattleModel = _boss_model()
	var boss: Spirling = m.active_spirling(Side.FOE)
	m._events = []
	m.deal_damage(Side.FOE, int(boss.max_hp() * 0.55))
	assert_true(m.boss_phase_done)
	assert_eq(m.boss_late_done, 0)
	m.deal_damage(Side.FOE, boss.hp - int(boss.max_hp() * 0.2))
	assert_eq(m.boss_late_done, 1)
	assert_has(_phase_texts(m._events), str(BossRules.late_phases("ashen_heart")[0].text))
	m.deal_damage(Side.FOE, 1)
	assert_eq(m.boss_late_done, 1, "each phase comes once")

func test_hold_field_delays_the_phase() -> void:
	var m: BattleModel = _boss_model()
	var boss: Spirling = m.active_spirling(Side.FOE)
	m.set_field("high_tide", 5)
	m.deal_damage(Side.FOE, int(boss.max_hp() * 0.6))
	assert_false(m.boss_phase_done, "High Tide holds the Ashen Heart")
	m.field = ""
	m.deal_damage(Side.FOE, 1)
	assert_true(m.boss_phase_done, "the next hit after the field wakes it")

func test_weak_point_lasts_one_turn() -> void:
	var m: BattleModel = _boss_model()
	var boss: Spirling = m.active_spirling(Side.FOE)
	m.deal_damage(Side.FOE, int(boss.max_hp() * 0.55))
	assert_eq(boss.stage("def"), -1)
	assert_true(_phase_texts(m._events).has("%s lies open: its Guard is down for a turn!" % boss.display_name()))
	m._boss_end_of_turn()
	assert_eq(boss.stage("def"), -1, "still open for the next turn")
	m.turn += 1
	m._boss_end_of_turn()
	assert_eq(boss.stage("def"), 0)

func test_rage_after_long_fight() -> void:
	var m: BattleModel = _boss_model()
	var boss: Spirling = m.active_spirling(Side.FOE)
	m.turn = BossRules.RAGE_TURN - 1
	m._boss_end_of_turn()
	assert_eq(boss.stage("atk"), 0)
	m.turn = BossRules.RAGE_TURN
	m._boss_end_of_turn()
	assert_eq(boss.stage("atk"), 1)
	assert_eq(boss.stage("foc"), 1)
	m.turn = BossRules.RAGE_TURN + 1
	m._boss_end_of_turn()
	assert_eq(boss.stage("atk"), 1, "only every RAGE_EVERY turns")
	assert_true(BossRules.rage_due(BossRules.RAGE_TURN + BossRules.RAGE_EVERY))

func test_boss_status_and_stage_drops_halved() -> void:
	assert_eq(BossRules.status_turns(3), 2)
	assert_eq(BossRules.status_turns(2), 1)
	assert_eq(BossRules.status_turns(0), 0, "a lasting status stays")
	assert_eq(BossRules.stage_delta(-1), -1)
	assert_eq(BossRules.stage_delta(-2), -1)
	assert_eq(BossRules.stage_delta(-3), -2)
	assert_eq(BossRules.stage_delta(2), 2)
	var m: BattleModel = _boss_model()
	assert_true(m.apply_status(Side.FOE, "soak"))
	assert_eq(m.active_spirling(Side.FOE).status_turns, 2)
	assert_true(m.apply_status(Side.PLAYER, "soak"))
	assert_eq(m.active_spirling(Side.PLAYER).status_turns, 3, "the player's side keeps the full time")
	m.change_stage(Side.FOE, "spd", -2)
	m.change_stage(Side.PLAYER, "spd", -2)
	assert_eq(m.active_spirling(Side.FOE).stage("spd"), -1)
	assert_eq(m.active_spirling(Side.PLAYER).stage("spd"), -2)

func test_boss_intro_names_its_actions() -> void:
	var e := BattleEvent.new(BattleEvent.Type.BOSS, {"label": "Ashen Heart", "text": "x", "actions": 2})
	assert_string_contains(e.describe(), "It acts 2 times each turn.")
	e.data["actions"] = 1
	assert_false(e.describe().contains("acts"))

func test_boss_ai_never_below_tier_two() -> void:
	for d: int in 4:
		assert_gte(TrainerData.ai_tier({"boss": "ashen_heart", "team": []}, 0, d), TrainerData.BOSS_MIN_AI)
	assert_eq(TrainerData.ai_tier({"team": []}, 0, GameState.Difficulty.STORY), 0, "plain Wayfarers keep theirs")

func test_boss_stats_note_wins_and_best_turns() -> void:
	var rec: Dictionary = {}
	BossRules.note_win(rec, "mist_heart", 9)
	BossRules.note_win(rec, "mist_heart", 6)
	BossRules.note_win(rec, "mist_heart", 8)
	var s: Dictionary = BossRules.stats(rec, "mist_heart")
	assert_eq(int(s.wins), 3)
	assert_eq(int(s.best_turns), 6)
	assert_eq(int(s.last_turns), 8)
	assert_true(BossRules.stats(rec, "ashen_heart").is_empty())

func test_still_air_and_ebb() -> void:
	for id: String in ["still_air", "ebb"]:
		assert_true(BattleRules.RULES.has(id))
		assert_true(bool(BattleRules.RULES[id].warden_only), id)
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Puddlet", 14)] as Array[Spirling], [BattleFixtures.make("Kindlop", 14)] as Array[Spirling], false)
	m.foe_rule = "still_air"
	m.change_stage(Side.PLAYER, "atk", 1)
	m.change_stage(Side.FOE, "def", -1)
	assert_eq(m.active_spirling(Side.PLAYER).stage("atk"), 0)
	assert_eq(m.active_spirling(Side.FOE).stage("def"), 0)
	assert_true(BattleAI.stages_locked(m))
	assert_eq(m.rest_gain(), BattleModel.REST_ENERGY)
	m.foe_rule = "ebb"
	assert_eq(m.rest_gain(), BattleModel.REST_ENERGY - 1)

# --- Gegner-KI -------------------------------------------------------------------

func test_partner_plays_tier_two_from_veteran() -> void:
	assert_eq(TrainerData.partner_ai(GameState.Difficulty.TAMER), TrainerData.PARTNER_AI)
	assert_eq(TrainerData.partner_ai(GameState.Difficulty.VETERAN), 2)
	assert_eq(TrainerData.partner_ai(GameState.Difficulty.RIFT_BORN), 2)

func test_swaps_out_after_a_heavy_stage_drop() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Mossling", 20, ["Lichen Lash"])]
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"]), BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	assert_ne(BattleAI.new(2).choose(m, Side.FOE).kind, BattleAction.Kind.SWAP, "no reason to swap yet")
	foe[0].stages["atk"] = -2
	var a: BattleAction = BattleAI.new(2).choose(m, Side.FOE)
	assert_eq(a.kind, BattleAction.Kind.SWAP)
	assert_eq(a.swap_index, 1)
	assert_ne(BattleAI.new(2, "hothead").choose(m, Side.FOE).kind, BattleAction.Kind.SWAP, "a Hothead never swaps")

func test_rooted_ai_never_tries_to_swap() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])]
	var foe: Array[Spirling] = [BattleFixtures.make("Mossling", 20), BattleFixtures.make("Puddlet", 20)]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	foe[0].status = "root"
	var a: BattleAction = BattleAI.new(2).choose(m, Side.FOE)
	assert_ne(a.kind, BattleAction.Kind.SWAP)
	assert_true(m.is_legal(a))

func test_ai_uses_at_most_two_items() -> void:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Mossling", 20)] as Array[Spirling], [BattleFixtures.make("Kindlop", 20)] as Array[Spirling], false)
	m.foe_items = {"tonic": 5}
	m.party(Side.FOE)[0].hp = 3
	assert_eq(BattleAI.new(2).choose(m, Side.FOE).kind, BattleAction.Kind.ITEM)
	m.items_used[Side.FOE] = {"tonic": BattleAI.ITEM_LIMIT}
	assert_ne(BattleAI.new(2).choose(m, Side.FOE).kind, BattleAction.Kind.ITEM)

func test_replacement_spares_a_badly_hurt_spirling() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])]
	var foe: Array[Spirling] = [BattleFixtures.make("Zippit", 20), BattleFixtures.make("Puddlet", 20), BattleFixtures.make("Kindlop", 20)]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	foe[0].hp = 0
	foe[1].hp = maxi(1, int(foe[1].max_hp() * 0.1))
	assert_eq(BattleAI.new(1).choose_replacement(m, Side.FOE), 1, "tier 1 only reads the matchup")
	assert_eq(BattleAI.new(2).choose_replacement(m, Side.FOE), 2, "tier 2 keeps the hurt Puddlet back")

func test_overcharge_counts_when_it_knocks_out() -> void:
	var me: Spirling = BattleFixtures.make("Zippit", 20, ["Overcharge"])
	var target: Spirling = BattleFixtures.make("Puddlet", 20)
	var m: BattleModel = BattleFixtures.model([target] as Array[Spirling], [me] as Array[Spirling], false)
	var mv: MoveData = me.moves[0]
	target.hp = int(DamageCalc.estimate(me, target, mv)) + 1
	var ai := BattleAI.new(1)
	me.energy = me.move_cost(mv)
	var flat: float = ai.score_move(m, Side.FOE, 0)
	me.energy = 10
	assert_gt(ai.score_move(m, Side.FOE, 0), flat + BattleAI.KO_BONUS * 0.5)

func test_recoil_shunned_when_low() -> void:
	var me: Spirling = BattleFixtures.make("Riptail", 30, ["Breaker Plunge"])
	var target: Spirling = BattleFixtures.make("Kindlop", 30)
	var m: BattleModel = BattleFixtures.model([target] as Array[Spirling], [me] as Array[Spirling], false)
	var ai := BattleAI.new(1)
	var full: float = ai.score_move(m, Side.FOE, 0)
	me.hp = 1
	assert_lt(ai.score_move(m, Side.FOE, 0), full - BattleAI.KO_BONUS * 0.5, "a fatal recoil is worth avoiding")

func test_no_two_attackers_on_one_sure_knockout() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Mossling", 20), BattleFixtures.make("Mossling", 20)]
	var foe: Array[Spirling] = [BattleFixtures.make("Kindlop", 20, ["Cinder Nip"]), BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	m.front_size = [2, 2]
	m.start()
	m.active_spirling(Side.PLAYER, 0).hp = 1
	var ai := BattleAI.new(1)
	var first: BattleAction = ai.choose(m, Side.FOE, 0)
	var second: BattleAction = ai.choose(m, Side.FOE, 1)
	assert_eq(first.target_slot, 0, "the sure knock-out first")
	assert_eq(second.target_slot, 1, "the teammate takes the other foe")

func test_equal_scores_go_to_the_weakest_target() -> void:
	var player: Array[Spirling] = [BattleFixtures.make("Mossling", 20), BattleFixtures.make("Mossling", 20)]
	var foe: Array[Spirling] = [BattleFixtures.make("Shalebat", 20, ["Hush"])]
	var m: BattleModel = BattleFixtures.model(player, foe, false)
	m.front_size = [2, 1]
	m.start()
	m.active_spirling(Side.PLAYER, 1).hp = m.active_spirling(Side.PLAYER, 1).max_hp() / 2
	var a: BattleAction = BattleAI.new(1).choose(m, Side.FOE, 0)
	assert_eq(a.kind, BattleAction.Kind.MOVE)
	assert_eq(a.target_slot, 1)

## Items 458, 471, 475: every tier picks only legal actions under the player's own rules, and the
## same seed gives the same choices.
func _fuzz_log(seed_value: int, tier: int) -> Array[String]:
	var names: Array[String] = ["Kindlop", "Puddlet", "Mossling", "Zippit", "Shalebat"]
	var mine: Array[Spirling] = []
	var theirs: Array[Spirling] = []
	for i: int in 3:
		mine.append(BattleFixtures.make(names[(seed_value + i) % names.size()], 18))
		theirs.append(BattleFixtures.make(names[(seed_value + i + 2) % names.size()], 18))
	var m: BattleModel = BattleFixtures.model(mine, theirs, false, seed_value, tier)
	m.front_size = [2, 2]
	m.start()
	var brains: Array[BattleAI] = [BattleAI.new(tier), m.ai]
	var log: Array[String] = []
	for t: int in 40:
		if m.is_finished():
			break
		if m.needs_player_switch():
			m.submit_switch(brains[0].choose_replacement(m, Side.PLAYER, m.switch_slot()))
			continue
		var acts: Array[BattleAction] = []
		for side: int in [Side.PLAYER, Side.FOE]:
			for slot: int in m.slot_count(side):
				if not m.is_standing(m.active_spirling(side, slot)):
					continue
				var a: BattleAction = brains[side].choose(m, side, slot)
				assert_true(m.is_legal(a), "tier %d seed %d turn %d" % [tier, seed_value, t])
				acts.append(a)
				log.append("%d%d:%d/%d/%d/%d" % [side, slot, a.kind, a.move_index, a.target_slot, a.swap_index])
		m.submit_actions(acts)
	return log

func test_ai_only_legal_and_deterministic() -> void:
	for tier: int in 4:
		for s: int in [3, 11]:
			assert_eq(_fuzz_log(s, tier), _fuzz_log(s, tier), "tier %d seed %d" % [tier, s])
