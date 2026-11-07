extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 445-450, 563, 847): the newer move
## blocks bonus_vs_status, energy_tax, field_element, self_stage_after, stage_on_hit (stage_chance)
## and cooldown, each checked in a fixed battle with a fixed seed.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

## A test-only move built the same way moves.json entries are.
func _mv(extra: Dictionary) -> MoveData:
	var m: Dictionary = {"name": "Test Art", "element": "STONE", "kind": "FOCUS", "power": 50, "accuracy": 1.0, "energy": 2}
	m.merge(extra, true)
	return Database.parse_move(m)

func _with(species: String, level: int, mv: MoveData) -> Spirling:
	var s: Spirling = BattleFixtures.make(species, level, ["Bowl Over"])
	s.moves = [mv]
	return s

func _duel(a: Spirling, b: Spirling, seed_value: int = 7) -> BattleModel:
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, seed_value)
	m.start()
	return m

func _damage_to(events: Array[BattleEvent], side: int) -> int:
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.DAMAGE and int(e.data.side) == side and not e.data.has("status_tick"):
			return int(e.data.amount)
	return -1

# --- bonus_vs_status (445) ------------------------------------------------------

func test_bonus_vs_status_reads_the_targets_status() -> void:
	var mv: MoveData = _mv({"vs_status": "scorch", "vs_mult": 1.6})
	var t: Spirling = BattleFixtures.make("Mossling", 20)
	assert_eq(BattleRules.status_bonus(mv, t), 1.0, "no status, no bonus")
	t.status = "soak"
	assert_eq(BattleRules.status_bonus(mv, t), 1.0, "a different status does not count")
	t.status = "scorch"
	assert_almost_eq(BattleRules.status_bonus(mv, t), 1.6, 0.0001)
	var any: MoveData = _mv({"vs_status": "*", "vs_mult": 1.3})
	assert_almost_eq(BattleRules.status_bonus(any, t), 1.3, 0.0001, "* takes any status")
	t.status = ""
	assert_eq(BattleRules.status_bonus(any, t), 1.0)
	var low: MoveData = _mv({"vs_status": "stage_down", "vs_mult": 1.5})
	assert_eq(BattleRules.status_bonus(low, t), 1.0)
	t.stages["def"] = -1
	assert_almost_eq(BattleRules.status_bonus(low, t), 1.5, 0.0001, "stage_down takes a lowered stage")
	t.stages["def"] = 1
	assert_eq(BattleRules.status_bonus(low, t), 1.0, "a raised stage is no opening")

func test_bonus_vs_status_hits_harder_in_battle() -> void:
	var dealt: Array[int] = []
	for st: String in ["", "scorch"]:
		var a: Spirling = _with("Shalebat", 20, _mv({"vs_status": "scorch", "vs_mult": 1.6}))
		var b: Spirling = BattleFixtures.make("Mossling", 40, ["Bowl Over"])
		var m: BattleModel = _duel(a, b)
		b.status = st
		dealt.append(_damage_to(m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1)), 1))
	assert_gt(dealt[0], 0)
	# Same seed, same rolls: the only change is the x1.6 (int truncation leaves at most 1 off).
	assert_almost_eq(float(dealt[1]), float(dealt[0]) * 1.6, 1.6)
	assert_gt(dealt[1], dealt[0])

# --- energy_tax (446) -------------------------------------------------------------

func test_energy_tax_costs_one_more_for_two_turns() -> void:
	var a: Spirling = _with("Zippit", 20, _mv({"name": "Tax Test", "element": "VOLT", "kind": "STATUS", "power": 0, "accuracy": 1.0, "energy": 3, "effect": "energy_tax", "effect_amount": 2}))
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = _duel(a, b)
	var cost: int = b.moves[0].energy_cost
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var tax: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.ENERGY_TAX)
	assert_not_null(tax)
	assert_eq(tax.describe(), "%s is taxed: every art costs 1 more Energy for 2 turns!" % b.display_name())
	# After the turn it was laid in, two taxed turns are left.
	assert_eq(b.energy_tax, 2)
	assert_eq(b.move_cost(b.moves[0]), cost + 1)
	b.energy = cost
	assert_false(b.can_afford(b.moves[0]), "the plain cost is no longer enough")
	b.energy = cost + 1
	var before: int = b.energy
	ev = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_move(1, 0))
	var spent: int = 0
	for e: BattleEvent in ev:
		if e.type == BattleEvent.Type.ENERGY_CHANGED and int(e.data.side) == 1:
			spent = before - int(e.data.energy)
			break
	assert_eq(spent, cost + 1, "the taxed move took one Energy more")
	assert_eq(b.energy_tax, 1)
	ev = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(b.energy_tax, 0)
	var lift: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.ENERGY_TAX)
	assert_eq(lift.describe(), "The Energy tax on %s lifts." % b.display_name())
	assert_eq(b.move_cost(b.moves[0]), cost)

func test_energy_tax_ends_with_the_battle() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 10)
	s.energy_tax = 2
	s.cooldowns["Bowl Over"] = 2
	s.end_battle()
	assert_eq(s.energy_tax, 0)
	assert_true(s.cooldowns.is_empty())

# --- field_element (447) ---------------------------------------------------------

func test_field_element_takes_the_fields_element() -> void:
	var mv: MoveData = _mv({"name": "Cross Test", "element": "GALE", "power": 55, "field_element": true})
	assert_eq(BattleRules.resolve_move(mv, ""), mv, "no field: the move stays as it is")
	var hit: MoveData = BattleRules.resolve_move(mv, "static_veil")
	assert_eq(hit.element, E.VOLT, "Static Veil boosts Volt")
	assert_eq(hit.power, 75)
	assert_eq(mv.element, E.GALE, "the data move is never changed")
	assert_eq(mv.power, 55)
	assert_eq(BattleRules.resolve_move(mv, "static_veil"), hit, "the copy is cached")

func test_field_element_lands_in_the_field_element() -> void:
	var a: Spirling = _with("Zephlet", 20, _mv({"name": "Cross Test", "element": "GALE", "power": 55, "field_element": true}))
	var b: Spirling = BattleFixtures.make("Mossling", 40, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, 7)
	m.field = "ash_storm"
	m.start()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var used: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.MOVE_USED)
	assert_eq(int(used.data.element), E.EMBER, "Ash Storm turns it into an Ember art")
	var dmg: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.DAMAGE)
	assert_gt(float(dmg.data.eff), 1.0, "Ember overwhelms Bloom")

# --- self_stage_after (448) ------------------------------------------------------

func test_self_stage_after_drops_the_users_stage_even_on_a_ko() -> void:
	var a: Spirling = _with("Kindlop", 30, _mv({"element": "EMBER", "power": 90, "self_stages": {"foc": -1}}))
	var b: Spirling = BattleFixtures.make("Mossling", 10, ["Bowl Over"])
	# A second foe keeps the battle going, so the stages are not cleared by the battle end.
	var c: Spirling = BattleFixtures.make("Mossling", 10, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b, c] as Array[Spirling], false, 7)
	m.start()
	b.hp = 1
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true(b.is_fainted())
	assert_true(BattleFixtures.types_of(ev).has(BattleEvent.Type.FAINTED))
	assert_eq(a.stage("foc"), -1, "the user pays even though the target fell")

# --- stage_on_hit / stage_chance (449) --------------------------------------------

func test_stage_chance_one_always_raises() -> void:
	var a: Spirling = _with("Zephlet", 20, _mv({"element": "GALE", "kind": "PHYSICAL", "stat": "spd", "stages": 1, "self": true, "stage_chance": 1.0}))
	var b: Spirling = BattleFixtures.make("Mossling", 40, ["Bowl Over"])
	var m: BattleModel = _duel(a, b)
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a.stage("spd"), 1)

func test_stage_chance_rolls_with_the_battle_seed() -> void:
	var mv: MoveData = _mv({"element": "GALE", "kind": "PHYSICAL", "stat": "spd", "stages": 1, "self": true, "stage_chance": 0.3})
	assert_almost_eq(float(mv.effects[0].chance), 0.3, 0.0001, "stage_chance feeds the stat_change chance")
	var raised: int = 0
	var results: Array[int] = []
	for seed_value: int in 200:
		var a: Spirling = _with("Zephlet", 20, mv)
		var b: Spirling = BattleFixtures.make("Mossling", 40, ["Bowl Over"])
		var m: BattleModel = _duel(a, b, seed_value)
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		results.append(a.stage("spd"))
		raised += 1 if a.stage("spd") > 0 else 0
	assert_between(raised, 30, 90, "about 30%% of 200 hits raise Pace (got %d)" % raised)
	# The same seed gives the same result again.
	var a2: Spirling = _with("Zephlet", 20, mv)
	var m2: BattleModel = _duel(a2, BattleFixtures.make("Mossling", 40, ["Bowl Over"]), 5)
	m2.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a2.stage("spd"), results[5])

# --- cooldown (450) ------------------------------------------------------------------

func test_cooldown_locks_the_move_for_its_turns() -> void:
	var mv: MoveData = _mv({"name": "Slam Test", "power": 110, "energy": 2, "cooldown": 2})
	var a: Spirling = _with("Shalebat", 20, mv)
	var b: Spirling = BattleFixtures.make("Mossling", 50, ["Bowl Over"])
	var m: BattleModel = _duel(a, b)
	a.energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(a.cooldown_left(mv), 2, "locked for the next two turns")
	assert_false(a.can_afford(mv))
	assert_false(m.is_legal(BattleAction.make_move(0, 0)))
	assert_eq(CommandMenu.move_line(mv, a.energy, 1.0, false, -1, a.move_cost(mv), a.cooldown_left(mv)), "wait 2")
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(a.cooldown_left(mv), 1)
	assert_false(a.can_afford(mv))
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(a.cooldown_left(mv), 0)
	assert_true(a.can_afford(mv), "free again on the third turn")
	assert_true(m.is_legal(BattleAction.make_move(0, 0)))

func test_move_info_explains_the_new_blocks() -> void:
	var text: String = CommandMenu.move_info(_mv({"vs_status": "jolt", "vs_mult": 1.5, "cooldown": 2, "self_stages": {"foc": -1}}))
	assert_string_contains(text, "x1.5 power if the foe has Jolt.")
	assert_string_contains(text, "Locked for 2 turns after each use.")
	assert_string_contains(text, "Then lowers its own Focus by 1.")
	assert_string_contains(CommandMenu.move_info(_mv({"field_element": true})), "power +20")
	assert_string_contains(CommandMenu.move_info(_mv({"kind": "STATUS", "power": 0, "effect": "energy_tax", "effect_amount": 2})), "cost 1 more Energy for 2 turns")

# --- AI (563) ---------------------------------------------------------------------------

func test_ai_values_the_new_blocks() -> void:
	var tax: MoveData = _mv({"name": "Tax Test", "element": "VOLT", "kind": "STATUS", "power": 0, "energy": 3, "effect": "energy_tax", "effect_amount": 2})
	var a: Spirling = _with("Zippit", 20, tax)
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, 7, 1)
	m.start()
	var ai := BattleAI.new(1)
	assert_almost_eq(ai.score_move(m, 0, 0), BattleAI.TAX_BONUS_PER_TURN * 2.0, 0.0001, "0.15 per taxed turn")
	b.energy_tax = 2
	assert_almost_eq(ai.score_move(m, 0, 0), 0.0, 0.0001, "no point taxing twice")
	# A cooldown costs nothing on the turn it is used.
	var plain: MoveData = _mv({"name": "Plain Test", "power": 110, "energy": 2})
	var locked: MoveData = _mv({"name": "Plain Test", "power": 110, "energy": 2, "cooldown": 2})
	a.moves = [plain, locked]
	assert_almost_eq(ai.score_move(m, 0, 0), ai.score_move(m, 0, 1), 0.0001)
	# The status bonus enters the AI's damage estimate.
	var vs: MoveData = _mv({"name": "Vs Test", "vs_status": "*", "vs_mult": 1.5})
	a.moves = [vs]
	var dry: float = ai.score_move(m, 0, 0)
	b.status = "soak"
	assert_gt(ai.score_move(m, 0, 0), dry)

func test_validator_knows_the_new_keys() -> void:
	var dir: String = "user://test_move_effects"
	DirAccess.make_dir_recursive_absolute(dir)
	var bad: Array = [
		{"name": "A", "element": "STONE", "kind": "FOCUS", "power": 40, "accuracy": 1.0, "energy": 2, "vs_status": "nope"},
		{"name": "B", "element": "STONE", "kind": "FOCUS", "power": 40, "accuracy": 1.0, "energy": 2, "self_stages": {"luck": -1}},
		{"name": "C", "element": "STONE", "kind": "FOCUS", "power": 40, "accuracy": 1.0, "energy": 2, "cooldown": -1},
		{"name": "D", "element": "STONE", "kind": "FOCUS", "power": 40, "accuracy": 1.0, "energy": 2, "stat": "spd", "stage_chance": 1.5},
	]
	var f: FileAccess = FileAccess.open(dir + "/moves.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(bad))
	f.close()
	var errors: PackedStringArray = DataValidator.validate("res://data/spirlings.json", dir + "/moves.json")
	var joined: String = "\n".join(errors)
	assert_string_contains(joined, "unknown vs_status 'nope'")
	assert_string_contains(joined, "unknown stat 'luck' in self_stages")
	assert_string_contains(joined, "negative cooldown")
	assert_string_contains(joined, "stage_chance must be in (0, 1]")
	assert_eq(DataValidator.validate().size(), 0, "the real data stays clean")

func test_weary_fight_stops_healing_and_costs_vigor() -> void:
	var a: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var b: Spirling = BattleFixtures.make("Kindlop", 20, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	m.turn = BattleRules.WEARY_TURN
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.WEARY))
	assert_eq(a.max_hp() - a.hp, ceili(float(a.max_hp()) / float(BattleModel.WEARY_CHIP_DIV)))
	assert_eq(m.heal(0, 5), 0, "nobody heals once the fight is weary")
