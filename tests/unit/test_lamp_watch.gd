extends GutTest
## Update "The Lamp Watch" (docs/WORLD.md, data/lamp_watch.json, scripts/core/LampWatch.gd):
## once a day the lighthouse lamp, seven fixed nights with Mirela's lamp log, then a pool;
## visitors are Veydal base forms in the Act I stat range, the Echo call decides, no fight.

const LANGS: Array[String] = ["de", "fr", "es", "it", "pt_BR", "nl", "pl", "tr", "ru", "ja", "ko", "zh_CN", "zh_TW"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_locked_until_aldo_gift() -> void:
	assert_false(LampWatch.unlocked(GameState.flags))
	GameState.set_flag("aldo_gift")
	assert_true(LampWatch.unlocked(GameState.flags))

func test_once_per_day_and_clock_back_gives_nothing() -> void:
	var r: Dictionary = {}
	var f: Dictionary = {}
	assert_true(LampWatch.can_light(r, "2026-11-23"))
	assert_false(LampWatch.light(r, f, "Kindlop", "2026-11-23").is_empty())
	assert_true(LampWatch.light(r, f, "Kindlop", "2026-11-23").is_empty(), "same day")
	assert_true(LampWatch.light(r, f, "Kindlop", "2026-11-22").is_empty(), "clock turned back")
	assert_eq(LampWatch.nights_lit(r), 1)
	assert_false(LampWatch.light(r, f, "Kindlop", "2026-11-30").is_empty(), "a missed week costs nothing")
	assert_eq(LampWatch.nights_lit(r), 2, "only lit nights count, no streak")

func test_first_two_nights_bring_the_other_storm_spirlings() -> void:
	for starter: String in ["Kindlop", "Zippit", "Wickit"]:
		var a: String = str(LampWatch.night(1, starter, "d").species)
		var b: String = str(LampWatch.night(2, starter, "d").species)
		assert_ne(a, starter)
		assert_ne(b, starter)
		assert_ne(a, b)
		assert_true(a in ["Kindlop", "Zippit", "Wickit"] and b in ["Kindlop", "Zippit", "Wickit"])

func test_seven_nights_set_flags_log_and_end_with_a_gleam() -> void:
	var r: Dictionary = {}
	var f: Dictionary = {}
	var last: Dictionary = {}
	for i: int in 7:
		last = LampWatch.light(r, f, "Zippit", "2026-12-%02d" % (i + 1))
		assert_true(bool(f.get(LampWatch.NIGHT_FLAG % (i + 1), false)))
		assert_eq((last.log as Array).size(), 2, "a lamp log page every fixed night")
	assert_true(bool(f.get(LampWatch.DONE_FLAG, false)))
	assert_true(bool(last.gleam))
	assert_eq(str(last.gift[0]), "lamp_lens")
	assert_eq(LampWatch.log_pages(r).size(), 7)
	var after: Dictionary = LampWatch.light(r, f, "Zippit", "2026-12-09")
	assert_true((after.log as Array).is_empty(), "the pool brings no more log pages")
	assert_true(str(after.species) in (LampWatch.data().pool as Array))

func test_quest_side_goal_uses_the_night_flags() -> void:
	var goal: Dictionary = {}
	for g: Variant in QuestLog.data().get("side", []):
		if str((g as Dictionary).get("id", "")) == "lamp":
			goal = g
	assert_false(goal.is_empty())
	assert_eq(str(goal.done), LampWatch.DONE_FLAG)
	assert_eq((goal.progress as Array).size(), LampWatch.fixed_nights())
	for i: int in LampWatch.fixed_nights():
		assert_eq(str(goal.progress[i]), LampWatch.NIGHT_FLAG % (i + 1))

func test_visitors_are_veydal_base_forms_in_the_act_one_range() -> void:
	var kinds: Array[String] = ["Kindlop", "Zippit", "Wickit"]
	for n: Variant in LampWatch.nights():
		var v: String = str((n as Dictionary).visitor)
		if not v.begins_with("@"):
			kinds.append(v)
	for p: Variant in LampWatch.data().pool:
		kinds.append(str(p))
	var base_forms: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		for u: Variant in sd.unfold:
			base_forms[str((u as Dictionary).get("to", ""))] = true
	for k: String in kinds:
		var sd: SpirlingData = Database.species(k)
		assert_not_null(sd, k)
		if sd == null:
			continue
		assert_eq(sd.region, "veydal", k)
		assert_false(base_forms.has(k), "%s is a base form" % k)
		var total: int = sd.base_hp + sd.base_atk + sd.base_def + sd.base_foc + sd.base_spd
		assert_between(total, 280, 330, "%s base total in the Act I starter range" % k)

func test_visitor_ring_follows_the_team() -> void:
	var team: Array[Spirling] = []
	assert_eq(LampWatch.visitor_ring(team), 3, "never under Ring 3")
	team.append(Spirling.new(Database.species("Kindlop"), 5, GameState.rng))
	assert_eq(LampWatch.visitor_ring(team), 4)
	team.append(Spirling.new(Database.species("Zippit"), 14, GameState.rng))
	assert_eq(LampWatch.visitor_ring(team), 13)
	var s: Spirling = LampWatch.make_visitor(LampWatch.night(3, "Kindlop", "d"), team, GameState.rng)
	assert_eq(s.level, 13)
	assert_eq(s.display_name(), "Button")
	assert_false(s.gleam)

func test_waiting_visitor_until_answered() -> void:
	var r: Dictionary = {}
	LampWatch.light(r, {}, "Kindlop", "2026-11-23")
	assert_true(LampWatch.visitor_waiting(r, "2026-11-23"))
	LampWatch.answer(r, "2026-11-23")
	assert_false(LampWatch.visitor_waiting(r, "2026-11-23"))
	assert_false(LampWatch.visitor_waiting(r, "2026-11-24"), "not lit yet that day")

func test_start_hint_once_per_day_only_when_dark() -> void:
	var r: Dictionary = {}
	var f: Dictionary = {}
	assert_eq(LampWatch.start_hint(f, r, "2026-11-23"), "", "locked")
	f["aldo_gift"] = true
	assert_ne(LampWatch.start_hint(f, r, "2026-11-23"), "")
	assert_eq(LampWatch.start_hint(f, r, "2026-11-23"), "", "once a day")
	LampWatch.light(r, f, "Kindlop", "2026-11-24")
	assert_eq(LampWatch.start_hint(f, r, "2026-11-24"), "", "lit already")
	assert_ne(LampWatch.start_hint(f, r, "2026-11-25"), "")

func test_gifts_and_lamp_lens_exist() -> void:
	for n: Variant in LampWatch.nights():
		var g: Array = (n as Dictionary).gift
		assert_false(Database.item(str(g[0])).is_empty(), str(g[0]))
	for g: Variant in LampWatch.data().pool_gifts:
		assert_false(Database.item(str((g as Array)[0])).is_empty())
	var lens: Dictionary = Database.item("lamp_lens")
	assert_almost_eq(float((lens.held as Dictionary).get("bond_bonus", 0.0)), 0.05, 0.001)

func test_lamp_strips_exist_for_every_count() -> void:
	for n: int in LampWatch.fixed_nights() + 1:
		assert_true(ResourceLoader.exists("res://art/era1/fx/lamp_watch_%d.png" % n), str(n))

func test_every_text_is_translated_in_all_languages() -> void:
	var keys: Array[String] = ["Lamp Watch", "The lamp room", "Light the lamp", "Answer the call", "Mirela's lamp log",
		"Climb to the lamp", "Lamp Lens", "Nights lit: %d", "Mirela's lamp log: %d/%d pages"]
	for n: Variant in LampWatch.nights():
		for l: Variant in (n as Dictionary).lines:
			keys.append(str(l))
		for l: Variant in (n as Dictionary).log:
			keys.append(str(l))
	for l: Variant in LampWatch.data().pool_lines:
		keys.append(str(l))
	for lang: String in LANGS:
		var f := FileAccess.open("res://data/i18n/%s/c100_update.json" % lang, FileAccess.READ)
		assert_not_null(f, lang)
		if f == null:
			continue
		var strings: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary).strings
		for k: String in keys:
			assert_true(strings.has(k) and str(strings[k]) != "" and str(strings[k]) != k, "%s: %s" % [lang, k])

func test_choice_fits_one_line() -> void:
	assert_true("Climb to the lamp".length() <= 18, "STORY.md: answers at most 18 characters")
