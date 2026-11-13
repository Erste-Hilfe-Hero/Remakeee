extends GutTest
## KAMPF_PLAN_1000 area "Status-Zustände": the fixed status numbers, the three new statuses
## (Spent, Marked, Muddle), bosses, Hushed Air, the Calm Veil, Glimmer Skin, Unruffled, the
## Mirror Scale and why a status fails.

const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _one(species: String, level: int = 20, moves: Array[String] = []) -> Array[Spirling]:
	var out: Array[Spirling] = [BattleFixtures.make(species, level, moves)]
	return out

func _texts(events: Array[BattleEvent], t: BattleEvent.Type) -> Array[String]:
	var out: Array[String] = []
	for e: BattleEvent in events:
		if e.type == t:
			out.append(e.describe())
	return out

func test_original_status_numbers_stay_fixed() -> void:
	assert_eq(StatusRules.tick_div("scorch"), 12, "ticks stay at 1/12")
	assert_eq(StatusRules.tick_div("root"), 12)
	assert_almost_eq(StatusRules.skip_chance("jolt"), 0.2, 0.0001, "Jolt 20 %")
	assert_eq(StatusRules.RULES.drowse.turns, [2, 2], "Drowse 2 turns")
	assert_almost_eq(StatusRules.acc_mult("daze"), 0.7, 0.0001, "Daze: 3 in 10 arts miss")
	assert_almost_eq(StatusRules.atk_mult("scorch"), 0.75, 0.0001)

func test_every_status_has_a_guide_text_a_cure_and_an_art() -> void:
	var cures: Dictionary = {}
	for it: Dictionary in Database.items.values():
		if it.get("cure") is String:
			cures[str(it.cure)] = true
	var arts: Dictionary = {}
	for mv: MoveData in Database.moves.values():
		for fx: Dictionary in mv.effects:
			if StringName(fx.get("id", "")) == &"inflict_status":
				arts[str(fx.status)] = true
	var guide: String = BattleGuide.page(0)
	for st: String in StatusRules.RULES:
		assert_false(StatusRules.text(st).is_empty(), "%s has a guide text" % st)
		assert_string_contains(guide, StatusRules.label(st))
		assert_true(cures.has(st), "%s has a cure" % st)
		assert_true(arts.has(st), "an art inflicts %s" % st)

func test_spent_halves_the_energy_gain() -> void:
	assert_eq(StatusRules.energy_gain("spent", 1, 0) + StatusRules.energy_gain("spent", 1, 1), 1)
	assert_eq(StatusRules.energy_gain("spent", 3, 0) + StatusRules.energy_gain("spent", 3, 1), 3)
	assert_eq(StatusRules.energy_gain("", 1, 1), 1)
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	var me: Spirling = m.active_spirling(0)
	var foe: Spirling = m.active_spirling(1)
	assert_true(m.apply_status(1, "spent"))
	me.energy = 0
	foe.energy = 0
	for i: int in 2:
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(me.energy - foe.energy, 1, "two turns: the Spent foe gains one Energy less")

func test_marked_target_is_hit_for_sure_and_the_hit_wipes_the_mark() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	var shaky: MoveData = BattleFixtures.move(Elements.E.STONE, 40)
	shaky.accuracy = 0.01
	m.active_spirling(0).moves = [shaky] as Array[MoveData]
	assert_true(m.apply_status(1, "marked"))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var types: Array[int] = BattleFixtures.types_of(ev)
	assert_false(types.has(T.MISSED), "a marked foe can't be missed")
	assert_true(types.has(T.DAMAGE))
	assert_eq(m.active_spirling(1).status, "", "the hit wiped the mark off")

func test_muddle_strikes_a_random_foe_in_a_multi_battle() -> void:
	var hit_other: bool = false
	for seed_value: int in 30:
		var mine: Array[Spirling] = _one("Kindlop", 30, ["Cinder Nip"])
		var theirs: Array[Spirling] = [BattleFixtures.make("Mossling", 30), BattleFixtures.make("Mossling", 30)]
		var m := BattleModel.new(mine, theirs, true, seed_value, 0)
		m.front_size = [1, 2] as Array[int]
		m.start()
		m.active_spirling(0).status = "muddle"
		m.active_spirling(0).status_turns = 2
		var ev: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(0, 0, 0, 0)] as Array[BattleAction])
		for e: BattleEvent in ev:
			if e.type == T.MOVE_USED and int(e.data.side) == 0 and bool(e.data.get("muddled", false)):
				assert_string_contains(e.describe(), "at random")
				if (e.data.targets as Array) == [1]:
					hit_other = true
	assert_true(hit_other, "a muddled Spirling sometimes strikes the foe it did not aim at")

func test_a_boss_keeps_a_status_half_as_long() -> void:
	var m := BattleModel.new(_one("Kindlop", 14), _one("Smoldrake", 14), false, 6, 0)
	m.foe_boss = "ashen_heart"
	m.start()
	var boss: Spirling = m.active_spirling(1)
	assert_true(boss.boss_guard)
	assert_true(m.apply_status(1, "soak"))
	assert_eq(boss.status_turns, 2, "Soak 3 turns -> 2 on a boss")
	m._cure(1, 0)
	assert_true(m.apply_status(1, "root"))
	assert_eq(boss.status_turns, StatusRules.BOSS_OPEN_TURNS, "an open-ended status ends on a boss")
	boss.end_battle()
	assert_false(boss.boss_guard, "end_battle clears the boss mark")

func test_hushed_air_keeps_every_status_off_both_sides() -> void:
	var m := BattleModel.new(_one("Kindlop"), _one("Mossling"), false, 3, 0)
	m.foe_rule = "hushed_air"
	m.start()
	m._events = []
	assert_false(m.apply_status(1, "scorch", 0, 0))
	assert_false(m.apply_status(0, "soak", 0, 1))
	var lines: Array[String] = _texts(m._events, T.STATUS_FAILED)
	assert_eq(lines.size(), 2)
	assert_string_contains(lines[0], "Hushed Air")

func test_calm_veil_keeps_foe_statuses_off_for_five_turns() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Mossling", 20, ["Calm Veil"]), _one("Kindlop"))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, T.STATUS_VEIL))
	m._events = []
	assert_false(m.apply_status(0, "scorch", 0, 1), "a foe's status is kept off")
	assert_string_contains(_texts(m._events, T.STATUS_FAILED)[0], "Calm Veil")
	var faded: bool = false
	for i: int in BattleRules.STATUS_VEIL_TURNS:
		for e: BattleEvent in m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1)):
			faded = faded or (e.type == T.STATUS_VEIL and int(e.data.turns) == 0)
	assert_true(faded, "the veil fades")
	assert_eq(m.status_veil[0], 0)
	assert_true(m.apply_status(0, "scorch", 0, 1), "after it fades statuses land again")

func test_glimmer_skin_may_scorch_a_physical_attacker() -> void:
	assert_eq(Database.species("Forgefly").trait_id, "glimmer_skin")
	assert_eq(Database.species("Prismist").trait_id, "unruffled")
	var scorched: bool = false
	for seed_value: int in 40:
		var m: BattleModel = BattleFixtures.model(_one("Puddlet", 20), _one("Forgefly", 20), true, seed_value)
		m._contact_status(1, 0, 0, 0)
		if m.active_spirling(0).status == "scorch":
			scorched = true
			assert_not_null(BattleFixtures.first_of(m._events, T.TRAIT), "the gift shows itself")
			break
	assert_true(scorched)

func test_unruffled_drops_its_status_when_it_steps_back() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Prismist", 20), BattleFixtures.make("Kindlop", 20)]
	var m: BattleModel = BattleFixtures.model(mine, _one("Mossling"))
	assert_true(m.apply_status(0, "soak"))
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	assert_eq(mine[0].status, "", "Unruffled shook the Soak off on the way out")

func test_mirror_scale_turns_the_first_foe_status_back() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	m.active_spirling(0).held = "mirror_scale"
	m._events = []
	assert_false(m.apply_status(0, "soak", 0, 1, 0))
	assert_eq(m.active_spirling(1).status, "soak", "the caster gets its own status")
	assert_string_contains(_texts(m._events, T.STATUS_FAILED)[0], "Mirror Scale")
	assert_true(m.apply_status(0, "daze", 0, 1, 0), "only once per battle")

func test_a_failed_status_says_why() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop", 20, ["Chalk Mark"]), _one("Mossling"))
	assert_true(m.apply_status(1, "soak"))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_string_contains(_texts(ev, T.STATUS_FAILED)[0], "already suffers from Soak")
	var steady: Spirling = BattleFixtures.make("Hushkin", 20)
	var m2: BattleModel = BattleFixtures.model(_one("Kindlop"), [steady] as Array[Spirling])
	m2._events = []
	assert_false(m2.apply_status(1, "daze", 0, 0))
	assert_string_contains(_texts(m2._events, T.STATUS_FAILED)[0], "can't get Daze")

func test_status_duration_does_not_depend_on_difficulty() -> void:
	for st: String in StatusRules.RULES:
		assert_false(StatusRules.RULES[st].has("difficulty"), st)
	var a := RandomNumberGenerator.new()
	a.seed = 5
	for st: String in StatusRules.RULES:
		var t: Array = StatusRules.RULES[st].turns
		var rolled: int = StatusRules.roll_turns(st, a)
		assert_true(rolled == 0 or (rolled >= int(t[0]) and rolled <= int(t[1])), st)

func test_a_swarm_takes_status_one_spirling_at_a_time() -> void:
	var theirs: Array[Spirling] = [BattleFixtures.make("Mossling", 10), BattleFixtures.make("Mossling", 10)]
	var m := BattleModel.new(_one("Kindlop", 10), theirs, true, 4, 0)
	m.front_size = [1, 2] as Array[int]
	m.start()
	assert_true(m.apply_status(1, "soak", 0))
	assert_eq(m.active_spirling(1, 1).status, "", "the other swarm member stays clean")

func test_master_ai_does_not_throw_status_into_hushed_air() -> void:
	var m := BattleModel.new(_one("Kindlop", 20, ["Cinder Nip"]), _one("Mossling", 20, ["Puffcap Haze", "Bowl Over"]), false, 9, 3)
	m.foe_rule = "hushed_air"
	m.start()
	var ai := BattleAI.new(3)
	assert_lt(ai.score_move(m, 1, 0), ai.score_move(m, 1, 1), "a status art is worth less than a hit under Hushed Air")

func test_first_status_brings_a_tip_once() -> void:
	var flags: Dictionary = {}
	var tip: String = BattleGuide.first_status_tip("soak", flags)
	assert_string_contains(tip, "Soak")
	assert_eq(BattleGuide.first_status_tip("soak", flags), "", "only the first time")
	assert_false(BattleGuide.first_status_tip("jolt", flags).is_empty(), "each status once")

func test_master_ai_plays_status_combos() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Zippit", 20, ["Crackle Bite"]), _one("Mossling", 20))
	var ai := BattleAI.new(3)
	var dry: float = ai.score_move(m, 0, 0)
	m.active_spirling(1).status = "soak"
	assert_gt(ai.score_move(m, 0, 0), dry, "a Volt hit on a soaked foe counts its reaction")

func test_online_duels_keep_the_calm_rule() -> void:
	var snap: Dictionary = BattleReferee.from_expect({"seed": 1, "teams": [[], []]})
	assert_false(bool(snap.wild), "a live duel is a Wayfarer duel, so the calm rule holds")

func test_every_status_has_its_own_symbol() -> void:
	var seen: Dictionary = {}
	for st: String in StatusRules.RULES:
		var sym: Array = StatusRules.symbol(st)
		assert_gt(sym.size(), 4, st)
		for d: Array in sym:
			assert_true(int(d[0]) >= 0 and int(d[0]) < InfoStrip.SYMBOL_SIZE and int(d[1]) >= 0 and int(d[1]) < InfoStrip.SYMBOL_SIZE, st)
		var key: String = str(sym)
		assert_false(seen.has(key), "%s has a shape of its own" % st)
		seen[key] = true

func test_status_turns_show_under_the_tag() -> void:
	assert_eq(StatusRules.turns_tag(2), "2")
	assert_eq(StatusRules.turns_tag(0), "", "an open-ended status shows no number")
	var strip := InfoStrip.new()
	strip.spirling_name = "Kindlop"
	strip.status = "soak"
	strip.set_status_turns(2)
	assert_string_contains(strip.screen_reader_text(), "2 turns left")
	strip.set_status("")
	assert_eq(strip.status_turns, 0, "a cured status takes its number along")
	strip.free()

func test_soak_and_jolt_make_a_combo() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	var foe: Spirling = m.active_spirling(1)
	assert_true(m.apply_status(1, "soak"))
	assert_false(m.apply_status(1, "daze"), "no combo: one status at a time")
	m._events = []
	assert_true(m.apply_status(1, "jolt"))
	assert_eq(foe.status, "jolt", "the Soak washed off")
	assert_eq(foe.sure_skip, 1)
	assert_string_contains(BattleFixtures.first_of(m._events, T.STATUS_APPLIED).describe(), "jolted stiff")
	foe.moves = [BattleFixtures.move(Elements.E.STONE, 40)] as Array[MoveData]
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_move(1, 0))
	assert_not_null(BattleFixtures.first_of(ev, T.STATUS_PREVENTED), "it surely loses its next turn")
	assert_eq(foe.sure_skip, 0)
	foe.end_battle()
	assert_eq(foe.sure_skip, 0)

func test_battle_report_counts_statuses() -> void:
	var r := BattleReport.new()
	r.begin("")
	r.add(BattleEvent.new(T.STATUS_APPLIED, {"side": 1, "slot": 0, "status": "soak"}))
	r.add(BattleEvent.new(T.STATUS_APPLIED, {"side": 1, "slot": 0, "status": "jolt"}))
	r.add(BattleEvent.new(T.STATUS_APPLIED, {"side": 0, "slot": 0, "status": "daze"}))
	assert_eq(r.status_line(), "Statuses: 2 on the foe, 1 on your team")
	assert_true(r.lines().has(r.status_line()))

func test_damage_preview_names_the_status_chance() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	var mv: MoveData = BattleFixtures.move(Elements.E.EMBER, 40)
	mv.effects = [{"id": "inflict_status", "status": "scorch", "chance": 0.3}] as Array[Dictionary]
	var foe: Spirling = m.active_spirling(1)
	var sc: Dictionary = CommandMenu.status_chance(m, foe, mv)
	assert_eq(sc, {"status": "scorch", "pct": 30})
	assert_eq(CommandMenu.move_line(mv, 9, 1.0, false, 40, -1, 0, 99, 0.0, 30, "scorch"), "%dE ~40%% SCO30" % mv.energy_cost)
	foe.status = "daze"
	assert_true(CommandMenu.status_chance(m, foe, mv).is_empty(), "no chance while another status sits there")
	foe.status = ""
	m.foe_rule = "hushed_air"
	assert_true(CommandMenu.status_chance(m, foe, mv).is_empty(), "nor where a rule keeps it off")

func test_root_shows_still_chain_links_at_the_feet() -> void:
	var spec: Dictionary = SpirlingAura.mote_spec("root")
	assert_eq(str(spec.shape), "chain")
	var box := Vector2(32, 32)
	var a: PackedVector2Array = SpirlingAura.mote_points(int(spec.drift), int(spec.count), 0.1, box)
	assert_eq(a, SpirlingAura.mote_points(int(spec.drift), int(spec.count), 0.7, box), "the links never move")
	for p: Vector2 in a:
		assert_gt(p.y, box.y * 0.8, "at the feet")
