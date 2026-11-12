extends GutTest
## No top ring for Spirlings (owner decision 2026-11-12). XP and stats follow their formulas for
## any ring; Spirling.LEVEL_SANITY (9999) only guards against broken save data. STORY_RING (60)
## stays the top story ring and the PvP normalisation ring, never a growth cap.

var _flags: Dictionary
var _difficulty: int

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags
	_difficulty = GameState.difficulty
	GameState.flags = {}

func after_each() -> void:
	GameState.flags = _flags
	GameState.difficulty = _difficulty as GameState.Difficulty

func test_no_cap_constants_or_era_caps_left() -> void:
	var consts: Dictionary = (Spirling as Script).get_script_constant_map()
	assert_false(consts.has("MAX_LEVEL"))
	assert_false(consts.has("ERA_MAX_LEVEL"))
	var eras: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eras.json"))
	assert_false(eras.has("ring_caps"), "no per-era ring caps")
	assert_eq(Spirling.LEVEL_SANITY, 9999)

func test_level_150_and_500_keep_their_ring() -> void:
	for lvl: int in [150, 500]:
		var s: Spirling = BattleFixtures.make("Mossling", lvl)
		assert_eq(s.level, lvl)
		assert_eq(s.xp, Spirling.xp_for_level(lvl))
		assert_gt(s.xp_to_next(), 0, "ring %d still grows" % lvl)
		assert_false(s.moves.is_empty())
		assert_lte(s.moves.size(), Spirling.MAX_MOVES)

func test_xp_curve_continues_the_same_shape() -> void:
	assert_eq(Spirling.xp_for_level(60), 50393)
	assert_almost_eq(Spirling.xp_for_level(150), 545781, 1)
	assert_almost_eq(Spirling.xp_for_level(500), 12488298, 1)
	assert_almost_eq(Spirling.xp_for_level(Spirling.LEVEL_SANITY), 30134800719, 2, "fits in int, no overflow")
	var step: int = 0
	for lvl: int in range(2, 601):
		var d: int = Spirling.xp_for_level(lvl) - Spirling.xp_for_level(lvl - 1)
		assert_gt(d, step, "ring %d costs more than the one before" % lvl)
		step = d

func test_stats_keep_rising_past_the_old_caps() -> void:
	var s60: Spirling = BattleFixtures.make("Mossling", 60)
	var s96: Spirling = BattleFixtures.make("Mossling", 96)
	var s150: Spirling = BattleFixtures.make("Mossling", 150)
	var s500: Spirling = BattleFixtures.make("Mossling", 500)
	assert_gt(s96.max_hp(), s60.max_hp())
	assert_gt(s150.max_hp(), s96.max_hp())
	assert_gt(s500.max_hp(), s150.max_hp())
	assert_gt(s500.atk(), s150.atk())
	assert_gt(s500.def(), s150.def())
	assert_gt(s500.foc(), s150.foc())
	assert_gt(s500.spd(), s150.spd())
	assert_gt(s150.atk(), s96.atk())
	# Same formula as below 60: HP = floor((base + spark/2) * (L + 18) / 20) before multipliers.
	var base: float = float(s500.data.base_hp) + 8.0 * Spirling.SPARK_WEIGHT
	assert_eq(s500._curve(s500.data.base_hp, "hp", Spirling.HP_LEVEL_OFFSET, Spirling.HP_LEVEL_DIV), int(floor(base * 518.0 / 20.0)))

func test_level_up_past_500_and_a_ring_evolution() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 500)
	var hp_before: int = s.max_hp()
	s.level_up()
	assert_eq(s.level, 501)
	assert_gt(s.max_hp(), hp_before)
	var evo: SpirlingData = null
	for n: String in Database.spirlings:
		var sd: SpirlingData = Database.spirlings[n]
		for p: Dictionary in sd.unfold:
			if str(p.get("rule", "ring")) == "ring" and str(p.get("map", "")).is_empty() and int(p.get("value", 0)) > 0:
				evo = sd
		if evo != null:
			break
	assert_not_null(evo, "a species with a plain ring unfold")
	var e := Spirling.new(evo, 150)
	assert_true(e.can_evolve())
	e.evolve()
	assert_ne(e.data, evo)
	assert_eq(e.level, 150)

func test_save_round_trip_at_150_and_500() -> void:
	for lvl: int in [150, 500]:
		var s: Spirling = BattleFixtures.make("Mossling", lvl)
		s.xp += 7
		var back: Spirling = Spirling.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		assert_eq(back.level, lvl)
		assert_eq(back.xp, s.xp)
		assert_eq(back.max_hp(), s.max_hp())
	assert_eq(Spirling.from_dict({"species": "Mossling", "level": 10000000}).level, Spirling.LEVEL_SANITY, "garbage stays bounded")

func test_xp_bar_is_not_full_past_old_caps() -> void:
	var s: Spirling = BattleFixtures.make("Mossling", 500)
	assert_almost_eq(InfoStrip.xp_fraction(s), 0.0, 0.001)

func test_no_ring_limit_except_veteran_act_one() -> void:
	GameState.difficulty = GameState.Difficulty.TAMER
	assert_false(GameState.has_ring_limit())
	assert_eq(GameState.level_cap(), Spirling.LEVEL_SANITY)
	GameState.flags = {"story_complete": true, "era2_finale_done": true, "era3_finale_done": true}
	assert_eq(GameState.level_cap(), Spirling.LEVEL_SANITY, "eras add no cap")
	GameState.difficulty = GameState.Difficulty.VETERAN
	GameState.flags = {}
	assert_true(GameState.has_ring_limit())
	assert_lt(GameState.level_cap(), Spirling.LEVEL_SANITY)
	GameState.flags = {GameState.ACT1_END_FLAG: true}
	assert_false(GameState.has_ring_limit())
	assert_eq(GameState.level_cap(), Spirling.LEVEL_SANITY)

func test_battles_have_no_ring_limit_by_default() -> void:
	assert_eq(BattleModel.new().level_cap, Spirling.LEVEL_SANITY)

func test_halcyra_foes_keep_rings_past_sixty() -> void:
	var src: String = FileAccess.get_file_as_string("res://data/region4.json")
	var top: int = 0
	var rx := RegEx.create_from_string("\"ring\": *\\[?\\s*(\\d+)(?:,\\s*(\\d+))?")
	for m: RegExMatch in rx.search_all(src):
		top = maxi(top, int(m.get_string(2)) if not m.get_string(2).is_empty() else int(m.get_string(1)))
	assert_gt(top, Spirling.STORY_RING)
	assert_eq(BattleFixtures.make("Mossling", top).level, top)
