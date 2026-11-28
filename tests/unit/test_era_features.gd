extends GutTest
## Era functions (data/era_functions.json, EraFeatures): the data, the gate per era, the lists
## for the era change and the Records page, weather in battle and ring-scaled Growth.

var _unlocked: int

func before_each() -> void:
	_unlocked = EraManager.unlocked_era

func after_each() -> void:
	EraManager.unlocked_era = _unlocked

func test_data_is_valid() -> void:
	assert_eq(EraFeatures.validate(), [] as Array[String])
	assert_gt(EraFeatures.features().size(), 20)

func test_every_later_era_brings_something() -> void:
	for e: int in range(2, 6):
		assert_false(EraFeatures.new_in(e).is_empty(), "era %d lists new functions" % e)
	assert_true(EraFeatures.new_in(1).is_empty(), "Era I has only base functions")

func test_every_step_is_covered() -> void:
	var steps: Dictionary = {}
	for f: Dictionary in EraFeatures.features():
		steps[int(f.step)] = true
	for s: int in range(1, 6):
		assert_true(steps.has(s), "generation step %d" % s)

func test_gate_follows_era() -> void:
	assert_true(EraFeatures.is_unlocked("keepsakes", 1), "base functions stay open in Era I")
	assert_false(EraFeatures.is_unlocked("sky_battles", 2))
	assert_true(EraFeatures.is_unlocked("sky_battles", 3))
	assert_true(EraFeatures.is_unlocked("sky_battles", 5))
	assert_false(EraFeatures.is_unlocked("ring_scaled_growth", 4))
	assert_true(EraFeatures.is_unlocked("ring_scaled_growth", 5))
	assert_false(EraFeatures.is_unlocked("no_such_function", 5), "unknown ids stay shut")

func test_gate_reads_the_save_era() -> void:
	EraManager.unlocked_era = 2
	assert_false(EraFeatures.is_unlocked("sky_battles"))
	EraManager.unlocked_era = 3
	assert_true(EraFeatures.is_unlocked("sky_battles"))

func test_base_functions_are_never_gated() -> void:
	for f: Dictionary in EraFeatures.features():
		if str(f.kind) == "base":
			assert_true(EraFeatures.is_unlocked(str(f.id), 1), str(f.id))

func test_lines_for_era_change_and_page() -> void:
	var lines: Array[String] = EraFeatures.new_in_lines(3)
	assert_eq(lines.size(), EraFeatures.new_in(3).size())
	assert_string_contains(lines[0], "New in Era III: ")
	assert_eq(EraFeatures.era_titles(3).size(), 3)
	var page: Array[String] = EraFeatures.page_lines(4)
	assert_true(page.any(func(l: String) -> bool: return l.contains("(upgraded)")))

func test_open_in_grows_with_era() -> void:
	var prev: int = 0
	for e: int in range(1, 6):
		var n: int = EraFeatures.open_in(e).size()
		assert_gt(n, prev, "era %d opens more" % e)
		prev = n
	assert_eq(prev, EraFeatures.features().size())

func test_every_text_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	for f: Dictionary in EraFeatures.features():
		assert_true(de.has(str(f.name)), "German name for %s" % f.id)
		assert_true(de.has(str(f.text)), "German text for %s" % f.id)
	assert_true(de.has("New in Era %s: %s. %s"))
	for kind: String in ["rain", "fog", "storm"]:
		assert_true(de.has(str(WeatherCycle.battle_field(kind).intro)), "German intro for %s" % kind)

func test_weather_lays_a_battle_field() -> void:
	assert_eq(str(WeatherCycle.battle_field("rain").field), "high_tide")
	assert_eq(str(WeatherCycle.battle_field("fog").field), "deep_murk")
	assert_eq(str(WeatherCycle.battle_field("storm").field), "static_veil")
	assert_true(WeatherCycle.battle_field("clear").is_empty())
	assert_true(WeatherCycle.battle_field("wind").is_empty())

func _mon(lvl: int) -> Spirling:
	return Spirling.new(Database.species("Mossling"), lvl)

func test_sky_intro_replaces_rift_line() -> void:
	var m := BattleModel.new([_mon(10)] as Array[Spirling], [_mon(10)] as Array[Spirling], true, 7)
	var sky: Dictionary = WeatherCycle.battle_field("rain")
	m.field = str(sky.field)
	m.field_intro = str(sky.intro)
	var texts: Array[String] = []
	for ev: BattleEvent in m.start():
		if ev.type == BattleEvent.Type.FIELD:
			texts.append(str(ev.data.text))
	assert_eq(texts, [str(sky.intro)] as Array[String])
	assert_eq(m.field, "high_tide")

func test_growth_scale_curve() -> void:
	assert_almost_eq(BattleModel.growth_scale(30, 30), 1.0, 0.0001, "an even fight is unchanged")
	assert_gt(BattleModel.growth_scale(40, 20), 1.0, "a stronger foe gives more")
	assert_lt(BattleModel.growth_scale(20, 40), 1.0, "a weaker foe gives less")
	assert_eq(BattleModel.growth_scale(95, 1), BattleModel.GROWTH_SCALE_MAX)
	assert_eq(BattleModel.growth_scale(2, 99), BattleModel.GROWTH_SCALE_MIN)

func _growth(scaled: bool, own: int, foe: int) -> int:
	var me: Spirling = _mon(own)
	var m := BattleModel.new([me] as Array[Spirling], [_mon(foe)] as Array[Spirling], true, 11)
	m.ring_scaled_growth = scaled
	m.start()
	m.parties[1][0].hp = 0
	m.participants = [me] as Array[Spirling]
	var got: Array[int] = [0]
	m.event_emitted.connect(func(ev: BattleEvent) -> void:
		if ev.type == BattleEvent.Type.XP_GAINED:
			got[0] += int(ev.data.amount))
	m._award_xp(m.parties[1][0])
	return got[0]

func test_ring_scaled_growth_only_when_on() -> void:
	var plain: int = _growth(false, 10, 30)
	var scaled: int = _growth(true, 10, 30)
	assert_gt(scaled, plain, "a low Spirling beating a higher foe learns more in Era V")
	assert_eq(_growth(true, 30, 30), _growth(false, 30, 30), "even rings stay the same")
	assert_lt(_growth(true, 50, 20), _growth(false, 50, 20), "beating a weak foe teaches less")

func test_era_five_roads_have_triple_battles() -> void:
	var found: int = 0
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		if not raw is Dictionary or str(raw.get("region", "")) != "quivermoor":
			continue
		for n: Variant in (raw as Dictionary).get("npcs", []):
			var front: Variant = (n as Dictionary).get("front", [1, 1])
			if front is Array and int(front[1]) >= 3:
				found += 1
				assert_gte((n.get("team", []) as Array).size(), 3, "%s %s brings three" % [f, n.get("id", "")])
	assert_gte(found, 6, "one triple battle per Quivermoor road")
