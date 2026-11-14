extends GutTest
## KAMPF_PLAN_1000 elements batch k25: neutral arts (89), matchups from lore pages (90), element
## symbols at the target pin (91), the later elements' fields per Rift (94), the matchup quiz in the
## lighthouse (99) and element dominance per region in the wild (102).

const E := Elements.E

var _known: Dictionary = {}
var _records: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Loc.set_language("en")
	_known = GameState.known_matchups.duplicate()
	_records = GameState.records.duplicate(true)

func after_each() -> void:
	GameState.known_matchups = _known
	GameState.records = _records

# --- 89 neutral arts ---------------------------------------------------------------------------

func test_neutral_arts_hit_every_element_the_same() -> void:
	for n: String in ["Plain Shove", "Old Grudge", "Scrap Swipe"]:
		var mv: MoveData = Database.move(n)
		assert_true(mv.neutral, n)
		assert_eq(mv.element_label(), "Neutral", n)
		for sp: String in ["Kindlop", "Puddlet", "Mossling", "Shalebat", "Zippit"]:
			assert_eq(DamageCalc.effectiveness(BattleFixtures.make(sp, 20), mv), 1.0, "%s into %s" % [n, sp])

func test_neutral_arts_get_no_own_element_bonus_field_or_reaction() -> void:
	var shove: MoveData = Database.move("Plain Shove")
	var stone: Spirling = BattleFixtures.make("Shalebat", 20)
	assert_true(shove.element in stone.elements(), "the look element is the user's own")
	assert_eq(DamageCalc.stab_for(stone, shove), 1.0)
	var target: Spirling = BattleFixtures.make("Zippit", 20)
	target.status = "jolt"
	assert_true(BattleRules.reaction(shove, target).is_empty(), "Stone would ground a Jolt, a neutral art does not")
	assert_almost_eq(BattleRules.damage_mult(stone, BattleFixtures.make("Mossling", 20), shove, "rubble_rain"),
		BattleRules.damage_mult(stone, BattleFixtures.make("Mossling", 20), shove, ""), 0.0001, "Rubble Rain leaves it alone")

func test_every_spirling_can_learn_the_neutral_arts() -> void:
	for id: String in ["echo_plain_shove", "echo_old_grudge", "echo_scrap_swipe"]:
		var it: Dictionary = Database.item(id)
		assert_false(it.is_empty(), id)
		assert_true(bool(it.get("any_element", false)), id)
		for sp: String in ["Kindlop", "Puddlet", "Zippit"]:
			assert_true(GameState.can_learn_echo(BattleFixtures.make(sp, 10, ["Bowl Over"]), id), "%s %s" % [sp, id])

func test_neutral_art_card_and_known_matchup() -> void:
	var mv: MoveData = Database.move("Old Grudge")
	assert_string_contains(CommandMenu.move_info(mv), "Neutral, ")
	assert_eq(GameState.known_art_multiplier(mv, BattleFixtures.make("Kindlop", 10)), 1.0, "always known: x1")

func test_a_neutral_hit_reports_no_matchup_element() -> void:
	var m: BattleModel = BattleFixtures.model([BattleFixtures.make("Kindlop", 20, ["Plain Shove"])] as Array[Spirling],
		[BattleFixtures.make("Puddlet", 20, ["Bowl Over"])] as Array[Spirling])
	var ev: Array[BattleEvent] = m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0), BattleAction.make_rest(BattleModel.Side.FOE))
	var used: BattleEvent = BattleFixtures.first_of(ev, BattleEvent.Type.MOVE_USED)
	assert_true(bool(used.data.get("neutral", false)))
	for e: BattleEvent in ev:
		if e.type == BattleEvent.Type.DAMAGE and e.data.has("eff"):
			assert_eq(float(e.data.eff), 1.0)

# --- 90 matchups from lore pages ---------------------------------------------------------------

func test_lore_page_lessons_come_from_the_chart() -> void:
	var l: Array[Dictionary] = Lexicon.lessons("warden_orrin")
	assert_eq(l.size(), 3)
	for row: Dictionary in l:
		assert_eq(int(row.element), E.TIDE)
		var sd: SpirlingData = Database.species(str(row.species))
		assert_eq(float(row.mult), Elements.multiplier(E.TIDE, sd.elements))
	assert_true(Lexicon.lessons("cartographers").is_empty())

func test_writing_a_lore_page_teaches_its_matchups() -> void:
	GameState.known_matchups = {}
	(GameState.records as Dictionary).erase("lexicon")
	assert_true(Lexicon.add(GameState.records, "warden_maelis"))
	assert_eq(float(GameState.known_matchups.get("%d:Riptail" % E.VOLT, -1.0)), 2.0)
	assert_eq(float(GameState.known_matchups.get("%d:Zephlet" % E.BLOOM, -1.0)), 0.5)
	var other: Dictionary = {}
	assert_true(Lexicon.add(other, "warden_orrin"))
	assert_false(GameState.known_matchups.has("%d:Kindlop" % E.TIDE), "a test record teaches nobody")
	assert_eq(Lexicon.teach_matchups(GameState.known_matchups, "warden_orrin"), 3)
	assert_eq(Lexicon.teach_matchups(GameState.known_matchups, "warden_orrin"), 0, "nothing new the second time")

func test_lore_page_names_what_it_teaches() -> void:
	var lines: Array[String] = Lexicon.lesson_lines("warden_maelis")
	assert_eq(lines[0], "Matchups this page teaches:")
	assert_true(lines.has("Volt into Riptail x2"))
	assert_true(lines.has("Bloom into Zephlet x.5"))
	assert_true(lines.has("Volt into Zippit x1") or lines.has("Volt into Zippit x.5"))
	assert_true(Lexicon.lesson_lines("cartographers").is_empty())

# --- 91 element symbols at the target pin ------------------------------------------------------

func test_target_pin_shows_elements_only_when_aiming() -> void:
	var pin := TargetPin.new()
	pin.elements = [E.STONE, E.UMBRA] as Array[int]
	pin.filled = true
	assert_eq(pin.shown_elements(), [E.STONE, E.UMBRA] as Array[int])
	assert_gt(pin.size.x, TargetPin.SIZE.x + TargetPin.ICON_STEP, "room for two symbols")
	pin.filled = false
	assert_true(pin.shown_elements().is_empty(), "the hollow choosing pin stays plain")
	assert_eq(pin.size, TargetPin.SIZE)
	pin.free()

# --- 94 the later elements' fields per Rift -----------------------------------------------------

func test_later_elements_have_fields() -> void:
	var boosted: Dictionary = {}
	for id: String in BattleRules.FIELDS:
		boosted[str(BattleRules.FIELDS[id].boost)] = id
	for el: String in ["RUST", "INK", "FROST", "GILT"]:
		assert_true(boosted.has(el), el)
		assert_eq(BattleRules.field_mult(str(boosted[el]), E[el]), BattleRules.FIELD_BOOST, el)

func test_rifts_vary_their_fields() -> void:
	var maps: Dictionary = RiftFields.data().get("rift_maps", {})
	var kinds: Dictionary = {}
	for file: String in maps:
		assert_true(BattleRules.FIELDS.has(str(maps[file])), file)
		var m: MapData = MapData.load_map(file)
		assert_not_null(m, file)
		assert_eq(m.field, RiftFields.home_field(file), file)
		kinds[str(maps[file])] = true
	assert_gte(kinds.size(), 8, "the Rifts do not all stand in one field")
	assert_eq(MapData.load_map("cinder_rift").field, "ash_storm", "a map's own field wins")
	assert_eq(RiftFields.home_field("brightledge"), "")

# --- 99 matchup quiz ---------------------------------------------------------------------------

func test_quiz_round_is_right_and_fair() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var round: Array[Dictionary] = MatchupQuiz.make_round(rng, 1)
	assert_eq(round.size(), int(MatchupQuiz.cfg().questions))
	var era1: Array[int] = MatchupQuiz.elements_for(1)
	assert_eq(era1.size(), 8)
	var seen: Dictionary = {}
	for q: Dictionary in round:
		assert_true(int(q.atk) in era1 and int(q.def) in era1)
		assert_eq(Elements.single(int(q.atk), int(q.def)), MatchupQuiz.answers()[int(q.answer)])
		assert_false(seen.has([q.atk, q.def]), "no pair twice")
		seen[[q.atk, q.def]] = true
	var again := RandomNumberGenerator.new()
	again.seed = 99
	assert_eq(MatchupQuiz.make_round(again, 1), round, "same seed, same round")
	assert_gt(MatchupQuiz.elements_for(4).size(), era1.size())

func test_quiz_answers_and_prompt_read_well() -> void:
	assert_eq(MatchupQuiz.answer_labels(), ["Strong, x2", "Plain, x1", "Weak, x0.5"] as Array[String])
	assert_eq(MatchupQuiz.prompt({"atk": E.TIDE, "def": E.EMBER, "answer": 0}, 1, 5), "Question 1 of 5: Tide into Ember?")

func test_quiz_pays_once_and_keeps_the_best() -> void:
	var rec: Dictionary = {}
	var r: Dictionary = MatchupQuiz.finish(rec, 3, 5)
	assert_eq(int(r.best), 3)
	assert_true(bool(r.new_best))
	assert_eq(str(r.reward), "")
	r = MatchupQuiz.finish(rec, 5, 5)
	assert_eq(str(r.reward), str(MatchupQuiz.cfg().reward))
	assert_false(Database.item(str(r.reward)).is_empty())
	r = MatchupQuiz.finish(rec, 5, 5)
	assert_eq(str(r.reward), "", "only the first perfect round pays")
	r = MatchupQuiz.finish(rec, 2, 5)
	assert_eq(int(r.best), 5)
	assert_false(bool(r.new_best))

# --- 102 element dominance per region ------------------------------------------------------------

func test_every_region_has_dominant_elements() -> void:
	for region: String in ["veydal", "corvane", "ashmere", "solenne", "vellmarch", "quillmarch", "halcyra", "quivermoor"]:
		var b: Array[int] = ElementDominance.boost(region)
		assert_eq(b.size(), 2, region)
	assert_eq(ElementDominance.boost("vellmarch"), [E.RUST, E.MASK] as Array[int])
	assert_true(ElementDominance.boost("nowhere").is_empty())

func test_dominant_elements_step_out_more_often() -> void:
	var tide: Dictionary = {"species": "Puddlet", "weight": 10}
	var ember: Dictionary = {"species": "Kindlop", "weight": 10}
	var b: Array[int] = ElementDominance.boost("corvane")
	assert_gt(EncounterTable.weight_of(tide, b), EncounterTable.weight_of(ember, b), "Tide rules Corvane")
