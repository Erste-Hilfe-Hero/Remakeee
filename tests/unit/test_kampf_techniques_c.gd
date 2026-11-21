extends GutTest
## KAMPF_PLAN_1000 batch 3: charged art (125), time-of-day arts (154), the aim hint per foe (92),
## the hit chance of status arts on the art row (144) and the art balance check (155).

const T := BattleEvent.Type
const NEW_ARTS: Array[String] = ["Coiled Strike", "Night Prowl", "Noon Glare"]

var _matchups: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_matchups = GameState.known_matchups.duplicate()
	Loc.set_language("en")

func after_each() -> void:
	GameState.known_matchups = _matchups
	Loc.set_language("en")

func _mon(species: String, art: String = "Bowl Over", level: int = 30) -> Spirling:
	var s: Spirling = BattleFixtures.make(species, level, [art])
	s.energy = Spirling.MAX_ENERGY
	return s

func _duel(mine: Array[Spirling], theirs: Array[Spirling], seed_value: int = 3) -> BattleModel:
	var m := BattleModel.new(mine, theirs, true, seed_value, 0)
	m.items_allowed = false
	m.start()
	return m

func test_charged_art_gathers_first_then_hits() -> void:
	var me: Spirling = _mon("Talusk", "Coiled Strike")
	var foe: Spirling = _mon("Kindlop")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var full: int = foe.hp
	var said: bool = false
	for e: BattleEvent in m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1)):
		if e.type == T.TECHNIQUE and e.describe() == "%s gathers its strength!" % me.display_name():
			said = true
	assert_true(said, "the log says it gathers")
	assert_eq(foe.hp, full, "no hit on the first use")
	assert_true(TechniqueRules.is_charged(m, me, Database.move("Coiled Strike")))
	me.energy = Spirling.MAX_ENERGY
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_lt(foe.hp, full, "the second use lands")
	assert_false(TechniqueRules.is_charged(m, me, Database.move("Coiled Strike")), "the charge is spent")

func test_charged_hit_is_doubled() -> void:
	var me: Spirling = _mon("Talusk", "Coiled Strike")
	var foe: Spirling = _mon("Kindlop")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var mv: MoveData = Database.move("Coiled Strike")
	var plain: float = TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, mv)
	TechniqueRules.state(m).charged_hit[me] = m.turn
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, mv), plain * TechniqueRules.CHARGE_MULT, 0.0001)

func test_time_of_day_art_is_stronger_only_at_its_time() -> void:
	var m: BattleModel = _duel([_mon("Hushkin")] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	var prowl: MoveData = Database.move("Night Prowl")
	var glare: MoveData = Database.move("Noon Glare")
	m.day_phase = DayCycle.Phase.NIGHT
	assert_almost_eq(TechniqueRules.daytime_mult(m, prowl), 1.5, 0.0001)
	assert_almost_eq(TechniqueRules.daytime_mult(m, glare), 1.0, 0.0001)
	m.day_phase = DayCycle.Phase.DAY
	assert_almost_eq(TechniqueRules.daytime_mult(m, prowl), 1.0, 0.0001)
	assert_almost_eq(TechniqueRules.daytime_mult(m, glare), 1.5, 0.0001)
	m.day_phase = -1
	assert_almost_eq(TechniqueRules.daytime_mult(m, prowl), 1.0, 0.0001, "indoors or with the day cycle off it is plain")

func test_new_arts_have_an_info_line_in_english_and_german() -> void:
	for art: String in NEW_ARTS:
		var mv: MoveData = Database.move(art)
		assert_not_null(mv, art)
		var en: String = TechniqueRules.info_line(mv.effects[0])
		assert_false(en.is_empty(), art)
		Loc.set_language("de")
		var de: String = TechniqueRules.info_line(mv.effects[0])
		Loc.set_language("en")
		assert_ne(de, en, art + " is German")
		assert_false(de.contains("%s") or de.contains("%d"), de)

func test_aim_hint_shows_the_known_matchup_per_foe() -> void:
	var foe: Spirling = _mon("Mossling")
	var nip: MoveData = Database.move("Cinder Nip")
	GameState.known_matchups = {}
	assert_eq(TechniqueRules.aim_tag(foe, nip), "", "nothing known yet")
	GameState.learn_matchup(nip.element, foe.data.species_name, 2.0)
	if GameState.difficulty != GameState.Difficulty.STORY:
		assert_eq(TechniqueRules.aim_tag(foe, nip), " x2")
	assert_eq(TechniqueRules.aim_tag(foe, Database.move("Hush")), "", "status arts carry no tag")

func test_status_art_that_can_miss_shows_its_hit_chance() -> void:
	var hush: MoveData = Database.move("Hush")
	assert_lt(hush.accuracy, 1.0)
	assert_eq(CommandMenu.move_line(hush, 9, 1.0), "%dE %d%%" % [hush.energy_cost, roundi(hush.accuracy * 100.0)])
	var sure: MoveData = Database.move("Ash Call")
	assert_eq(CommandMenu.move_line(sure, 9, 1.0), "%dE" % sure.energy_cost, "a sure status art stays short")

func test_every_art_of_the_balance_check_is_sold_by_hesper() -> void:
	var shop: String = " " + str(Dialogue.get_entry("lighthouse/hesper").get("action", "")) + " "
	for art: String in ArtsSim.ARTS:
		assert_not_null(Database.move(art), art)
		var crystal: String = ""
		for id: String in Database.items:
			if str(Database.items[id].get("teaches", "")) == art:
				crystal = id
		assert_true(shop.contains(" " + crystal + " "), "Hesper sells a crystal for " + art)

func test_art_balance_check_reports_a_row_per_art() -> void:
	var r: Dictionary = ArtsSim.run(20, 2, 7, ["Night Prowl"] as Array[String])
	assert_eq(r.arts.size(), 1)
	var row: Dictionary = r.arts["Night Prowl"]
	assert_between(float(row.with), 0.0, 1.0)
	assert_between(float(row.without), 0.0, 1.0)
	assert_almost_eq(float(row.gain), float(row.with) - float(row.without), 0.002)
	assert_true(ArtsSim.report(r).contains("| Night Prowl |"))
