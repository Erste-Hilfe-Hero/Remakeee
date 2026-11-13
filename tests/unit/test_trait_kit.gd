extends GutTest
## Kampf plan areas Traits (241-280) and Keepsakes (281-320): scripts/battle/TraitKit.gd.

func _mon(species: String = "Mossling", lvl: int = 20, held: String = "") -> Spirling:
	var s := Spirling.new(Database.species(species), lvl)
	s.held = held
	return s

func _model(me: Spirling, foe: Spirling = null, seed_value: int = 3) -> BattleModel:
	var f: Spirling = foe if foe != null else _mon()
	var m := BattleModel.new([me] as Array[Spirling], [f] as Array[Spirling], true, seed_value)
	m.start()
	return m

func _move_with(pred: Callable) -> MoveData:
	for mv: MoveData in Database.moves.values():
		if pred.call(mv):
			return mv
	return null

func _types(m: BattleModel) -> Array[int]:
	var out: Array[int] = []
	m.event_emitted.connect(func(ev: BattleEvent) -> void: out.append(ev.type))
	return out

func test_data_is_whole() -> void:
	for id: String in TraitKit.traits():
		var t: Dictionary = TraitKit.info(id)
		assert_false(str(t.get("label", "")).is_empty(), id)
		assert_false(str(t.get("text", "")).is_empty(), id)
		assert_eq(BattleRules.trait_info(id), t, "trait_info finds " + id)
	for id: Variant in TraitKit.keepsakes():
		assert_true(BattleRules.is_holdable(str(id)), str(id))
		assert_false(TraitKit.rarity(str(id)).is_empty(), "rarity shown for " + str(id))
	for k: String in TraitKit.data().get("bonus_traits", {}):
		for id: Variant in TraitKit.data().bonus_traits[k]:
			assert_true(TraitKit.traits().has(str(id)), "%s lists %s" % [k, id])
	for b: String in TraitKit.data().get("boss_traits", {}):
		assert_true(BattleRules.BOSSES.has(b), b)

func test_every_text_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for id: String in TraitKit.traits():
		assert_true(de.has(str(TraitKit.info(id).label)), id)
		assert_true(de.has(str(TraitKit.info(id).text)), id)
	for id: Variant in TraitKit.keepsakes():
		assert_true(de.has(str(Database.item(str(id)).name)), str(id))
		assert_true(de.has(str(Database.item(str(id)).description)), str(id))
	assert_true(de.has("%s's %s takes the edge off the hit!"))
	assert_true(de.has("%s's %s stirs!"))

func test_names_stay_unique() -> void:
	var seen: Dictionary = {}
	for id: String in BattleRules.TRAITS:
		seen[str(BattleRules.TRAITS[id].label)] = id
	for id: String in TraitKit.traits():
		assert_false(seen.has(str(TraitKit.info(id).label)), "gift name taken: " + id)
		seen[str(TraitKit.info(id).label)] = id
	var names: Dictionary = {}
	for it: Dictionary in Database.items.values():
		names[str(it.name)] = names.get(str(it.name), 0) + 1
	for id: Variant in TraitKit.keepsakes():
		assert_eq(int(names[str(Database.item(str(id)).name)]), 1, "item name taken: " + str(id))

func test_spare_flame_cuts_dear_arts_only() -> void:
	var s: Spirling = _mon()
	var dear: MoveData = _move_with(func(mv: MoveData) -> bool: return mv.energy_cost >= 5)
	var cheap: MoveData = _move_with(func(mv: MoveData) -> bool: return mv.energy_cost > 0 and mv.energy_cost < 5)
	var before: int = s.move_cost(dear)
	s.bonus_trait = "spare_flame"
	assert_eq(s.move_cost(dear), before - 1)
	assert_eq(s.move_cost(cheap), cheap.energy_cost)

func test_bonus_gift_needs_unfolding_and_kinship() -> void:
	var first: Spirling = _mon("Kindlop", 30)
	first.kinship = 999
	assert_true(TraitKit.bonus_options(first).is_empty(), "a first form learns none")
	var later: SpirlingData = null
	for sd: SpirlingData in Database.spirlings.values():
		if Database.earlier_form(sd) != null:
			later = sd
			break
	var s := Spirling.new(later, 30)
	s.kinship = 0
	assert_true(TraitKit.bonus_options(s).is_empty(), "kinship still too low")
	s.kinship = int(TraitKit.data().min_kinship)
	var opts: Array[String] = TraitKit.bonus_options(s)
	assert_eq(opts.size(), 3)
	assert_false(TraitKit.learn_bonus(s, "no_such_gift"))
	assert_true(TraitKit.learn_bonus(s, opts[1]))
	assert_true(opts[1] in TraitKit.extra_ids(s))
	var back: Spirling = Spirling.from_dict(s.to_dict())
	assert_eq(back.bonus_trait, opts[1], "saved and loaded")
	assert_false(_mon().to_dict().has("bonus_trait"), "old saves stay as they were")

func test_prism_gift_on_every_fourth_uid() -> void:
	var with: int = 0
	for i: int in 64:
		var s: Spirling = _mon()
		s.uid = "uid%d" % i
		s.prism = true
		if TraitKit.prism_trait_id(s) == "prism_skin":
			with += 1
			assert_true(ShopEffects.gift_table(s).has("super_taken"))
		s.prism = false
		assert_eq(TraitKit.prism_trait_id(s), "", "plain Spirlings never")
	assert_between(with, 4, 32)

func test_boss_takes_hush_core_and_halves_conditions() -> void:
	var boss: Spirling = _mon("Mossling", 30)
	var m := BattleModel.new([_mon()] as Array[Spirling], [boss] as Array[Spirling], false, 5)
	m.foe_boss = "ashen_heart"
	m.start()
	assert_true("hush_core" in TraitKit.extra_ids(boss))
	assert_eq(TraitKit.status_turns(boss, 4), 2)
	assert_eq(TraitKit.status_turns(boss, 3), 2)
	assert_eq(TraitKit.status_turns(boss, 0), 0, "endless stays endless")
	assert_eq(TraitKit.status_turns(_mon(), 4), 4)

func test_quiet_heart_cures_on_the_way_out() -> void:
	var me: Spirling = _mon()
	me.bonus_trait = "quiet_heart"
	var m := BattleModel.new([me, _mon()] as Array[Spirling], [_mon()] as Array[Spirling], true, 3)
	m.start()
	assert_true(m.apply_status(0, "scorch"))
	var types: Array[int] = _types(m)
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	assert_eq(me.status, "")
	assert_true(BattleEvent.Type.TRAIT in types)

func test_nimble_steps_out_of_roots() -> void:
	var me: Spirling = _mon("Mossling", 20, "kit_wander_boot")
	var m := BattleModel.new([me, _mon()] as Array[Spirling], [_mon()] as Array[Spirling], true, 3)
	m.start()
	me.status = "root"
	me.status_turns = 3
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	assert_eq(m.active_index(0), 1, "the boot walks out of the roots")
	var stuck: Spirling = _mon()
	var m2 := BattleModel.new([stuck, _mon()] as Array[Spirling], [_mon()] as Array[Spirling], true, 3)
	m2.start()
	stuck.status = "root"
	stuck.status_turns = 3
	m2.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	if StatusRules.blocks_swap("root"):
		assert_eq(m2.active_index(0), 0, "without it the roots hold")

func test_glow_hide_scorches_physical_attackers() -> void:
	var me: Spirling = _mon()
	var foe: Spirling = _mon()
	foe.bonus_trait = "glow_hide"
	var m: BattleModel = _model(me, foe)
	var phys: MoveData = _move_with(func(mv: MoveData) -> bool: return mv.kind == MoveData.Kind.PHYSICAL and mv.is_damaging())
	for i: int in 40:
		TraitKit.after_hit(m, 0, 0, 1, 0, phys, 5)
		if me.status == "scorch":
			break
	assert_eq(me.status, "scorch")
	var focus: MoveData = _move_with(func(mv: MoveData) -> bool: return mv.kind != MoveData.Kind.PHYSICAL and mv.is_damaging())
	var me2: Spirling = _mon()
	var m2: BattleModel = _model(me2, foe)
	for i: int in 40:
		TraitKit.after_hit(m2, 0, 0, 1, 0, focus, 5)
	assert_eq(me2.status, "", "focus arts never touch the hide")

func test_pack_sense_and_loner() -> void:
	var me: Spirling = _mon()
	var mv: MoveData = _move_with(func(x: MoveData) -> bool: return x.is_damaging())
	me.bonus_trait = "loner"
	var m: BattleModel = _model(me)
	assert_almost_eq(TraitKit.hit_mult(m, 0, 0, 1, 0, mv), 1.1, 0.001)
	me.bonus_trait = "pack_sense"
	assert_almost_eq(TraitKit.hit_mult(m, 0, 0, 1, 0, mv), 1.0, 0.001, "no pack in 1v1")
	var m2 := BattleModel.new([me, _mon()] as Array[Spirling], [_mon(), _mon()] as Array[Spirling], true, 3)
	m2.front_size = [2, 2]
	m2.start()
	assert_almost_eq(TraitKit.hit_mult(m2, 0, 0, 1, 0, mv), 1.15, 0.001)

func test_sentinel_first_turn_only() -> void:
	var me: Spirling = _mon()
	me.bonus_trait = "sentinel"
	var m: BattleModel = _model(me)
	var a: BattleAction = BattleAction.make_move(0, 0)
	a.actor = me
	assert_eq(TraitKit.priority_bonus(m, a), TraitKit.FIRST_ACT_PRIORITY)
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(TraitKit.priority_bonus(m, a), 0)

func test_field_runner_and_field_stones() -> void:
	var me: Spirling = _mon()
	var foe: Spirling = _mon()
	var ember: MoveData = _move_with(func(x: MoveData) -> bool: return x.is_damaging() and x.element == Elements.E.EMBER)
	assert_almost_eq(TraitKit.static_mult(me, null, ember, "ash_storm"), 1.0, 0.001)
	me.bonus_trait = "field_runner"
	assert_almost_eq(TraitKit.static_mult(me, null, ember, "ash_storm"), BattleRules.FIELD_BOOST, 0.001)
	me.bonus_trait = ""
	me.held = "kit_cinder_stone"
	assert_almost_eq(TraitKit.static_mult(me, null, ember, "ash_storm"), 1.15, 0.001)
	assert_almost_eq(TraitKit.static_mult(me, null, ember, "high_tide"), 1.0, 0.001)
	# The damage preview reads BattleRules.damage_mult, so it shows the stone too.
	var plain: float = BattleRules.damage_mult(_mon(), foe, ember, "ash_storm")
	assert_almost_eq(BattleRules.damage_mult(me, foe, ember, "ash_storm"), plain * 1.15, 0.001)

func test_prism_skin_and_counter_current() -> void:
	var target: Spirling = _mon()
	var super_mv: MoveData = _move_with(func(x: MoveData) -> bool: return x.is_damaging() and DamageCalc.effectiveness(target, x) > 1.0)
	var weak_mv: MoveData = _move_with(func(x: MoveData) -> bool: return x.is_damaging() and DamageCalc.effectiveness(target, x) > 0.0 and DamageCalc.effectiveness(target, x) < 1.0)
	target.bonus_trait = "prism_skin"
	assert_almost_eq(TraitKit.static_mult(_mon(), target, super_mv, ""), 0.75, 0.001)
	assert_almost_eq(TraitKit.static_mult(_mon(), target, weak_mv, ""), 1.0, 0.001)
	target.bonus_trait = "counter_current"
	assert_almost_eq(TraitKit.static_mult(_mon(), target, weak_mv, ""), 0.7, 0.001)

func test_echo_soul_and_lantern_glass_hold_fields() -> void:
	var s: Spirling = _mon()
	assert_eq(TraitKit.field_turns(s), BattleRules.RESONANCE_TURNS)
	s.bonus_trait = "echo_soul"
	assert_eq(TraitKit.field_turns(s), BattleRules.RESONANCE_TURNS + 2)
	s.held = "kit_lantern_glass"
	assert_eq(TraitKit.field_turns(s), BattleRules.RESONANCE_TURNS + 4)

func test_lantern_light_and_pace_feather_on_entry() -> void:
	var me: Spirling = _mon("Mossling", 20, "kit_pace_feather")
	me.bonus_trait = "lantern_light"
	var m: BattleModel = _model(me)
	assert_eq(me.stage("foc"), 1)
	assert_eq(me.stage("spd"), 1)

func test_cold_sleep_mends_while_drowsed() -> void:
	var me: Spirling = _mon()
	me.bonus_trait = "cold_sleep"
	var m: BattleModel = _model(me)
	me.hp = me.max_hp() / 2
	me.status = "drowse"
	me.status_turns = 3
	var hp: int = me.hp
	TraitKit.end_of_turn(m, 0, 0)
	assert_eq(me.hp, hp + me.max_hp() / 8)

func test_shock_pad_lucky_cap_rest_candle() -> void:
	var s: Spirling = _mon()
	assert_false(TraitKit.no_recoil(s))
	s.bonus_trait = "shock_pad"
	assert_true(TraitKit.no_recoil(s))
	s.bonus_trait = "lucky_cap"
	assert_almost_eq(BattleRules.mult_key(s, "crit_mult"), 1.5, 0.001)
	s.held = "kit_rest_candle"
	var m: BattleModel = _model(s)
	m.change_energy(0, -5)
	var e: int = s.energy
	m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(s.energy, mini(e + BattleModel.REST_ENERGY + 1 + BattleModel.ENERGY_PER_TURN, m.max_energy_of(0)))

func test_energy_crystal_raises_cap_and_start() -> void:
	var s: Spirling = _mon("Mossling", 20, "kit_energy_crystal")
	var m: BattleModel = _model(s)
	assert_eq(s.energy, m.max_energy_of(0) + 2)
	var plain: Spirling = _mon()
	var m2: BattleModel = _model(plain)
	assert_eq(plain.energy, m2.max_energy_of(0))

func test_ward_talisman_once_per_battle() -> void:
	var target: Spirling = _mon("Mossling", 20, "kit_ward_talisman")
	var me: Spirling = _mon()
	var m: BattleModel = _model(me, target)
	var super_mv: MoveData = _move_with(func(x: MoveData) -> bool: return x.is_damaging() and DamageCalc.effectiveness(target, x) > 1.0)
	var types: Array[int] = _types(m)
	assert_almost_eq(TraitKit.hit_mult(m, 0, 0, 1, 0, super_mv), 0.5, 0.001)
	assert_true(BattleEvent.Type.HELD_ITEM in types)
	assert_almost_eq(TraitKit.hit_mult(m, 0, 0, 1, 0, super_mv), 1.0, 0.001, "only once")

func test_rift_splinter_and_echo_shell() -> void:
	var s: Spirling = _mon("Mossling", 20, "kit_rift_splinter")
	assert_almost_eq(TraitKit.overcharge_bonus(s), 0.05, 0.0001)
	var me: Spirling = _mon("Mossling", 20, "kit_echo_shell")
	var m: BattleModel = _model(me)
	assert_almost_eq(TraitKit.bond_bonus(m), 0.05, 0.0001)

func test_tourney_keepsake_rules() -> void:
	for id: Variant in TraitKit.tourney_bans():
		assert_true(BattleRules.is_holdable(str(id)), str(id))
	assert_true(TraitKit.keepsakes_unique([_mon("Mossling", 20, "kit_rest_candle"), _mon("Mossling", 20, "kit_echo_shell"), _mon()]))
	assert_false(TraitKit.keepsakes_unique([_mon("Mossling", 20, "kit_rest_candle"), _mon("Mossling", 20, "kit_rest_candle")]))

func test_lexicon_lines() -> void:
	var gifts: Array[String] = TraitKit.all_gift_lines()
	assert_true(gifts.size() >= BattleRules.TRAITS.size() + TraitKit.traits().size())
	var thick: bool = false
	for l: String in gifts:
		thick = thick or l.begins_with("Thick Hide:")
	assert_true(thick, "the old gifts are listed too")
	assert_true(TraitKit.all_keepsake_lines().size() >= TraitKit.keepsakes().size())

func test_same_seed_same_battle_without_kit() -> void:
	# Hooks roll nothing unless a kit gift or keepsake is in play: two runs stay identical.
	var logs: Array[String] = []
	for run: int in 2:
		var r := RandomNumberGenerator.new()
		r.seed = 77
		var a := Spirling.new(Database.species("Mossling"), 20, r)
		var b := Spirling.new(Database.species("Mossling"), 20, r)
		var m: BattleModel = _model(a, b, 11)
		var lines: Array[String] = []
		for t: int in 6:
			for ev: BattleEvent in m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0)):
				lines.append(ev.describe())
			if m.is_finished():
				break
		logs.append("\n".join(lines))
	assert_eq(logs[0], logs[1])

func test_tower_top_hands_out_a_keepsake() -> void:
	var before: int = GameState.item_count("kit_cinder_stone")
	var lines: Array[String] = TraitKit.tower_reward("cinder_stair")
	assert_eq(GameState.item_count("kit_cinder_stone"), before + 1)
	assert_eq(lines.size(), 1)
	assert_eq(TraitKit.tower_reward("no_tower"), [] as Array[String])
	for id: String in TraitKit.data().tower_rewards:
		assert_false(RiftTower.find(id).is_empty(), id)

func test_endgame_exchange_sells_kit_keepsakes() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/endgame.json"))
	var sold: Array[String] = []
	for o: Dictionary in raw.exchange:
		sold.append(str(o.item))
	assert_true("kit_energy_crystal" in sold)
	assert_true("kit_ward_talisman" in sold)
