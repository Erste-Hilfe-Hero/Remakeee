extends GutTest
## Battle plan areas "Fortschritt, XP und Training" and "Wild-Begegnungen und Bond"
## (docs/KAMPF_PLAN_1000.md): GrowthRules and WildRules.

func before_all() -> void:
	Database.load_all()

func _model(mine: Array[Spirling]) -> BattleModel:
	return BattleFixtures.model(mine, [BattleFixtures.make("Mossling", 5)] as Array[Spirling], true)

func _first_species_of(element: int) -> String:
	for sd: SpirlingData in Database.spirlings.values():
		if sd.elements.size() == 1 and sd.elements[0] == element:
			return sd.species_name
	return ""

# --- Growth -------------------------------------------------------------------------------

func test_story_and_rematches_grow_faster() -> void:
	var tamer: float = GrowthRules.battle_mult(GameState.Difficulty.TAMER, {}, {})
	assert_eq(tamer, 1.0)
	assert_gt(GrowthRules.battle_mult(GameState.Difficulty.STORY, {}, {}), tamer, "Story grows faster")
	assert_eq(GrowthRules.battle_mult(GameState.Difficulty.VETERAN, {}, {}), tamer)
	assert_gt(GrowthRules.battle_mult(GameState.Difficulty.TAMER, {"rematch": true}, {}), tamer, "a rematch grows faster")
	var rec: Dictionary = {}
	GrowthRules.grant_world_boost(rec)
	assert_gt(GrowthRules.battle_mult(GameState.Difficulty.TAMER, {}, rec), tamer, "the world goal boost")

func test_growth_charm_and_kinship_raise_one_spirlings_growth() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	assert_eq(GrowthRules.spirling_mult(s), 1.0)
	s.held = "growth_charm"
	assert_almost_eq(GrowthRules.spirling_mult(s), 1.5, 0.001)
	s.held = ""
	s.kinship = int(GrowthRules.num("kinship_min", 0))
	assert_gt(GrowthRules.spirling_mult(s), 1.0, "a fond Spirling learns a little faster")

func test_the_charm_works_in_battle() -> void:
	var plain: Spirling = BattleFixtures.make("Kindlop", 10)
	var charmed: Spirling = BattleFixtures.make("Kindlop", 10)
	charmed.held = "growth_charm"
	var start: int = plain.xp
	_model([plain] as Array[Spirling])._give_xp(plain, 40)
	_model([charmed] as Array[Spirling])._give_xp(charmed, 40)
	assert_eq(plain.xp - start, 40)
	assert_eq(charmed.xp - start, 60)

func test_several_rings_at_once_get_one_summary_line() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	var m: BattleModel = _model([s] as Array[Spirling])
	m._events = []
	m._give_xp(s, Spirling.xp_for_level(14) - s.xp)
	assert_eq(s.level, 14)
	var lines: Array[String] = []
	for e: BattleEvent in m._events:
		if e.type == BattleEvent.Type.SHOP_EDGE and e.describe().contains(" rings: "):
			lines.append(e.describe())
	assert_eq(lines, ["Kindlop grew 4 rings: ring 10 to ring 14."] as Array[String])
	assert_eq(m.growth_total, Spirling.xp_for_level(14) - Spirling.xp_for_level(10))
	m._events = []
	m._give_xp(s, 1)
	assert_null(BattleFixtures.first_of(m._events, BattleEvent.Type.SHOP_EDGE), "no line for one ring or less")

func test_there_is_no_top_ring_but_a_cap_still_blocks() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", Spirling.STORY_RING)
	var m: BattleModel = _model([s] as Array[Spirling])
	m.level_cap = Spirling.LEVEL_SANITY
	m._give_xp(s, Spirling.xp_for_level(Spirling.STORY_RING + 5) - s.xp)
	assert_eq(s.level, Spirling.STORY_RING + 5, "growth goes on past the story ring")
	var capped: Spirling = BattleFixtures.make("Kindlop", 12)
	var m2: BattleModel = _model([capped] as Array[Spirling])
	m2.level_cap = 12
	m2._give_xp(capped, 5000)
	assert_eq(capped.level, 12, "a Veteran ring cap blocks growth")

func test_bench_growth_is_counted_apart() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 10), BattleFixtures.make("Puddlet", 5)]
	var m: BattleModel = _model(mine)
	m._give_xp(mine[1], 7, true)
	assert_eq(m.bench_growth, 7)
	assert_eq(m.growth_total, 7)

func test_after_battle_counts_growth_by_region_and_writes_the_lexicon() -> void:
	var rec: Dictionary = {}
	var got: Array[String] = GrowthRules.after_battle(rec, "veydal", 30, 10)
	assert_eq(got, [GrowthRules.BENCH_LEXICON, GrowthRules.GROWTH_LEXICON] as Array[String])
	GrowthRules.after_battle(rec, "veydal", 5, 0)
	GrowthRules.after_battle(rec, "corvane", 50, 0)
	assert_eq(rec[GrowthRules.AREA_RECORD], {"veydal": 35, "corvane": 50})
	var lines: Array[String] = GrowthRules.summary_lines(rec)
	assert_string_contains(lines[1], "Corvane: 50", "most growth first")
	GrowthRules.grant_world_boost(rec)
	var left: int = int(rec[GrowthRules.WORLD_RECORD])
	GrowthRules.after_battle(rec, "veydal", 1, 0)
	assert_eq(int(rec[GrowthRules.WORLD_RECORD]), left - 1, "each battle uses up one boosted battle")
	for id: String in [GrowthRules.BENCH_LEXICON, GrowthRules.GROWTH_LEXICON, WildRules.BOND_LEXICON]:
		assert_true(Lexicon.has_entry(id), id)

## Balance goal "kein Grind-Zwang": between two Warden ring caps a Spirling never needs more than
## no_grind_battles even wild battles against foes of the median growth yield.
func test_no_grind_between_warden_caps() -> void:
	var yields: Array[int] = []
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "veydal":
			yields.append(sd.xp_yield)
	yields.sort()
	var low: int = yields[yields.size() / 2]
	var budget: int = int(GrowthRules.num("no_grind_battles", 0))
	assert_gt(budget, 0)
	var caps: Array[int] = GameState.LEVEL_CAPS
	for i: int in caps.size() - 1:
		var n: int = GrowthRules.battles_between(caps[i], caps[i + 1], low, GameState.Difficulty.TAMER)
		assert_lte(n, budget, "ring %d to %d takes %d battles" % [caps[i], caps[i + 1], n])
		assert_lte(GrowthRules.battles_between(caps[i], caps[i + 1], low, GameState.Difficulty.STORY), n, "Story never needs more")

func test_online_duels_never_change_the_real_team() -> void:
	var real: Spirling = BattleFixtures.make("Kindlop", 20)
	var copies: Array[Spirling] = EchoTeam.duel_copy([real] as Array[Spirling])
	assert_false(copies[0] == real, "duels fight with copies")
	var xp: int = real.xp
	_model(copies)._give_xp(copies[0], 500)
	assert_eq(real.xp, xp)
	assert_eq(real.level, 20)

func test_curve_table_documents_the_rings() -> void:
	var t: String = GrowthRules.curve_table(80)
	assert_string_contains(t, "| 60 |")
	assert_string_contains(t, "| 100 |")
	assert_string_contains(t, "There is no top ring")

# --- Wild encounters and bonds -----------------------------------------------------------

func test_a_field_calms_wild_spirlings_of_its_element() -> void:
	var bloom: Spirling = BattleFixtures.make(_first_species_of(Elements.E.BLOOM), 5)
	var ember: Spirling = BattleFixtures.make(_first_species_of(Elements.E.EMBER), 5)
	assert_eq(WildRules.field_bond_bonus("", bloom), 0.0)
	assert_gt(WildRules.field_bond_bonus("pollen_drift", bloom), WildRules.field_bond_bonus("pollen_drift", ember))
	assert_gt(WildRules.field_bond_bonus("pollen_drift", ember), 0.0, "pollen calms every kind a little")
	assert_eq(WildRules.field_bond_bonus("high_tide", ember), 0.0)
	assert_gt(BondCalc.chance(bloom, 1.0, WildRules.field_bond_bonus("pollen_drift", bloom)), BondCalc.chance(bloom, 1.0, 0.0))

func test_bond_tries_are_counted_by_the_model() -> void:
	var m: BattleModel = _model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling])
	m.submit_turn(BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0))
	assert_eq(m.bond_tries, 1)

func test_bond_statistics_count_tries_bonds_and_kinds() -> void:
	var m: BattleModel = _model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling])
	var rec: Dictionary = {}
	assert_eq(WildRules.after_battle(rec, m), [] as Array[String], "no echo call, nothing counted")
	m.bond_tries = 2
	m.bonded = BattleFixtures.make("Mossling", 5)
	assert_eq(WildRules.after_battle(rec, m), [WildRules.BOND_LEXICON] as Array[String])
	m.bond_tries = 1
	m.bonded = null
	WildRules.after_battle(rec, m)
	var lines: Array[String] = WildRules.bond_lines(rec)
	assert_eq(lines, ["Echo calls answered: 3", "Bonds formed: 1", "Kinds bonded this way: 1"] as Array[String])
	for l: String in lines:
		assert_false(l.contains("%"), "never a percentage")

func test_a_chain_raises_the_prism_chance_up_to_a_limit() -> void:
	assert_eq(WildRules.prism_chance(0), Spirling.PRISM_CHANCE)
	assert_gt(WildRules.prism_chance(4), WildRules.prism_chance(1))
	var top: int = int(WildRules.data().get("prism_chain_max", 0))
	assert_eq(WildRules.prism_chance(top + 50), WildRules.prism_chance(top), "capped")

func test_nights_outdoors_bring_more_encounters() -> void:
	assert_gt(WildRules.rate_mult(DayCycle.Phase.NIGHT, true, true), 1.0)
	assert_eq(WildRules.rate_mult(DayCycle.Phase.NIGHT, false, true), 1.0, "not indoors")
	assert_eq(WildRules.rate_mult(DayCycle.Phase.NIGHT, true, false), 1.0, "not with day and night off")
	assert_eq(WildRules.rate_mult(DayCycle.Phase.DAY, true, true), 1.0)

func test_weather_brings_out_its_elements() -> void:
	assert_true(Elements.E.TIDE in WildRules.weather_boost("rain"))
	assert_true(Elements.E.VOLT in WildRules.weather_boost("storm"))
	assert_eq(WildRules.weather_boost("clear"), [] as Array[int])

func test_some_wild_spirlings_carry_a_keepsake_without_changing_the_roll() -> void:
	var with_item: int = 0
	for s: int in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var before: int = rng.state
		var w: Spirling = BattleFixtures.make("Mossling", 5)
		WildRules.roll_held(w, rng)
		assert_eq(rng.state, before, "the encounter generator is untouched")
		if not w.held.is_empty():
			with_item += 1
			assert_true(Database.item(w.held).has("held"), w.held)
	assert_between(with_item, 1, 60, "rare")

func test_held_items_of_wild_spirlings_and_new_items_exist() -> void:
	for it: Dictionary in WildRules.data().get("held_items", []):
		assert_true(Database.item(str(it.item)).has("held"), str(it.item))
	assert_gt(float(Database.item("echo_shell").get("bond_bonus", 0.0)), float(Database.item("kin_charm").get("bond_bonus", 0.0)))
	assert_true(Database.item("growth_charm").has("held"))

func test_spirlog_page_names_the_rarity() -> void:
	GameState.mark_seen("Talusk", true)
	assert_string_contains(SpirlogBook.page_text(Database.species("Talusk"), GameState.spirlog), "Rarity: ")

func test_spawn_tables_are_valid() -> void:
	for t: String in EncounterTable.table_ids():
		var spawns: Array = EncounterTable.table(t).get("spawns", [])
		assert_false(spawns.is_empty(), t)
		for s: Dictionary in spawns:
			assert_not_null(Database.species(str(s.get("species", ""))), "%s: %s" % [t, s])
			assert_gt(int(s.get("weight", 1)), 0, "%s: %s" % [t, s])
			var lo: int = int(s.get("min", 2))
			assert_between(lo, 1, int(s.get("max", 4)), "%s: %s" % [t, s])
			for g: String in EncounterTable.grounds_of(s):
				assert_true(g in EncounterTable.GROUND_NAMES, "%s: ground %s" % [t, g])

func test_every_festival_sells_spark() -> void:
	for f: Dictionary in Season.festivals():
		var items: Array = (f.shop as Array).map(func(o: Dictionary) -> String: return str(o.item))
		assert_true("spark_charm" in items, str(f.id))

func test_spark_wash_sets_one_spark_back_to_nothing() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20)
	s.spark["spd"] = 9
	s.spark["hp"] = 12
	s.hp = s.max_hp()
	assert_true(GrowthRules.reset_spark(s, "spd"))
	assert_eq(s.spark["spd"], 0)
	assert_false(GrowthRules.reset_spark(s, "spd"), "already dark")
	assert_false(GrowthRules.reset_spark(s, "luck"), "no such value")
	assert_true(GrowthRules.reset_spark(s, "hp"))
	assert_lte(s.hp, s.max_hp(), "Vigor never above the new top")
	assert_true(bool(Database.item("spark_wash").get("spark_reset", false)))

func test_tower_sections_leave_finds() -> void:
	assert_eq(GrowthRules.tower_finds(0, 4, 5), [] as Array[String])
	var finds: Array[String] = GrowthRules.tower_finds(3, 15, 5)
	assert_eq(finds.size(), 3, "floors 5, 10 and 15")
	for id: String in finds:
		assert_false(Database.item(id).is_empty(), id)
	assert_eq(GrowthRules.tower_finds(5, 9, 5), [] as Array[String], "only new section ends")

func test_growth_line_names_every_spirling_that_grew() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 10), BattleFixtures.make("Puddlet", 5)]
	var m: BattleModel = _model(mine)
	m._give_xp(mine[0], 30)
	m._give_xp(mine[1], 12, true)
	assert_eq(GrowthRules.distribution_line(mine, m.growth_by), "Growth: Kindlop +30, Puddlet +12")
	assert_eq(GrowthRules.distribution_line(mine, {}), "")

func test_a_full_move_list_gives_one_line_instead_of_a_choice() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 1)
	var target: int = -1
	for lv: int in range(2, 40):
		if not s.data.moves_learned_at(lv).is_empty():
			target = lv
			break
	assert_gt(target, 0, "Kindlop learns something")
	s = BattleFixtures.make("Kindlop", target - 1)
	while s.moves.size() < Spirling.MAX_MOVES:
		s.moves.append(BattleFixtures.move(Elements.E.EMBER, 40))
	var m: BattleModel = _model([s] as Array[Spirling])
	m._events = []
	m._give_xp(s, Spirling.xp_for_level(target) - s.xp)
	var lines: Array[String] = []
	for e: BattleEvent in m._events:
		if e.type == BattleEvent.Type.SHOP_EDGE:
			lines.append(e.describe())
	assert_false(lines.is_empty())
	assert_string_contains(lines[0], "already knows four arts")

func test_swarms_and_kinds_of_the_week_raise_one_kind() -> void:
	var sw: Dictionary = WildRules.swarm("2026-11-13")
	assert_eq(sw, WildRules.swarm("2026-11-13"), "the same all day")
	assert_true(str(sw.species) in EncounterTable.species_on(str(sw.table)), "a native kind")
	var mults: Dictionary = WildRules.event_mults(str(sw.table), "2026-11-13")
	assert_gte(int(mults.get(str(sw.species), 1)), int(WildRules.data().swarm_mult))
	assert_eq(WildRules.week_of("2026-11-13"), WildRules.week_of("2026-11-14"))
	assert_ne(WildRules.week_of("2026-11-13"), WildRules.week_of("2026-11-25"))
	var t: String = EncounterTable.table_ids()[0]
	assert_true(WildRules.weekly(t, 100) in EncounterTable.species_on(t))
	assert_false(WildRules.event_lines("2026-11-13").is_empty())

func test_event_weights_steer_the_roll() -> void:
	var t: String = EncounterTable.table_ids()[0]
	var kinds: Array[String] = EncounterTable.species_on(t)
	var favourite: String = kinds[kinds.size() - 1]
	var hits: int = 0
	for i: int in 200:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var w: Spirling = EncounterTable.roll(t, rng, [] as Array[int], "", {}, {favourite: 1000})
		if w != null and w.data.species_name == favourite:
			hits += 1
	assert_gt(hits, 150)

# --- Training ring -----------------------------------------------------------------------

func test_dummies_are_real_kinds_at_the_teams_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	assert_eq(TrainingGround.dummies().size(), 3)
	for d: Dictionary in TrainingGround.dummies():
		var s: Spirling = TrainingGround.make(d, 20, rng)
		assert_not_null(s, str(d.id))
		assert_eq(s.level, 20 + int(d.ring_offset))
		assert_eq(s.display_name(), str(d.name))
		var info: Dictionary = TrainingGround.bout_info(d)
		assert_true(bool(info.friendly), "a friendly bout: nothing lost")
		assert_eq(int(info.money), 0)
	assert_eq(TrainingGround.ring_for(TrainingGround.dummies()[0], 1), TrainingGround.MIN_RING)

func test_training_grows_slower_than_the_road() -> void:
	assert_lt(GrowthRules.battle_mult(GameState.Difficulty.TAMER, {"practice": true}, {}), 1.0)

func test_training_goals_pay_once_and_the_record_counts() -> void:
	var rec: Dictionary = {}
	var met: Array[Dictionary] = TrainingGround.after_bout(rec, "straw", true, 40)
	assert_eq(met.map(func(g: Dictionary) -> String: return str(g.id)), ["first_bout"])
	assert_eq(TrainingGround.after_bout(rec, "straw", false, 5), [] as Array[Dictionary], "a lost bout meets nothing")
	for i: int in 2:
		TrainingGround.after_bout(rec, "oak", true, 10)
	met = TrainingGround.after_bout(rec, "oak", true, 10)
	var ids: Array = met.map(func(g: Dictionary) -> String: return str(g.id))
	assert_true("oak_three" in ids)
	met = TrainingGround.after_bout(rec, "oak", true, 10)
	assert_false(met.map(func(g: Dictionary) -> String: return str(g.id)).has("oak_three"), "never twice")
	var st: Dictionary = TrainingGround.state(rec)
	assert_eq(int(st.bouts), 6)
	assert_eq(int(st.wins), 5)
	assert_eq(int(st.growth), 85)
	assert_string_contains("\n".join(TrainingGround.stat_lines(rec)), "Oak Dummy: 4")
	assert_string_contains("\n".join(TrainingGround.goal_lines(rec)), "[x] Win one bout.")
	for g: Dictionary in TrainingGround.goals():
		assert_false(Database.item(str(g.reward)).is_empty(), str(g.reward))

func test_the_lighthouse_has_the_training_keeper() -> void:
	var m: MapData = MapData.load_map("lighthouse")
	var found: bool = false
	for n: Dictionary in m.npcs:
		if str(n.get("id", "")) == "tamsin":
			found = true
	assert_true(found)
	assert_true(Dialogue.exists("lighthouse/tamsin"))

func test_the_storm_lantern_sets_the_encounter_rate() -> void:
	var rec: Dictionary = {}
	assert_eq(WildRules.lantern_mult(rec, true), 1.0, "normal by default")
	rec[WildRules.LANTERN_RECORD] = 0
	assert_lt(WildRules.lantern_mult(rec, true), 1.0)
	assert_eq(WildRules.lantern_mult(rec, false), 1.0, "only with the lantern")
	rec[WildRules.LANTERN_RECORD] = 2
	assert_gt(WildRules.lantern_mult(rec, true), 1.0)
	rec[WildRules.LANTERN_RECORD] = 9
	assert_eq(WildRules.lantern_setting(rec), 2)
	assert_true(Database.item(WildRules.LANTERN_ITEM).get("gear", false))

func test_a_horde_has_a_leader_and_wavers_without_it() -> void:
	var a: Spirling = BattleFixtures.make("Mossling", 5)
	var b: Spirling = BattleFixtures.make("Mossling", 9)
	assert_null(WildRules.horde_leader([a]), "a lone wild Spirling leads nothing")
	assert_eq(WildRules.horde_leader([a, b]), b)
	assert_eq(WildRules.horde_leader([b, BattleFixtures.make("Mossling", 9)]), b, "the first on a tie")
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [a, b] as Array[Spirling], true)
	m._events = []
	m._horde_wavers()
	assert_eq(m.active_spirling(BattleModel.Side.FOE, 0).stage("atk"), -1)
	assert_not_null(BattleFixtures.first_of(m._events, BattleEvent.Type.SHOP_EDGE))

# --- Batch 3: battle sparks, bond rings, wild surprise, elders, fog -----------------------

func test_a_won_battle_can_raise_a_spark_in_the_foes_strongest_value() -> void:
	var foe: Spirling = BattleFixtures.make("Mossling", 5)
	var key: String = GrowthRules.spark_source(foe)
	for k: String in Spirling.STAT_KEYS:
		assert_true(foe.data.base_stat(key) >= foe.data.base_stat(k), "the strongest value")
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	s.spark[key] = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(GrowthRules.battle_spark(s, foe, 0.0, rng), "", "no chance, no spark")
	var line: String = GrowthRules.battle_spark(s, foe, 1.0, rng)
	assert_eq(s.spark[key], 4)
	assert_eq(line, "Kindlop's %s spark brightens." % key.to_upper())
	s.spark[key] = Spirling.SPARK_MAX
	assert_eq(GrowthRules.battle_spark(s, foe, 1.0, rng), "", "a full spark stays")
	assert_eq(s.spark[key], Spirling.SPARK_MAX)
	assert_between(GrowthRules.num("battle_spark_chance", 0.0), 0.01, 0.5)

func test_battle_sparks_only_where_the_overworld_turns_them_on() -> void:
	var foe: Spirling = BattleFixtures.make("Mossling", 5)
	var key: String = GrowthRules.spark_source(foe)
	var s: Spirling = BattleFixtures.make("Kindlop", 10)
	s.spark[key] = 0
	var m: BattleModel = BattleFixtures.model([s] as Array[Spirling], [foe] as Array[Spirling], true)
	m.participants = [s] as Array[Spirling]
	m._events = []
	m._award_xp(foe)
	assert_eq(s.spark[key], 0, "off by default (duels, sims, training ring)")
	m.battle_spark_chance = 1.0
	m._award_xp(foe)
	assert_eq(s.spark[key], 1)
	var lines: Array[String] = []
	for e: BattleEvent in m._events:
		if e.type == BattleEvent.Type.SHOP_EDGE and e.describe().contains("spark brightens"):
			lines.append(e.describe())
	assert_eq(lines.size(), 1)

func test_bond_rings_swell_and_fade() -> void:
	for i: int in BondRings.RINGS:
		assert_eq(BondRings.ring_at(i, 0.0, 40.0).y, 0.0, "nothing before the start")
		assert_eq(BondRings.ring_at(i, 1.0, 40.0).y, 0.0, "all faded at the end")
	var early: Vector2 = BondRings.ring_at(0, 0.2, 40.0)
	var later: Vector2 = BondRings.ring_at(0, 0.4, 40.0)
	assert_gt(early.y, 0.0)
	assert_gt(later.x, early.x, "the ring swells")
	assert_true(SpirlingSprite.new().has_method("bond_rings"))

func test_the_wild_ambush_comes_more_often_at_night() -> void:
	assert_eq(WildRules.ambush_mult(DayCycle.Phase.DAY), 1.0)
	assert_eq(WildRules.ambush_mult(-1), 1.0, "indoors or without day and night")
	assert_gt(WildRules.ambush_mult(DayCycle.Phase.NIGHT), 1.0)
	assert_lt(BattleModel.AMBUSH_CHANCE * WildRules.ambush_mult(DayCycle.Phase.NIGHT), 0.5, "still rare")

func test_elders_appear_only_after_act_one() -> void:
	var rng := RandomNumberGenerator.new()
	var found: int = 0
	for i: int in 2000:
		rng.seed = i
		var w: Spirling = BattleFixtures.make("Mossling", 30)
		assert_false(WildRules.roll_elder(w, false, rng), "never before the end of Act I")
		if WildRules.roll_elder(w, true, rng):
			found += 1
	assert_between(found, 1, 300, "rare, but they come")
	var e: Spirling = BattleFixtures.make("Mossling", 30)
	WildRules.make_elder(e)
	assert_true(WildRules.is_elder(e))
	assert_eq(e.level, 30 + int(WildRules.data().get("elder_rings", 0)))
	for k: String in Spirling.STAT_KEYS:
		assert_true(int(e.spark[k]) >= int(WildRules.data().get("elder_spark", 0)))
	assert_eq(e.hp, e.max_hp())
	assert_gt(WildRules.elder_growth([e]), 1.0)
	assert_eq(WildRules.elder_growth([BattleFixtures.make("Mossling", 30)]), 1.0)
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 40)] as Array[Spirling], [e] as Array[Spirling], true)
	var lines: Array[String] = []
	for ev: BattleEvent in m.start():
		if ev.type == BattleEvent.Type.SHOP_EDGE:
			lines.append(ev.describe())
	assert_has(lines, WildRules.ELDER_LINE % e.display_name())

func test_fog_limits_sight_in_wild_battles() -> void:
	assert_lt(WildRules.sight_mult("fog"), 1.0)
	assert_eq(WildRules.sight_mult(""), 1.0)
	assert_eq(WildRules.sight_mult("rain"), 1.0)
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 5)] as Array[Spirling], true)
	m.sight_mult = WildRules.sight_mult("fog")
	var lines: Array[String] = []
	for ev: BattleEvent in m.start():
		if ev.type == BattleEvent.Type.SHOP_EDGE:
			lines.append(ev.describe())
	assert_has(lines, WildRules.FOG_LINE)
	var clear: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 10)] as Array[Spirling], [BattleFixtures.make("Mossling", 5)] as Array[Spirling], true)
	assert_null(BattleFixtures.first_of(clear.start(), BattleEvent.Type.SHOP_EDGE), "no opening line on a clear day")
