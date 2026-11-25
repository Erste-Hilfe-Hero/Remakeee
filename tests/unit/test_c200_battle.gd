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
