extends GutTest
## docs/KAMPF_PLAN_1000.md, "Rift-Felder und Umgebung" (items 321 to 360): the two new fields,
## field energy and bond, the field gifts, the Field Stake, field conflicts, time of day, the
## badge, tint, music, lexicon, tower floors and wild spawns.

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func _one(species: String, level: int, moves: Array[String] = []) -> Array[Spirling]:
	var out: Array[Spirling] = [BattleFixtures.make(species, level, moves)]
	return out

func test_rubble_rain_and_gale_eye_boost_and_block() -> void:
	assert_eq(BattleRules.field_mult("rubble_rain", E.STONE), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("rubble_rain", E.VOLT), BattleRules.FIELD_WEAKEN)
	assert_eq(BattleRules.field_mult("gale_eye", E.GALE), BattleRules.FIELD_BOOST)
	assert_eq(BattleRules.field_mult("gale_eye", E.BLOOM), BattleRules.FIELD_WEAKEN)
	assert_true(BattleRules.field_blocks("rubble_rain", "jolt"))
	assert_true(BattleRules.field_blocks("gale_eye", "drowse"))
	assert_false(BattleRules.field_blocks("gale_eye", "jolt"))

func test_new_calls_lay_the_new_fields_and_are_learned() -> void:
	for pair: Array in [["Rubble Call", "rubble_rain", "Grindlet"], ["Gale Call", "gale_eye", "Vanepip"]]:
		var mv: MoveData = Database.move(str(pair[0]))
		assert_not_null(mv, str(pair[0]))
		assert_eq(StringName(mv.effects[0].id), &"set_field")
		assert_eq(str(mv.effects[0].field), str(pair[1]))
		var learned: bool = false
		for m2: MoveData in Database.species(str(pair[2])).learnset_moves:
			learned = learned or m2.move_name == str(pair[0])
		assert_true(learned, "%s learns %s" % [pair[2], pair[0]])

func test_gale_eye_keeps_everyone_awake() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Zephlet", 20, ["Gale Call"]), _one("Mossling", 20))
	m.start()
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field, "gale_eye")
	assert_false(m.apply_status(1, "drowse"))

func test_static_veil_gives_volt_spirlings_energy() -> void:
	var z: Spirling = BattleFixtures.make("Zippit", 20, ["Arc Bolt"])
	var k: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])
	assert_eq(RiftFields.energy_bonus("static_veil", z), 1)
	assert_eq(RiftFields.energy_bonus("static_veil", k), 0)
	assert_eq(RiftFields.energy_bonus("ash_storm", z), 0)
	var gains: Array[int] = []
	for f: String in ["", "static_veil"]:
		var m: BattleModel = BattleFixtures.model([z] as Array[Spirling], [k] as Array[Spirling])
		m.field = f
		m.start()
		z.energy = 0
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
		gains.append(z.energy)
	assert_eq(gains[1], gains[0] + 1)

func test_dawn_glow_helps_a_bond() -> void:
	assert_almost_eq(float(BattleRules.FIELDS.dawn_glow.get("bond_bonus", 0.0)), 0.05, 0.0001)
	var bonded: Array[int] = [0, 0]
	for i: int in 2:
		for sd: int in 300:
			var m: BattleModel = BattleFixtures.model(_one("Kindlop", 30, ["Bowl Over"]), _one("Mossling", 5), true, sd)
			m.field = "dawn_glow" if i == 1 else ""
			m.start()
			var a: BattleAction = BattleAction.make_bond(0, 0.5)
			var ev: Array[BattleEvent] = m.submit_turn(a, BattleAction.make_rest(1))
			var r: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.BOND_RESULT)
			if r != null and bool(r.data.get("success", false)):
				bonded[i] += 1
	assert_gt(bonded[1], bonded[0], "same seeds, more bonds under Dawn Glow")

func test_a_new_field_pushes_the_old_one_out_with_a_line() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Smoldrake", 30, ["Ash Call"]), _one("Mossling", 30, ["Bowl Over"]))
	m.field = "deep_murk"
	m.start()
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var gone: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.FIELD_END)
	assert_not_null(gone)
	assert_eq(gone.describe(), "The Deep Murk gives way to the Ash Storm.")
	assert_eq(m.field, "ash_storm", "the art wins over the place")
	for i: int in BattleRules.RESONANCE_TURNS:
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	assert_eq(m.field, "deep_murk", "then the place's own field comes back")

func test_field_length_is_the_same_on_every_difficulty() -> void:
	var lengths: Array[int] = []
	for d: int in 4:
		var m: BattleModel = BattleFixtures.model(_one("Smoldrake", 30, ["Ash Call"]), _one("Mossling", 30, ["Bowl Over"]))
		m.boss_difficulty = d
		m.ai.set_difficulty(d)
		m.start()
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
		lengths.append(m.field_turns)
	assert_eq(lengths, [4, 4, 4, 4] as Array[int])

func test_field_stake_stretches_the_holders_field() -> void:
	assert_true(BattleRules.is_holdable("field_stake"))
	var s: Spirling = BattleFixtures.make("Smoldrake", 30, ["Ash Call"])
	s.held = "field_stake"
	var m: BattleModel = BattleFixtures.model([s] as Array[Spirling], _one("Mossling", 30, ["Bowl Over"]))
	m.start()
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field_turns, BattleRules.RESONANCE_TURNS + 2 - 1)

func test_field_strider_ignores_the_weakening() -> void:
	var mv: MoveData = Database.move("Pebble Toss")
	var g: Spirling = BattleFixtures.make("Grindlet", 20)
	var t: Spirling = BattleFixtures.make("Kindlop", 20)
	assert_eq(g.gift_id(), "field_strider")
	assert_eq(BattleRules.damage_mult(g, t, mv, "static_veil"), 1.0)
	assert_eq(BattleRules.damage_mult(t, g, mv, "static_veil"), BattleRules.FIELD_WEAKEN)
	assert_eq(BattleRules.damage_mult(g, t, mv, "rubble_rain"), BattleRules.FIELD_BOOST, "the boost stays")

func test_echo_soul_gains_energy_when_a_field_is_laid() -> void:
	var v: Spirling = BattleFixtures.make("Vanepip", 30, ["Gale Call"])
	assert_eq(v.gift_id(), "echo_soul")
	var m: BattleModel = BattleFixtures.model([v] as Array[Spirling], _one("Mossling", 30, ["Bowl Over"]))
	m.start()
	v.energy = 5
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_not_null(BattleFixtures.first_of(ev, BattleEvent.Type.TRAIT))
	# 5 - 3 for the call + 2 from the gift + the turn's own Energy.
	assert_eq(v.energy, 5 - 3 + 2 + BattleModel.ENERGY_PER_TURN)

func test_time_of_day_holds_a_field_longer() -> void:
	assert_eq(RiftFields.daytime_turns("dawn_glow", DayCycle.Phase.DAWN), 1)
	assert_eq(RiftFields.daytime_turns("dawn_glow", DayCycle.Phase.NIGHT), 0)
	assert_eq(RiftFields.daytime_turns("deep_murk", DayCycle.Phase.NIGHT), 1)
	assert_eq(RiftFields.daytime_turns("deep_murk", -1), 0)
	var m: BattleModel = BattleFixtures.model(_one("Glimmerax", 30, ["Dawn Call"]), _one("Mossling", 30, ["Bowl Over"]))
	m.day_phase = DayCycle.Phase.DAY
	m.start()
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.field, "dawn_glow")
	assert_eq(m.field_turns, BattleRules.RESONANCE_TURNS + 1 - 1)

func test_badge_text_and_screen_reader_line() -> void:
	assert_eq(RiftFields.badge_text("ash_storm", 3), "Ash Storm 3")
	assert_eq(RiftFields.badge_text("ash_storm", 0), "Ash Storm")
	assert_eq(RiftFields.badge_text("", 3), "")
	assert_eq(RiftFields.spoken("high_tide", 2), "Rift field High Tide, 2 turns left.")
	assert_eq(RiftFields.spoken("high_tide", 0), "Rift field High Tide, for the whole battle.")

func test_badge_follows_the_field_events() -> void:
	var b := FieldBadge.new()
	add_child_autofree(b)
	autofree(b.tint_rect)
	b.on_event(BattleEvent.new(BattleEvent.Type.FIELD, {"field": "pollen_drift", "turns": 5}))
	assert_true(b.visible)
	assert_eq(b.turns, 5)
	assert_string_contains(b.accessibility_name, "Pollen Drift")
	b.on_event(BattleEvent.new(BattleEvent.Type.FIELD_EXTENDED, {"field": "pollen_drift", "turns": 2}))
	assert_eq(b.turns, 7)
	b.on_event(BattleEvent.new(BattleEvent.Type.FIELD_END, {"field": "pollen_drift"}))
	assert_false(b.visible)
	assert_eq(b.tint_rect.color.a, 0.0)

func test_every_field_has_a_tint_pitch_and_lexicon_entry() -> void:
	for id: String in BattleRules.FIELDS:
		for era: int in range(1, 6):
			assert_gt(RiftFields.tint(id, era).a, 0.0, "%s era %d" % [id, era])
		assert_true(RiftFields.data().get("music_pitch", {}).has(id), id)
		assert_true(Lexicon.has_entry(RiftFields.lexicon_id(id)), id)
	# Era I is a four-ink handheld: every field gets the same ink there.
	assert_eq(RiftFields.tint("ash_storm", 1).to_html(false), RiftFields.tint("high_tide", 1).to_html(false))
	assert_ne(RiftFields.tint("ash_storm", 3).to_html(false), RiftFields.tint("high_tide", 3).to_html(false))
	assert_eq(RiftFields.tint("", 3).a, 0.0)

func test_lexicon_entry_states_the_real_numbers() -> void:
	var t: String = Lexicon.text(RiftFields.LEXICON_RULES)
	assert_string_contains(t, "x%s" % str(BattleRules.FIELD_BOOST))
	assert_string_contains(t, "x%s" % str(BattleRules.FIELD_WEAKEN))
	assert_string_contains(t, "%d turns" % BattleRules.RESONANCE_TURNS)
	var rec: Dictionary = {}
	assert_true(RiftFields.note_seen(rec, "gale_eye"))
	assert_false(RiftFields.note_seen(rec, "gale_eye"), "only once")
	assert_true((rec.lexicon as Array).has("field_gale_eye"))
	assert_true((rec.lexicon as Array).has(RiftFields.LEXICON_RULES))

func test_tower_floors_get_a_steady_field() -> void:
	var seen: Dictionary = {}
	for f: int in range(1, 60):
		var id: String = RiftFields.tower_field(4242, f)
		assert_eq(id, RiftFields.tower_field(4242, f), "same climb, same field")
		if f < int(RiftFields.data().tower.from_floor):
			assert_eq(id, "")
		if not id.is_empty():
			assert_true(BattleRules.FIELDS.has(id))
			seen[id] = true
	assert_gt(seen.size(), 3, "floors mix their fields")

func test_map_field_draws_out_its_element() -> void:
	assert_eq(RiftFields.spawn_boost("high_tide"), [E.TIDE] as Array[int])
	assert_true(RiftFields.spawn_boost("").is_empty())

func test_replay_keeps_the_place_field() -> void:
	var m: BattleModel = BattleFixtures.model(_one("Smoldrake", 30, ["Ash Call"]), _one("Mossling", 30, ["Bowl Over"]))
	m.field = "rubble_rain"
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "field")
	assert_eq(str(snap.get("field", "")), "rubble_rain")
	assert_eq(BattleReplay.build_model(snap).field, "rubble_rain")

func test_field_extras_pass_the_data_check() -> void:
	assert_eq(KampfChecks.field_errors(), PackedStringArray(), "energy_element, energy_gain and bond_bonus are known keys")
	var bad: Dictionary = {"x": {"label": "X", "intro": "x", "energy_element": "NOPE", "bond_bonus": 0.9}}
	var errs: PackedStringArray = KampfChecks.field_errors(bad)
	assert_eq(errs.size(), 2, "a wrong element and a too big bond bonus are caught")
