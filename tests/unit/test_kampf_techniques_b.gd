extends GutTest
## KAMPF_PLAN_1000 batch 2: mixed arts (114), Clean Slate (130), the field countdown (122), damage
## by element (105), the stepping-in warning (119), the lexicon entries (84, 98) and the status
## art every species can reach (156).

const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _mon(species: String, art: String = "Bowl Over", level: int = 30) -> Spirling:
	var s: Spirling = BattleFixtures.make(species, level, [art])
	s.energy = Spirling.MAX_ENERGY
	return s

func _duel(mine: Array[Spirling], theirs: Array[Spirling], wild: bool = true, seed_value: int = 3) -> BattleModel:
	var m := BattleModel.new(mine, theirs, wild, seed_value, 0)
	m.items_allowed = false
	m.start()
	return m

func test_mixed_art_lands_with_the_better_element() -> void:
	var rush: MoveData = Database.move("Magma Rush")
	assert_not_null(rush)
	# Ember into Bloom is x2, Stone into Bloom is x0.5: Ember wins, nothing extra.
	assert_almost_eq(TechniqueRules.dual_ratio(rush, _mon("Mossling")), 1.0, 0.0001)
	# Ember into Volt is x1, Stone into Volt is x2: the Stone side doubles the hit.
	assert_almost_eq(TechniqueRules.dual_ratio(rush, _mon("Zippit")), 2.0, 0.0001)
	assert_almost_eq(TechniqueRules.dual_ratio(Database.move("Cinder Nip"), _mon("Zippit")), 1.0, 0.0001, "plain arts stay as they are")

func test_mixed_art_ratio_is_part_of_the_hit() -> void:
	var me: Spirling = _mon("Kindlop", "Magma Rush")
	var foe: Spirling = _mon("Zippit")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	assert_almost_eq(TechniqueRules.hit_mult(m, 0, 0, me, 1, 0, foe, Database.move("Magma Rush")), 2.0, 0.0001)

func test_clean_slate_resets_only_the_target() -> void:
	var me: Spirling = _mon("Wickit", "Clean Slate")
	var foe: Spirling = _mon("Talusk")
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	me.stages["atk"] = 2
	foe.stages["def"] = 3
	foe.stages["spd"] = -1
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(foe.stage("def"), 0)
	assert_eq(foe.stage("spd"), 0)
	assert_eq(me.stage("atk"), 2, "the user keeps its own")

func test_field_says_one_turn_ahead_that_it_fades() -> void:
	var m: BattleModel = _duel([_mon("Kindlop")] as Array[Spirling], [_mon("Talusk")] as Array[Spirling])
	m.set_field("ash_storm", 3)
	var warned: int = -1
	var ended: int = -1
	for t: int in 4:
		for e: BattleEvent in m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1)):
			if e.type == T.TECHNIQUE and e.describe() == "The Ash Storm will fade after the next turn.":
				warned = t
			if e.type == T.FIELD_END:
				ended = t
	assert_gte(warned, 0, "the warning comes")
	assert_eq(ended, warned + 1, "and the field ends one turn later")

func test_damage_by_element_is_summed_per_side() -> void:
	var me: Spirling = _mon("Kindlop", "Cinder Nip", 20)
	var foe: Spirling = _mon("Talusk", "Bowl Over", 40)
	var m: BattleModel = _duel([me] as Array[Spirling], [foe] as Array[Spirling])
	var full: int = foe.hp
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	var dealt: int = full - foe.hp
	assert_gt(dealt, 0)
	assert_eq(int(TechniqueRules.element_damage(m).get("0:%d" % Elements.E.EMBER, 0)), dealt)
	assert_eq(TechniqueRules.element_summary(m), "Damage by element\nEmber: %d" % dealt)
	assert_eq(TechniqueRules.element_summary(m, 1), "", "the foe only rested")

func test_switch_warning_names_the_worst_foe_element() -> void:
	var m: BattleModel = _duel([_mon("Kindlop"), _mon("Mossling")] as Array[Spirling], [_mon("Smoldrake")] as Array[Spirling])
	assert_eq(TechniqueRules.switch_warning(m, 0, m.party(0)[1]), "!Ember", "Bloom fears the Ember foe")
	assert_eq(TechniqueRules.switch_warning(m, 0, _mon("Zippit")), "", "Volt has nothing to fear from Ember")

func test_lexicon_explains_dual_elements_and_every_reaction() -> void:
	assert_true(Lexicon.has_entry("dual_elements"))
	assert_true(Lexicon.text("dual_elements").contains("multiply"))
	var text: String = Lexicon.text("reactions")
	for r: Dictionary in BattleRules.REACTIONS:
		assert_true(text.contains(Elements.element_name(int(Elements.E[str(r.element)]))), "reactions entry names " + str(r.element))

func test_every_species_can_reach_a_status_art() -> void:
	var any_status: Array[String] = []
	var by_element: Dictionary = {}
	for it: Dictionary in Database.items.values():
		var mv: MoveData = Database.move(str(it.get("teaches", "")))
		if mv == null or mv.kind != MoveData.Kind.STATUS:
			continue
		if bool(it.get("any_element", false)):
			any_status.append(mv.move_name)
		else:
			by_element[mv.element] = true
	assert_false(any_status.is_empty(), "a status art any Spirling can learn")
	for sd: SpirlingData in Database.spirlings.values():
		var ok: bool = not any_status.is_empty()
		for mv: MoveData in sd.learnset_moves:
			ok = ok or mv.kind == MoveData.Kind.STATUS
		assert_true(ok, sd.species_name)
