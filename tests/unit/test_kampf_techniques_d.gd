extends GutTest
## KAMPF_PLAN_1000 batch 4: the lexicon page of matchups seen with shape marks (81, 83), element
## training in a matching field (112) and the swap preview when an art is replaced (140).

const E := Elements.E

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Loc.set_language("en")

func after_each() -> void:
	Loc.set_language("en")

func _mon(species: String) -> Spirling:
	return BattleFixtures.make(species, 30, ["Bowl Over"])

func test_matchup_page_says_so_when_nothing_was_seen() -> void:
	var lines: Array[String] = TechniqueRules.matchup_lines({})
	assert_eq(lines, ["No matchups seen yet. Every hit you land is written down here."] as Array[String])

func test_matchup_page_groups_by_element_with_shape_marks() -> void:
	var known: Dictionary = {
		"%d:Mossling" % E.EMBER: 2.0, "%d:Puddlet" % E.EMBER: 0.5, "%d:Thornback" % E.EMBER: 2.0,
		"%d:Talusk" % E.TIDE: 2.0, "%d:Zippit" % E.EMBER: 1.0}
	var lines: Array[String] = TechniqueRules.matchup_lines(known)
	assert_eq(lines, ["+ strong, - weak. Every hit you land is written down here.",
		"+ Ember: Mossling x2, Thornback x2", "- Ember: Puddlet x.5", "+ Tide: Talusk x2"] as Array[String])

func test_matchup_page_is_german_in_german() -> void:
	Loc.set_language("de")
	var lines: Array[String] = TechniqueRules.matchup_lines({"%d:Mossling" % E.EMBER: 2.0})
	assert_eq(lines[0], "+ stark, - schwach. Jeder Treffer, den du landest, wird hier notiert.")

func test_field_that_boosts_its_element_doubles_the_spark_chance() -> void:
	var kindlop: Spirling = _mon("Kindlop")
	var puddlet: Spirling = _mon("Puddlet")
	var m := BattleModel.new([kindlop] as Array[Spirling], [puddlet] as Array[Spirling], true, 3, 0)
	assert_almost_eq(TechniqueRules.spark_field_mult(m, kindlop), 1.0, 0.0001, "no field")
	m.field = "ash_storm"
	assert_almost_eq(TechniqueRules.spark_field_mult(m, kindlop), TechniqueRules.FIELD_SPARK_MULT, 0.0001, "Ember on Ash Storm")
	assert_almost_eq(TechniqueRules.spark_field_mult(m, puddlet), 1.0, 0.0001, "Tide on Ash Storm")

func test_swap_preview_puts_old_and_new_side_by_side() -> void:
	var nip: MoveData = Database.move("Cinder Nip")
	var strike: MoveData = Database.move("Coiled Strike")
	var moves: Array[MoveData] = [nip]
	var rows: Array[Dictionary] = PauseMenu.swap_rows(moves, strike)
	assert_eq(rows.size(), 1)
	assert_eq(str(rows[0].text), "Cinder Nip")
	assert_eq(str(rows[0].hint), "Ember > Stone  Power %d > %d  Energy %d > %d" % [nip.power, strike.power, nip.energy_cost, strike.energy_cost])
	assert_eq(PauseMenu.swap_rows(moves, null), PauseMenu.art_rows(moves), "without a new art it is the plain list")
