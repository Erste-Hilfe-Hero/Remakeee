extends GutTest
## Item 574: Scatter Gale and Graft can be taught to every Spirling by Echo Crystal.

const ANY: Dictionary = {"echo_scatter_gale": "Scatter Gale", "echo_graft": "Graft"}

func test_crystals_exist_and_teach_their_art() -> void:
	for id: String in ANY:
		var it: Dictionary = Database.item(id)
		assert_false(it.is_empty(), id)
		assert_eq(str(it.get("teaches", "")), ANY[id])
		assert_true(bool(it.get("any_element", false)), id)
		assert_not_null(Database.move(ANY[id]), ANY[id])

func test_every_species_can_learn_them() -> void:
	for sp: SpirlingData in Database.spirlings.values():
		var s := Spirling.new(sp, 20)
		for id: String in ANY:
			var knows: bool = s.moves.has(Database.move(ANY[id]))
			assert_eq(GameState.can_learn_echo(s, id), not knows, "%s %s" % [sp.species_name, id])

func test_known_art_is_refused() -> void:
	var k := Spirling.new(Database.species("Kindlop"), 10)
	assert_true(GameState.can_learn_echo(k, "echo_graft"))
	k.moves.append(Database.move("Graft"))
	assert_false(GameState.can_learn_echo(k, "echo_graft"))

func test_element_crystals_still_check_element() -> void:
	var k := Spirling.new(Database.species("Kindlop"), 10)
	assert_false(GameState.can_learn_echo(k, "echo_tide"))

func test_sold_by_the_crystal_seller_and_endgame_shop() -> void:
	var f := FileAccess.open("res://data/dialogue/thornridge.json", FileAccess.READ)
	var text: String = f.get_as_text()
	var eg := FileAccess.open("res://data/endgame.json", FileAccess.READ)
	var eg_text: String = eg.get_as_text()
	for id: String in ANY:
		assert_true(text.contains(id), "thornridge shop: " + id)
		assert_true(eg_text.contains("\"%s\"" % id), "endgame shop: " + id)
