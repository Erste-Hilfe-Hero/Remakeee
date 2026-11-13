extends GutTest
## KAMPF_PLAN_1000 area "Werte-Stufen und Werte": the stage range and factors, stages staying
## through a swap, copy and trade arts, bosses taking lowered stages half, the +2 Might warning,
## the fixed keen-hit numbers, one value formula for everyone and the base value checks.

const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _one(species: String, level: int = 20, moves: Array[String] = []) -> Array[Spirling]:
	var out: Array[Spirling] = [BattleFixtures.make(species, level, moves)]
	return out

func test_stage_range_and_factors_stay_chimoras_own() -> void:
	assert_eq(BattleRules.STAGE_MIN, -3)
	assert_eq(BattleRules.STAGE_MAX, 3)
	assert_almost_eq(BattleRules.stage_mult(3), 2.5, 0.0001)
	assert_almost_eq(BattleRules.stage_mult(2), 2.0, 0.0001)
	assert_almost_eq(BattleRules.stage_mult(-3), 0.4, 0.0001)
	assert_almost_eq(BattleRules.stage_mult(9), 2.5, 0.0001, "clamped to the range")
	assert_eq(BattleRules.stage_line("Might", 2), "Might +2: x2.00")
	assert_eq(BattleRules.stage_line("Pace", -1), "Pace -1: x0.67")

func test_no_aim_or_dodge_stages() -> void:
	assert_eq(BattleRules.STAGE_STATS, ["atk", "def", "foc", "spd"] as Array[String])

func test_stages_stay_through_a_swap_and_end_with_the_battle() -> void:
	var mine: Array[Spirling] = [BattleFixtures.make("Kindlop", 20), BattleFixtures.make("Puddlet", 20)]
	var m: BattleModel = BattleFixtures.model(mine, _one("Mossling"))
	m.change_stage(0, "atk", 2)
	m.submit_turn(BattleAction.make_swap(0, 1), BattleAction.make_rest(1))
	m.submit_turn(BattleAction.make_swap(0, 0), BattleAction.make_rest(1))
	assert_eq(mine[0].stage("atk"), 2, "the stage waited on the bench")
	mine[0].end_battle()
	assert_eq(mine[0].stage("atk"), 0)

func test_mirror_stance_copies_the_foes_stages() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Puddlet", 20, ["Mirror Stance"]), _one("Mossling"))
	m.change_stage(1, "atk", 2)
	m.change_stage(1, "spd", -1)
	m.change_stage(0, "def", 1)
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var me: Spirling = m.active_spirling(0)
	assert_eq([me.stage("atk"), me.stage("def"), me.stage("spd")], [2, 0, -1])
	assert_eq(m.active_spirling(1).stage("atk"), 2, "the foe keeps its own")

func test_crosswind_trade_swaps_all_stages() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Puddlet", 20, ["Crosswind Trade"]), _one("Mossling"))
	m.change_stage(0, "def", -2)
	m.change_stage(1, "atk", 2)
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var me: Spirling = m.active_spirling(0)
	var foe: Spirling = m.active_spirling(1)
	assert_eq([me.stage("atk"), me.stage("def")], [2, 0])
	assert_eq([foe.stage("atk"), foe.stage("def")], [0, -2])

func test_copy_and_trade_fail_with_a_line_when_nothing_changes() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Puddlet", 20, ["Crosswind Trade"]), _one("Mossling"))
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_true(BattleFixtures.types_of(ev).has(T.STATUS_FAILED))

func test_stage_arts_count_as_stage_only_when_stages_are_locked() -> void:
	assert_true(BattleRules.stage_only(Database.move("Mirror Stance")))
	assert_true(BattleRules.stage_only(Database.move("Crosswind Trade")))

func test_a_boss_takes_lowered_stages_half() -> void:
	var s: Spirling = BattleFixtures.make("Smoldrake", 20)
	var plain: int = s.atk()
	s.stages["atk"] = -2
	var low: int = s.effective_atk()
	s.boss_guard = true
	var boss_low: int = s.effective_atk()
	assert_gt(boss_low, low, "a lowered boss keeps more Might")
	assert_almost_eq(float(boss_low), float(plain) * 4.0 / 6.0, 1.5)
	s.stages["atk"] = 2
	assert_eq(s.effective_atk(), int(plain * 2.0), "raised stages work in full")

func test_a_foe_at_plus_two_might_brings_a_warning() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Kindlop"), _one("Mossling"))
	m._events = []
	m.change_stage(1, "atk", 1)
	assert_false(m._events[-1].describe().contains("Careful"))
	m.change_stage(1, "atk", 1)
	assert_string_contains(m._events[-1].describe(), "Careful")
	m.change_stage(0, "atk", 2)
	assert_false(m._events[-1].describe().contains("Careful"), "only for the foe")

func test_keen_hit_numbers_stay_fixed() -> void:
	assert_almost_eq(DamageCalc.CRIT_CHANCE, 1.0 / 12.0, 0.000001)
	assert_almost_eq(DamageCalc.CRIT_MULT, 1.4, 0.000001)
	assert_string_contains(BattleGuide.page(2), "1 time in 12")

func test_one_value_formula_for_player_and_foe() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 30)
	var b: Spirling = BattleFixtures.make("Kindlop", 30)
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	assert_eq(m.active_spirling(0).atk(), m.active_spirling(1).atk())
	assert_eq(m.active_spirling(0).max_hp(), m.active_spirling(1).max_hp())

func test_value_calculator_matches_the_real_values() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 30)
	var lean: String = str(s.temperament().stat)
	for key: String in ["hp", "atk", "def", "foc", "spd"]:
		assert_eq(BattleGuide.calc(key, BattleGuide.base_of(s, key), s.level, int(s.spark.get(key, 0)), lean == key),
			BattleGuide.value(s, key), key)
	assert_string_contains(BattleGuide.page(3, s), "Kindlop")

func test_base_values_stay_in_bounds_and_rise_on_unfolding() -> void:
	var errors: PackedStringArray = []
	DataValidator._check_values(JSON.parse_string(FileAccess.get_file_as_string("res://data/spirlings.json")), errors)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var bad: Array = [
		{"name": "A", "base": {"hp": 50, "atk": 50, "def": 50, "foc": 50, "spd": 50}, "unfold": [{"to": "B"}]},
		{"name": "B", "base": {"hp": 50, "atk": 50, "def": 50, "foc": 50, "spd": 5}},
	]
	DataValidator._check_values(bad, errors)
	assert_eq(errors.size(), 2, "B is out of bounds and lower than A")

func test_guide_pages_exist_in_english_and_german() -> void:
	assert_eq(BattleGuide.titles().size(), BattleGuide.PAGES.size())
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for p: String in BattleGuide.PAGES:
		assert_false(str(de.get(p, "")).is_empty(), p)
	for i: int in BattleGuide.PAGES.size():
		assert_false(BattleGuide.page(i).is_empty())

func test_info_strip_reads_out_stages_with_their_factor() -> void:
	var strip := InfoStrip.new()
	strip.spirling_name = "Kindlop"
	strip.stages = {"atk": 2} as Dictionary[String, int]
	assert_string_contains(strip.screen_reader_text(), "Might +2: x2.00")
	strip.free()

func test_unfurl_preview_shows_every_value_before_and_after() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20)
	var lines: Array[String] = BattleGuide.unfold_preview(s, Database.species("Smoldrake"))
	assert_eq(lines.size(), 5)
	assert_string_contains(lines[1], "Might %d -> " % s.atk())
	assert_eq(s.data.species_name, "Kindlop", "the preview leaves the Spirling as it is")

func test_swap_hint_compares_with_the_one_in_front() -> void:
	var a: Spirling = BattleFixtures.make("Kindlop", 20)
	var b: Spirling = BattleFixtures.make("Kindlop", 25)
	var line: String = BattleGuide.compare_line(b, a)
	assert_string_contains(line, "MGT %d (%+d)" % [b.atk(), b.atk() - a.atk()])
	assert_string_contains(line, str(b.temperament().label))
	assert_false(BattleGuide.compare_line(a, a).contains("("), "no difference against itself")

func test_stage_sound_climbs_with_the_stage() -> void:
	assert_gt(BattleGuide.stage_pitch(2), BattleGuide.stage_pitch(1))
	assert_lt(BattleGuide.stage_pitch(-1), 1.0)
	assert_eq(BattleGuide.stage_pitch(9), BattleGuide.stage_pitch(3))

func test_growth_lost_to_the_ring_limit_says_so() -> void:
	var s: Spirling = BattleFixtures.make("Kindlop", 20)
	var m: BattleModel = BattleFixtures.model([s] as Array[Spirling], _one("Mossling"))
	m.level_cap = 20
	m._events = []
	m._give_xp(s, 500)
	var e: BattleEvent = BattleFixtures.first_of(m._events, T.XP_GAINED)
	assert_string_contains(e.describe(), "ring limit holds it at ring 20")
	m.level_cap = Spirling.LEVEL_SANITY
	m._events = []
	m._give_xp(s, 5)
	assert_false(BattleFixtures.first_of(m._events, T.XP_GAINED).describe().contains("ring limit"))
