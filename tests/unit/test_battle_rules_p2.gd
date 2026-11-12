extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 857-860): reactions in a fuzz
## run, side snares, what a heal block stops and what it leaves alone, and priority -1.

const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _duel(a: Array[Spirling], b: Array[Spirling], seed_value: int = 7) -> BattleModel:
	var m: BattleModel = BattleFixtures.model(a, b, false, seed_value)
	m.start()
	return m

func _only(species: String, level: int, move: String) -> Spirling:
	return BattleFixtures.make(species, level, [move] as Array[String])

func _count(events: Array[BattleEvent], t: BattleEvent.Type) -> int:
	return events.filter(func(e: BattleEvent) -> bool: return e.type == t).size()

## Plain damage arts of [param element]: no effects, no priority, so only the reaction moves
## the numbers. Returned as sure-hit copies.
func _plain_arts(element: int) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for md: MoveData in Database.moves.values():
		if md.element == element and md.is_damaging() and md.effects.is_empty() and md.priority == 0 \
				and md.cooldown == 0 and not md.overcharge and md.target == "single":
			var c: MoveData = md.duplicate()
			c.accuracy = 1.0
			out.append(c)
	return out

# --- Item 857 -------------------------------------------------------------------------------

func test_every_reaction_fires_in_a_fuzz_run_and_scales_damage_by_its_factor() -> void:
	var names: Array = Database.spirlings.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 857
	var fired: Dictionary = {}
	for i: int in 200:
		var r: Dictionary = BattleRules.REACTIONS[i % BattleRules.REACTIONS.size()]
		var arts: Array[MoveData] = _plain_arts(int(Elements.E[str(r.element)]))
		assert_false(arts.is_empty(), "a plain %s art" % r.element)
		var mv: MoveData = arts[rng.randi_range(0, arts.size() - 1)]
		var a: Spirling = BattleFixtures.make(str(names[rng.randi_range(0, names.size() - 1)]), rng.randi_range(10, 50))
		var b: Spirling = BattleFixtures.make(str(names[rng.randi_range(0, names.size() - 1)]), rng.randi_range(10, 50))
		a.moves = [mv]
		a.energy = Spirling.MAX_ENERGY
		var m: BattleModel = _duel([a] as Array[Spirling], [b] as Array[Spirling], rng.randi())
		b.status = str(r.status)
		b.status_turns = 3
		# The factor: the same hit with the same roll, once on the afflicted foe and once with the
		# reaction taken out (status cleared for the multiplier only), differs by exactly "mult".
		var with: float = BattleRules.damage_mult(a, b, mv, "")
		b.status = ""
		var without: float = BattleRules.damage_mult(a, b, mv, "")
		b.status = str(r.status)
		var factor: float = float(r.get("mult", 1.0))
		assert_almost_eq(with / without, factor, 0.0001, "%s on %s" % [r.element, r.status])
		var r1 := RandomNumberGenerator.new()
		r1.seed = 99 + i
		var r2 := RandomNumberGenerator.new()
		r2.seed = 99 + i
		var hit: int = int(DamageCalc.compute(a, b, mv, r1, with).damage)
		var plain: int = int(DamageCalc.compute(a, b, mv, r2, without).damage)
		if plain > 1:
			assert_almost_eq(float(hit), float(plain) * factor, factor + 1.0, "damage %d vs %d" % [hit, plain])
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		var re: BattleEvent = BattleFixtures.first_of(ev, T.REACTION)
		if re == null:
			continue
		assert_eq(str(re.data.status), str(r.status))
		var key: String = "%s/%s" % [r.element, r.status]
		fired[key] = int(fired.get(key, 0)) + 1
		if not b.is_fainted():
			if bool(r.get("cure", false)):
				assert_ne(b.status, str(r.status), "%s washes the status away" % key)
			for st: String in r.get("stage", {}):
				assert_eq(b.stage(st), int(r.stage[st]), "%s moves %s" % [key, st])
	for r: Dictionary in BattleRules.REACTIONS:
		assert_gt(int(fired.get("%s/%s" % [r.element, r.status], 0)), 0, "%s on %s fired" % [r.element, r.status])

# --- Item 858 -------------------------------------------------------------------------------

func test_every_snare_acts_once_and_is_gone() -> void:
	var snare_arts: Array[String] = []
	for md: MoveData in Database.moves.values():
		if md.has_effect(&"side_snare"):
			snare_arts.append(md.move_name)
	assert_gte(snare_arts.size(), 7)
	for art: String in snare_arts:
		var a: Spirling = _only("Shalebat", 30, art)
		a.moves[0] = a.moves[0].duplicate()
		a.moves[0].accuracy = 1.0
		var b1: Spirling = _only("Mossling", 30, "Bowl Over")
		var b2: Spirling = _only("Kindlop", 30, "Bowl Over")
		var m: BattleModel = _duel([a] as Array[Spirling], [b1, b2] as Array[Spirling])
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		assert_eq((m.snares[1] as Array).size(), 1, art)
		var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_swap(1, 1))
		assert_eq(_count(ev, T.SNARE_HIT), 1, "%s springs once" % art)
		assert_true((m.snares[1] as Array).is_empty(), "%s is used up" % art)
		ev = m.submit_turn(BattleAction.make_rest(0), BattleAction.make_swap(1, 0))
		ev.append_array(m.submit_turn(BattleAction.make_rest(0), BattleAction.make_swap(1, 1)))
		assert_eq(_count(ev, T.SNARE_HIT), 0, "%s does not spring again" % art)

func test_scatter_gale_clears_every_snare_on_its_own_side_only() -> void:
	var a: Spirling = _only("Zephlet", 20, "Scatter Gale")
	var b: Spirling = _only("Mossling", 20, "Bowl Over")
	var m: BattleModel = _duel([a] as Array[Spirling], [b] as Array[Spirling])
	m.lay_snare(0, {"hp": 0.1}, "Shard Bed")
	m.lay_snare(0, {"status": "scorch"}, "Coal Seed")
	m.lay_snare(0, {"stage": {"spd": -1}}, "Dusk Snare")
	m.lay_snare(1, {"status": "soak"}, "Shoal Trap")
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true((m.snares[0] as Array).is_empty(), "all three on its own side are gone")
	assert_eq((m.snares[1] as Array).size(), 1, "the snare on the foe's side stays")

# --- Item 859 -------------------------------------------------------------------------------

func _blocked_turn(m: BattleModel, s: Spirling, player_action: BattleAction) -> int:
	s.hp = s.max_hp() / 2
	s.heal_block = 3
	m.submit_turn(player_action, BattleAction.make_rest(1))
	return s.hp

func test_heal_block_stops_art_gift_field_and_keepsake_heals() -> void:
	# Art: Candle Ward heals itself.
	var a: Spirling = _only("Kindlop", 20, "Candle Ward")
	var m: BattleModel = _duel([a] as Array[Spirling], [_only("Zippit", 20, "Bowl Over")] as Array[Spirling])
	a.energy = Spirling.MAX_ENERGY
	assert_eq(_blocked_turn(m, a, BattleAction.make_move(0, 0)), a.max_hp() / 2, "heal art")
	# Gift: Deep Roots mends at the end of each turn.
	var g: Spirling = _only("Mossling", 20, "Bowl Over")
	assert_eq(g.data.trait_id, "deep_roots")
	m = _duel([g] as Array[Spirling], [_only("Zippit", 20, "Bowl Over")] as Array[Spirling])
	assert_eq(_blocked_turn(m, g, BattleAction.make_rest(0)), g.max_hp() / 2, "gift regeneration")
	# Field: Pollen Drift mends Bloom Spirlings.
	var f: Spirling = _only("Bogwick", 20, "Bowl Over")
	m = _duel([f] as Array[Spirling], [_only("Zippit", 20, "Bowl Over")] as Array[Spirling])
	m.field = "pollen_drift"
	assert_eq(_blocked_turn(m, f, BattleAction.make_rest(0)), f.max_hp() / 2, "field heal")
	# Keepsake: Bark Wrap mends its holder.
	var k: Spirling = _only("Kindlop", 20, "Bowl Over")
	k.held = "bark_wrap"
	m = _duel([k] as Array[Spirling], [_only("Zippit", 20, "Bowl Over")] as Array[Spirling])
	m.items_allowed = true
	assert_eq(_blocked_turn(m, k, BattleAction.make_rest(0)), k.max_hp() / 2, "keepsake heal")
	# Without the block the same keepsake heals.
	k.heal_block = 0
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_gt(k.hp, k.max_hp() / 2, "the keepsake works once the block is off")

func test_heal_block_leaves_everything_else_alone() -> void:
	var seed_value: int = 21
	var hp: Array[int] = []
	var energy: Array[int] = []
	var stages: Array[int] = []
	for blocked: bool in [false, true]:
		var a: Spirling = _only("Kindlop", 30, "Bowl Over")
		var b: Spirling = _only("Zippit", 30, "Static Tag")
		b.moves[0] = b.moves[0].duplicate()
		b.moves[0].accuracy = 1.0
		var m: BattleModel = _duel([a] as Array[Spirling], [b] as Array[Spirling], seed_value)
		if blocked:
			a.heal_block = 4
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_move(1, 0))
		hp.append(a.hp)
		energy.append(a.energy)
		stages.append(a.stage("spd") + a.stage("atk") + a.stage("def"))
		# A bag item still heals through the block.
		a.hp = a.max_hp() / 2
		assert_gt(m._heal_spirling(0, 0, 5), 0, "a bag item heals (blocked %s)" % blocked)
	assert_eq(hp[0], hp[1], "damage taken is the same")
	assert_eq(energy[0], energy[1], "Energy is the same")
	assert_eq(stages[0], stages[1], "stages are the same")

# --- Item 860 -------------------------------------------------------------------------------

func test_priority_minus_one_acts_after_every_other_art_of_the_turn() -> void:
	var quake: Spirling = _only("Zephlet", 50, "Slow Quake")
	var ally: Spirling = _only("Calderox", 10, "Bowl Over")
	var f1: Spirling = _only("Mossling", 10, "Bowl Over")
	var f2: Spirling = _only("Kindlop", 10, "Bowl Over")
	assert_eq(quake.moves[0].priority, -1)
	for s: Spirling in [ally, f1, f2]:
		assert_gt(quake.effective_spd(), s.effective_spd(), "everyone else is slower")
	var m := BattleModel.new([quake, ally] as Array[Spirling], [f1, f2] as Array[Spirling], false, 5, 0)
	m.front_size = [2, 2]
	m.items_allowed = false
	m.start()
	quake.energy = Spirling.MAX_ENERGY
	var acts: Array[BattleAction] = [BattleAction.make_move(0, 0, 0, 0), BattleAction.make_move(0, 0, 1, 1),
		BattleAction.make_move(1, 0, 0, 0), BattleAction.make_move(1, 0, 1, 1)]
	var ev: Array[BattleEvent] = m.submit_actions(acts)
	var users: Array[String] = []
	for e: BattleEvent in ev:
		if e.type == T.MOVE_USED:
			users.append(str(e.data.get("move", "")))
	assert_eq(users.size(), 4, "all four act: %s" % [users])
	assert_eq(users[-1], "Slow Quake", "the fastest Spirling's priority -1 art comes last")
