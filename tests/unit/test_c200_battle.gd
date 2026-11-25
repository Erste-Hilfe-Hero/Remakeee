extends GutTest
## Chimora 200 list, battle package: multi-hit arts (48), loss tip (71).

const MULTI: Array[String] = ["Pebble Hail", "Cinder Flurry", "Ripple Jab", "Burr Volley", "Static Patter",
	"Gust Flicks", "Glint Volley", "Shadow Pecks", "Knuckle Patter"]

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	Loc.set_language("en")

func test_multi_hit_arts_exist_and_are_taught_by_a_crystal_hesper_sells() -> void:
	var shop: String = FileAccess.get_file_as_string("res://data/dialogue/lighthouse.json")
	for n: String in MULTI:
		var mv: MoveData = Database.move(n)
		assert_not_null(mv, n)
		assert_true(mv.has_effect(&"multi_hit"), n)
		var crystal: String = "echo_" + n.to_snake_case()
		assert_eq(str(Database.item(crystal).get("teaches", "")), n, crystal)
		assert_true(shop.contains(crystal), "Hesper sells " + crystal)

func test_knuckle_patter_is_neutral_and_any_spirling_can_learn_it() -> void:
	assert_true(Database.move("Knuckle Patter").neutral)
	assert_true(bool(Database.item("echo_knuckle_patter").get("any_element", false)))

func test_multi_hit_arts_are_translated() -> void:
	Loc.set_language("de")
	for n: String in MULTI:
		var mv: MoveData = Database.move(n)
		assert_ne(Loc.t(mv.move_name), mv.move_name, n)
		assert_ne(Loc.t(mv.description), mv.description, n)

func test_loss_tip_names_elements_that_hit_the_winner_hard() -> void:
	var foe: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])
	var tip: String = BattleGuide.loss_tip(foe)
	assert_string_contains(tip, "Tip: ")
	assert_string_contains(tip, foe.display_name())
	for e: int in Elements.E.values():
		if tip.contains(Elements.element_name(e) + " "):
			assert_gte(Elements.multiplier(e, foe.elements()), 2.0, Elements.element_name(e))
	Loc.set_language("de")
	assert_string_contains(BattleGuide.loss_tip(foe), "Tipp: ")

func test_loss_tip_is_empty_without_a_foe() -> void:
	assert_eq(BattleGuide.loss_tip(null), "")

func test_wild_opening_says_if_the_kind_is_in_the_spirlog() -> void:
	var me: Spirling = BattleFixtures.make("Zippit", 10, ["Cinder Nip"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Kindlop", 8, ["Cinder Nip"] as Array[String])
	var wild: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling])
	assert_eq(BattleOpening.spirlog_note(wild, foe, {}), BattleOpening.NOTE_NEW)
	assert_eq(BattleOpening.spirlog_note(wild, foe, {"Kindlop": {"seen": true, "bonded": true}}), BattleOpening.NOTE_KNOWN)
	var duel: BattleModel = BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling], false)
	assert_eq(BattleOpening.spirlog_note(duel, foe, {}), "", "no note against a Wayfarer")

func test_battle_items_are_grouped_heal_cure_energy_rest() -> void:
	var heal: String = ""
	var cure: String = ""
	var energy: String = ""
	for it: Dictionary in Database.items.values():
		if not bool(it.get("battle", false)):
			continue
		var g: int = BattleScene.item_group(it)
		if g == 0 and heal.is_empty():
			heal = str(it.id)
		elif g == 1 and cure.is_empty():
			cure = str(it.id)
		elif g == 2 and energy.is_empty():
			energy = str(it.id)
	assert_false(heal.is_empty() or cure.is_empty() or energy.is_empty())
	assert_eq(BattleScene.sort_battle_items([energy, cure, heal] as Array[String]), [heal, cure, energy] as Array[String])

# --- item 49: arts that hit and then fall back --------------------------------------------------

const PIVOT: Array[String] = ["Ember Feint", "Ebb Strike", "Petal Dodge", "Spark and Dash", "Gust Retreat", "Fade Swipe"]

func test_pivot_arts_exist_with_a_crystal_and_an_info_line() -> void:
	var shop: String = FileAccess.get_file_as_string("res://data/dialogue/lighthouse.json")
	for n: String in PIVOT:
		var mv: MoveData = Database.move(n)
		assert_not_null(mv, n)
		assert_true(mv.has_effect(&"pivot"), n)
		assert_true(shop.contains("echo_" + n.to_snake_case()), n)
		assert_string_contains(CommandMenu.move_info(mv), "best-suited teammate steps in")

func test_pivot_art_swaps_the_user_out_after_a_hit() -> void:
	var lead: Spirling = BattleFixtures.make("Kindlop", 30, ["Ember Feint"] as Array[String])
	var bench: Spirling = BattleFixtures.make("Zippit", 30, ["Cinder Nip"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Wickit", 30, ["Cinder Nip"] as Array[String])
	var m: BattleModel = BattleFixtures.model([lead, bench] as Array[Spirling], [foe] as Array[Spirling])
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.active_index(BattleModel.Side.PLAYER), 1, "the teammate stepped in")

func test_pivot_art_alone_keeps_the_user_in() -> void:
	var lead: Spirling = BattleFixtures.make("Kindlop", 30, ["Ember Feint"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Wickit", 30, ["Cinder Nip"] as Array[String])
	var m: BattleModel = BattleFixtures.model([lead] as Array[Spirling], [foe] as Array[Spirling])
	m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.active_index(BattleModel.Side.PLAYER), 0)

const NEW_GIFTS: Array[String] = ["fireproof", "dry_coat", "grounded", "thorn_coat", "static_fur", "damp_skin", "calm_mind"]

func test_new_gifts_exist_are_translated_and_are_spread_over_kinds() -> void:
	Loc.set_language("de")
	var count: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		count[sd.trait_id] = int(count.get(sd.trait_id, 0)) + 1
	for id: String in NEW_GIFTS:
		var t: Dictionary = BattleRules.trait_info(id)
		assert_false(t.is_empty(), id)
		assert_ne(Loc.t(str(t.label)), str(t.label), id)
		assert_ne(Loc.t(str(t.text)), str(t.text), id)
		assert_true(int(count.get(id, 0)) >= 5, "%s is on %d kinds" % [id, int(count.get(id, 0))])

func test_new_immunity_gifts_block_their_status() -> void:
	assert_true(BattleRules.is_immune(BattleFixtures.make("Cindle", 20, ["Cinder Nip"] as Array[String]), "scorch"))
	assert_false(BattleRules.is_immune(BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String]), "scorch"))

func test_calm_mind_takes_less_from_focus_arts_only() -> void:
	var calm: Spirling = BattleFixtures.make("Hushkin", 20, ["Cinder Nip"] as Array[String])
	var user: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])
	var phys: MoveData = Database.move("Cinder Nip").duplicate()
	phys.kind = MoveData.Kind.PHYSICAL
	var focus: MoveData = phys.duplicate()
	focus.kind = MoveData.Kind.FOCUS
	var a: float = BattleRules.damage_mult(user, calm, phys, "")
	assert_almost_eq(BattleRules.damage_mult(user, calm, focus, ""), a * 0.85, 0.001)
