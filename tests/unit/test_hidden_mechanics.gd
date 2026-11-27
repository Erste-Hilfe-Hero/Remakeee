extends GutTest
## Hidden mechanics of 1.3.2 (data/hidden_mechanics.json, docs/HIDDEN_MECHANICS.md): secret unfold
## paths, rare spawns, hidden spots, the Star Well knack, dated easter eggs, two secret badges, and
## the hidden battle touches that must stay deterministic for replays and the referee.

const WHEN_KEYS: Array[String] = ["phase", "weather", "moon", "weekday", "date", "chain", "ring", "held", "kinship", "knows", "map", "lead_element"]

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _berlin_noon(y: int, m: int, d: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 11}))

func _ctx(extra: Dictionary) -> Dictionary:
	var c: Dictionary = {"phase": "day", "weather": "clear", "moon": "", "weekday": 3, "date": "06-10", "chain": 0, "map": "", "lead": null}
	c.merge(extra, true)
	return c

func _all_when() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d: Dictionary = HiddenMechanics.data()
	for k: String in ["unfolds", "spawns", "spots"]:
		for e: Dictionary in d.get(k, []):
			out.append(e.get("when", {}))
	return out

# --- Data ----------------------------------------------------------------------------------

func test_about_25_mechanics_over_every_region() -> void:
	var d: Dictionary = HiddenMechanics.data()
	var n: int = (d.unfolds as Array).size() + (d.spawns as Array).size() + (d.spots as Array).size() \
		+ (d.battle.combos as Array).size() + (d.battle.skies as Array).size() + (d.battle.keen as Array).size() + (d.dates as Array).size() + 1
	assert_gte(n, 25)
	var regions: Dictionary = {}
	for k: String in ["unfolds", "spawns", "spots"]:
		for e: Dictionary in d[k]:
			regions[str(e.region)] = true
	for r: String in ["veydal", "corvane", "ashmere", "vellmarch", "halcyra", "solenne", "quivermoor", "quillmarch"]:
		assert_true(regions.has(r), "something hidden in " + r)

func test_ids_are_unique() -> void:
	var seen: Dictionary = {}
	var d: Dictionary = HiddenMechanics.data()
	for k: String in ["unfolds", "spawns", "spots", "dates"]:
		for e: Dictionary in d[k]:
			assert_false(seen.has(str(e.id)), "duplicate id " + str(e.id))
			seen[str(e.id)] = true

func test_every_when_key_is_known() -> void:
	for w: Dictionary in _all_when():
		for k: String in w:
			assert_true(k in WHEN_KEYS, "unknown when key " + k)

func test_secret_unfolds_lead_to_a_normal_target() -> void:
	for u: Dictionary in HiddenMechanics.data().unfolds:
		var from: SpirlingData = Database.species(str(u.from))
		assert_not_null(from, str(u.from))
		var targets: Array[String] = []
		for p: Dictionary in from.unfold:
			targets.append((p.to as SpirlingData).species_name)
		assert_true(str(u.to) in targets, "%s -> %s is a normal unfold too (Furl back works)" % [u.from, u.to])
		if (u.when as Dictionary).has("knows"):
			assert_not_null(Database.move(str(u.when.knows)), str(u.when.knows))
		if (u.when as Dictionary).has("held"):
			assert_false(Database.item(str(u.when.held)).is_empty(), str(u.when.held))
		if (u.when as Dictionary).has("map"):
			assert_true(MapData.exists(str(u.when.map)), str(u.when.map))

func test_spawns_use_existing_maps_tables_and_species() -> void:
	for sp: Dictionary in HiddenMechanics.data().spawns:
		assert_true(MapData.exists(str(sp.map)), str(sp.map))
		var m: MapData = MapData.load_map(str(sp.map))
		assert_false(m.encounter_table.is_empty(), str(sp.map) + " has wild Spirlings")
		assert_true(m.outdoor, str(sp.map) + " is outdoors (sky and moon)")
		assert_not_null(Database.species(str(sp.species)), str(sp.species))
		assert_between(float(sp.chance), 0.01, 0.5)
		assert_false((sp.when as Dictionary).is_empty(), str(sp.id) + " needs a condition")
		var rings: Vector2i = HiddenMechanics.spawn_rings(sp, m.encounter_table)
		assert_true(rings.x >= 1 and rings.x <= rings.y, str(sp.id))

func test_spots_sit_on_the_right_cells() -> void:
	for p: Dictionary in HiddenMechanics.data().spots:
		assert_true(MapData.exists(str(p.map)), str(p.map))
		var m: MapData = MapData.load_map(str(p.map))
		var cell := Vector2i(int(p.x), int(p.y))
		match str(p.get("at", "tile")):
			"sign":
				assert_false(m.sign_at(cell, {}).is_empty(), str(p.id) + " sits on a sign")
				assert_false(str(p.get("code", "")).is_empty(), str(p.id) + " sign spots wait for a word")
			"landmark":
				assert_false(Landmarks.lines_at(m.id, cell).is_empty(), str(p.id) + " sits on a landmark")
			"tile":
				assert_false(m.is_walkable(cell), str(p.id) + " is a solid cell")
				assert_true(m.sign_at(cell, {}).is_empty() and m.secret_at(cell, {}).is_empty() and Landmarks.lines_at(m.id, cell).is_empty(), str(p.id) + " nothing else answers")
				for n: Dictionary in m.npcs:
					assert_false(int(n.x) == cell.x and int(n.y) == cell.y, str(p.id) + " no NPC")
			_:
				fail_test("unknown at " + str(p.at))
		var reach: bool = false
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			reach = reach or m.is_walkable(cell + dir)
		assert_true(reach, str(p.id) + " can be faced from a walkable cell")
		if p.has("item"):
			var item: String = str(p.item)
			assert_false(Database.item(item).is_empty(), item)
			assert_false(item.begins_with("rg_"), "no Riftglass shop items as finds")
			assert_false(bool(Database.item(item).get("premium", false)) or bool(Database.item(item).get("shop_only", false)), item + " is no shop good")

func test_code_words_have_a_clue_elsewhere() -> void:
	for p: Dictionary in HiddenMechanics.data().spots:
		if not p.has("code"):
			continue
		var found: bool = false
		for q: Dictionary in HiddenMechanics.data().spots:
			if q != p:
				for l: Variant in q.get("lines", []):
					found = found or str(l).contains(str(p.code))
		assert_true(found, "a clue names " + str(p.code))

func test_battle_entries_use_real_arts_fields_and_elements() -> void:
	var b: Dictionary = HiddenBattle.data()
	for c: Dictionary in b.combos:
		assert_not_null(Database.move(str(c.first)), str(c.first))
		assert_not_null(Database.move(str(c.then)), str(c.then))
		assert_true(Database.move(str(c.then)).is_damaging(), str(c.then) + " deals damage")
		assert_between(float(c.mult), 1.0, 1.5)
		assert_eq(str(c.text).count("%s"), 1)
	for s: Dictionary in b.skies:
		assert_true(BattleRules.FIELDS.has(str(s.field)), str(s.field))
		assert_true(Elements.E.has(str(s.element)), str(s.element))
		assert_between(float(s.mult), 1.0, 1.5)
	for k: Dictionary in b.keen:
		assert_true(str(k.rule) in ["low_vigor", "underdog"], str(k.rule))
		assert_between(float(k.crit_mult), 1.0, 3.0)

func test_two_secret_badges() -> void:
	for id: String in ["hidden_keeper", "hidden_echo"]:
		var a: Dictionary = Achievements.find(id)
		assert_false(a.is_empty(), id)
		assert_true(bool(a.get("secret", false)), id + " is secret")
		assert_true(Achievements.is_hidden(a))

# --- Calendar ------------------------------------------------------------------------------

func test_moon_follows_the_berlin_calendar() -> void:
	assert_eq(HiddenMechanics.moon(HiddenMechanics.berlin_day(_berlin_noon(2025, 1, 13))), "full")
	assert_eq(HiddenMechanics.moon(HiddenMechanics.berlin_day(_berlin_noon(2026, 11, 24))), "full")
	assert_eq(HiddenMechanics.moon(HiddenMechanics.berlin_day(_berlin_noon(2025, 1, 29))), "new")
	assert_eq(HiddenMechanics.moon(HiddenMechanics.berlin_day(_berlin_noon(2026, 11, 27))), "")
	var fulls: int = 0
	var day0: int = HiddenMechanics.berlin_day(_berlin_noon(2026, 1, 1))
	for i: int in 365:
		fulls += 1 if HiddenMechanics.moon(day0 + i) == "full" else 0
	assert_between(fulls, 22, 28, "about two full-moon days a month")

func test_berlin_day_turns_at_berlin_midnight() -> void:
	# 23:30 UTC on 31 Dec is already 1 Jan in Berlin.
	var u: int = int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 12, "day": 31, "hour": 23, "minute": 30}))
	assert_eq(HiddenMechanics.date_key(HiddenMechanics.berlin_day(u)), "01-01")
	assert_eq(HiddenMechanics.calendar(u).date, "01-01")

# --- Conditions ----------------------------------------------------------------------------

func test_met_checks_every_key() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 12, _rng(1))
	s.held = "bark_wrap"
	s.kinship = 50
	assert_true(HiddenMechanics.met({"phase": "night", "weather": "rain"}, _ctx({"phase": "night", "weather": "rain"})))
	assert_false(HiddenMechanics.met({"phase": "night"}, _ctx({"phase": "dusk"})))
	assert_true(HiddenMechanics.met({"chain": 5}, _ctx({"chain": 7})))
	assert_false(HiddenMechanics.met({"chain": 5}, _ctx({"chain": 4})))
	assert_true(HiddenMechanics.met({"weekday": 0}, _ctx({"weekday": 0})))
	assert_true(HiddenMechanics.met({"ring": 10, "held": "bark_wrap", "kinship": 40}, _ctx({}), s))
	assert_false(HiddenMechanics.met({"ring": 13}, _ctx({}), s))
	assert_false(HiddenMechanics.met({"ring": 1}, _ctx({})), "a Spirling key without a Spirling never holds")
	assert_true(HiddenMechanics.met({"knows": s.moves[0].move_name}, _ctx({}), s))
	assert_true(HiddenMechanics.met({"lead_element": "EMBER"}, _ctx({"lead": s})))
	assert_false(HiddenMechanics.met({"lead_element": "FROST"}, _ctx({"lead": s})))
	assert_false(HiddenMechanics.met({"typo": 1}, _ctx({})), "unknown keys never hold")

# --- Unfolds -------------------------------------------------------------------------------

func test_kindlop_unfurls_early_at_night_with_its_bark_wrap() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 10, _rng(2))
	var night: Dictionary = _ctx({"phase": "night"})
	assert_true(HiddenMechanics.unfold_targets(s, night).is_empty(), "no keepsake, no secret")
	s.held = "bark_wrap"
	var t: Array[SpirlingData] = HiddenMechanics.unfold_targets(s, night)
	assert_eq(t.size(), 1)
	assert_eq(t[0].species_name, "Smoldrake")
	assert_true(HiddenMechanics.unfold_targets(s, _ctx({"phase": "day"})).is_empty())
	# Spirling.unfurl_targets picks the secret path up too, and furling back still works.
	assert_true(Database.species("Smoldrake") in s.unfurl_targets("", night))
	s.evolve(Database.species("Smoldrake"))
	assert_eq(s.data.species_name, "Smoldrake")
	s.furl_back()
	assert_eq(s.data.species_name, "Kindlop")

func test_drizzlet_unfurls_in_rain_and_solkit_under_a_full_moon() -> void:
	var d := Spirling.new(Database.species("Drizzlet"), 5, _rng(3))
	assert_eq(HiddenMechanics.unfold_targets(d, _ctx({"weather": "rain"}))[0].species_name, "Rainmantle")
	assert_true(HiddenMechanics.unfold_targets(d, _ctx({"weather": "fog"})).is_empty())
	var k := Spirling.new(Database.species("Solkit"), 5, _rng(4))
	assert_eq(HiddenMechanics.unfold_targets(k, _ctx({"phase": "night", "moon": "full"}))[0].species_name, "Solmantle")
	assert_true(HiddenMechanics.unfold_targets(k, _ctx({"phase": "night", "moon": "new"})).is_empty())

func test_unfold_context_without_sky_gets_a_calm_one() -> void:
	var d := Spirling.new(Database.species("Drizzlet"), 5, _rng(5))
	# No map: the sky counts as clear, so the rain path stays closed.
	assert_true(HiddenMechanics.unfold_targets(d, {"map": "", "phase": "day"}).is_empty())

# --- Spawns --------------------------------------------------------------------------------

func test_spawns_only_under_their_sky_and_leave_the_rng_alone_otherwise() -> void:
	var sp: Dictionary = {}
	for e: Dictionary in HiddenMechanics.data().spawns:
		if str(e.id) == "s_rain_prism":
			sp = e
	var m: MapData = MapData.load_map(str(sp.map))
	var r := _rng(9)
	var before: int = r.state
	assert_true(HiddenMechanics.maybe_spawn(m.id, m.encounter_table, _ctx({"map": m.id, "weather": "clear"}), r).is_empty())
	assert_eq(r.state, before, "no draw when nothing can appear")
	var got: Dictionary = {}
	for i: int in 60:
		got = HiddenMechanics.maybe_spawn(m.id, m.encounter_table, _ctx({"map": m.id, "weather": "rain"}), _rng(i))
		if not got.is_empty():
			break
	assert_false(got.is_empty(), "rain brings it out sooner or later")
	assert_eq((got.wild as Spirling).data.species_name, "Prismist")
	var rings: Vector2i = HiddenMechanics.spawn_rings(sp, m.encounter_table)
	assert_between((got.wild as Spirling).level, rings.x, rings.y)
	# Same seed, same result (replays of the encounter).
	var a: Dictionary = HiddenMechanics.maybe_spawn(m.id, m.encounter_table, _ctx({"map": m.id, "weather": "rain"}), _rng(77))
	var b: Dictionary = HiddenMechanics.maybe_spawn(m.id, m.encounter_table, _ctx({"map": m.id, "weather": "rain"}), _rng(77))
	assert_eq(a.is_empty(), b.is_empty())

func test_chain_spawn_needs_a_long_chain() -> void:
	assert_true(HiddenMechanics.spawns_now("weeping_locks", _ctx({"map": "weeping_locks", "chain": 4})).is_empty())
	assert_eq(HiddenMechanics.spawns_now("weeping_locks", _ctx({"map": "weeping_locks", "chain": 5})).size(), 1)

# --- Spots ---------------------------------------------------------------------------------

func _spot(id: String) -> Dictionary:
	for p: Dictionary in HiddenMechanics.data().spots:
		if str(p.id) == id:
			return p
	return {}

func test_the_lone_oak_needs_three_knocks_and_gives_once() -> void:
	var p: Dictionary = _spot("p_lone_oak")
	assert_eq(HiddenMechanics.spot_at("gloamwood", Vector2i(int(p.x), int(p.y)), "tile"), p)
	var rec: Dictionary = {}
	var flags: Dictionary = {}
	var c: Dictionary = _ctx({"map": "gloamwood"})
	var r1: Dictionary = HiddenMechanics.tap(p, c, rec, flags)
	var r2: Dictionary = HiddenMechanics.tap(p, c, rec, flags)
	assert_true(str(r1.flag).is_empty() and str(r2.flag).is_empty(), "first two knocks only talk")
	assert_ne(r1.lines, r2.lines)
	var r3: Dictionary = HiddenMechanics.tap(p, c, rec, flags)
	assert_eq(str(r3.item), "kin_charm")
	assert_true(HiddenMechanics.grant(p, r3, flags, rec))
	assert_true(HiddenMechanics.spot_done(p, flags))
	assert_true(HiddenMechanics.is_found("p_lone_oak", rec))
	assert_eq(int(rec.hidden_found_n), 1)
	var r4: Dictionary = HiddenMechanics.tap(p, c, rec, flags)
	assert_true(str(r4.flag).is_empty(), "nothing more to take")
	assert_eq(r4.lines, p.after)

func test_weather_spot_stays_quiet_without_its_sky() -> void:
	var p: Dictionary = _spot("p_needle_fog")
	assert_true(HiddenMechanics.tap(p, _ctx({"weather": "clear"}), {}, {}).is_empty())
	assert_eq(str(HiddenMechanics.tap(p, _ctx({"weather": "fog"}), {}, {}).item), "swift_feather")

func test_sign_codes_take_the_word_from_the_clue() -> void:
	var p: Dictionary = _spot("p_quay_word")
	assert_true(bool(HiddenMechanics.tap(p, _ctx({}), {}, {}).code))
	assert_true(HiddenMechanics.code_ok(p, " lantern "))
	assert_true(HiddenMechanics.code_ok(p, "LAN TERN"))
	assert_false(HiddenMechanics.code_ok(p, "lamp"))
	assert_false(HiddenMechanics.code_ok(p, ""))
	var flags: Dictionary = {}
	var rec: Dictionary = {}
	assert_true(HiddenMechanics.grant(p, HiddenMechanics.code_result(p), flags, rec))
	assert_true(HiddenMechanics.tap(p, _ctx({}), rec, flags).is_empty(), "a solved sign is just a sign again")

func test_star_well_reads_every_knack_in_words() -> void:
	var a := Spirling.new(Database.species("Kindlop"), 5, _rng(1))
	a.uid = "abc"
	var b := Spirling.new(Database.species("Zippit"), 5, _rng(2))
	b.uid = "xyz"
	assert_eq(HiddenMechanics.knack(a), HiddenMechanics.knack(a), "fixed per Spirling")
	assert_true(HiddenMechanics.knack(a) in WeatherCycle.KINDS)
	var lines: Array[String] = HiddenMechanics.knack_lines([a, b])
	assert_eq(lines.size(), 2)
	assert_true(lines[0].begins_with(a.display_name()))
	var seen: Dictionary = {}
	for i: int in 50:
		var s := Spirling.new(Database.species("Kindlop"), 5, _rng(i))
		s.uid = "u%d" % i
		seen[HiddenMechanics.knack(s)] = true
	assert_eq(seen.size(), 5, "every sky is someone's favourite")

func test_knack_sky_gives_a_little_kinship_after_a_win() -> void:
	var s := Spirling.new(Database.species("Kindlop"), 5, _rng(1))
	s.uid = "knack-test"
	var sky: String = HiddenMechanics.knack(s)
	var other: String = "clear" if sky != "clear" else "rain"
	var k0: int = s.kinship
	assert_eq(HiddenMechanics.after_battle([s], other, true), 0)
	assert_eq(HiddenMechanics.after_battle([s], sky, false), 0)
	assert_eq(s.kinship, k0)
	assert_eq(HiddenMechanics.after_battle([s], sky, true), 1)
	assert_eq(s.kinship, k0 + 1)

# --- Dated easter eggs ---------------------------------------------------------------------

func test_dated_note_once_a_year() -> void:
	var rec: Dictionary = {}
	var solstice: int = _berlin_noon(2026, 12, 21)
	assert_ne(HiddenMechanics.start_note(rec, solstice), "")
	assert_eq(HiddenMechanics.start_note(rec, solstice), "", "once a year")
	assert_ne(HiddenMechanics.start_note(rec, _berlin_noon(2027, 12, 21)), "", "next year again")
	assert_eq(HiddenMechanics.start_note({}, _berlin_noon(2026, 6, 10)), "")
	assert_true(HiddenMechanics.is_found("d_long_night", rec))

func test_found_marks_survive_a_save() -> void:
	HiddenMechanics.note_found("p_lone_oak", GameState.records)
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	GameState.from_dict(d)
	assert_true(HiddenMechanics.is_found("p_lone_oak", GameState.records))
	assert_eq(int(GameState.records.get("hidden_found_n", 0)), 1)
	assert_eq(Achievements.stat("record:hidden_found_n"), 1)

# --- Battle --------------------------------------------------------------------------------

func _model(hidden: bool, field: String = "") -> BattleModel:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 20, _rng(1))]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 20, _rng(2))]
	var m := BattleModel.new(mine, foes, false, 4242, 1)
	m.hidden_rules = hidden
	m.field = field
	return m

func test_combo_needs_the_first_art_right_before() -> void:
	var m: BattleModel = _model(true)
	var me: Spirling = m.party(0)[0]
	var kindle: MoveData = Database.move("Kindle Up")
	var breath: MoveData = Database.move("Cinder Breath")
	HiddenBattle.note_move(m, me, breath)
	assert_true(HiddenBattle.combo(m, me, breath).is_empty())
	HiddenBattle.note_move(m, me, kindle)
	HiddenBattle.note_move(m, me, breath)
	assert_eq(str(HiddenBattle.combo(m, me, breath).id), "b_kindled_breath")
	assert_almost_eq(HiddenBattle.hit_mult(m, 0, 0, me, breath), 1.3, 0.001)
	var off: BattleModel = _model(false)
	HiddenBattle.note_move(off, off.party(0)[0], kindle)
	HiddenBattle.note_move(off, off.party(0)[0], breath)
	assert_eq(HiddenBattle.hit_mult(off, 0, 0, off.party(0)[0], breath), 1.0, "off outside world battles")

func test_sky_synergy_needs_its_field() -> void:
	var glint: MoveData = Database.move("Glint")
	assert_almost_eq(HiddenBattle.hit_mult(_model(true, "high_tide"), 0, 0, _model(true).party(0)[0], glint), 1.2, 0.001)
	assert_eq(HiddenBattle.hit_mult(_model(true, ""), 0, 0, _model(true).party(0)[0], glint), 1.0)
	assert_eq(HiddenBattle.hit_mult(_model(false, "high_tide"), 0, 0, _model(false).party(0)[0], glint), 1.0)

func test_keen_rules_raise_only_the_crit_chance() -> void:
	var m: BattleModel = _model(true)
	var me: Spirling = m.party(0)[0]
	var foe: Spirling = m.party(1)[0]
	assert_eq(HiddenBattle.crit_mult(m, me, foe), 1.0)
	me.hp = maxi(1, int(me.max_hp() * 0.2))
	assert_almost_eq(HiddenBattle.crit_mult(m, me, foe), 2.0, 0.001)
	me.hp = me.max_hp()
	var big := Spirling.new(Database.species("Mossling"), 35, _rng(3))
	assert_almost_eq(HiddenBattle.crit_mult(m, me, big), 2.0, 0.001)
	assert_eq(HiddenBattle.crit_mult(_model(false), me, big), 1.0)

func _play(hidden: bool, seed_value: int) -> Array:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 22, _rng(5)), Spirling.new(Database.species("Puddlet"), 20, _rng(6))]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 24, _rng(7)), Spirling.new(Database.species("Zippit"), 23, _rng(8))]
	var model := BattleModel.new(mine, foes, false, seed_value, 1)
	model.hidden_rules = hidden
	model.field = "high_tide"
	var snap: Dictionary = BattleReplay.snapshot(model, "battle", "field")
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 200:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var a: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
	return [JSON.parse_string(JSON.stringify(snap)), JSON.parse_string(JSON.stringify(BattleReferee.claim_of(model))), model]

func test_replay_carries_the_flag_and_the_referee_agrees() -> void:
	for seed_value: int in [11, 4242, 90210]:
		var b: Array = _play(true, seed_value)
		assert_true(bool((b[0] as Dictionary).get("hidden", false)))
		assert_true(BattleReplay.build_model(b[0]).hidden_rules)
		var r: Dictionary = BattleReferee.check(b[0], b[1])
		assert_eq(r.verdict, BattleReferee.OK, str(r))
	var plain: Array = _play(false, 11)
	assert_false((plain[0] as Dictionary).has("hidden"), "older replays stay the same")
	assert_eq(BattleReferee.check(plain[0], plain[1]).verdict, BattleReferee.OK)

func test_league_battles_never_use_hidden_touches() -> void:
	var snap: Dictionary = BattleReferee.from_expect({"seed": 5, "teams": [[{"species": "Kindlop", "level": 50, "moves": []}], [{"species": "Mossling", "level": 50, "moves": []}]]})
	assert_false(snap.has("hidden"))
	assert_false(BattleReplay.build_model(snap).hidden_rules)
