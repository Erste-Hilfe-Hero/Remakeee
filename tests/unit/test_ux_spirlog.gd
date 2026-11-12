extends GutTest
## Plan items 1940 (progress bars on top of the Spirlog) and 1948 (where to look for kinds
## not seen yet, once the place was entered).

var _visited: Dictionary

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	_visited = GameState.visited_maps.duplicate()

func after_each() -> void:
	GameState.visited_maps = _visited

func test_progress_rows_count_seen_and_bonded() -> void:
	var rows: Array[Dictionary] = PauseMenu.spirlog_progress_rows()
	assert_eq(rows.size(), 2)
	var total: int = SpirlogBook.visible_kinds(GameState.flags).size()
	assert_string_contains(str(rows[0].text), "Seen ")
	assert_string_contains(str(rows[0].text), "/%d" % total)
	assert_string_contains(str(rows[1].text), "Bonded ")
	assert_true(rows[0].decorate is Callable, "each row draws a bar")

func test_unseen_hint_needs_an_entered_map() -> void:
	var species: String = ""
	var map_id: String = ""
	for table: String in EncounterTable.table_ids():
		var maps: Array = PauseMenu._maps_with_table(table)
		var kinds: Array = EncounterTable.species_on(table)
		if not maps.is_empty() and not kinds.is_empty():
			species = str(kinds[0])
			map_id = str(maps[0])
			break
	assert_false(species.is_empty(), "some map has wild kinds")
	GameState.visited_maps = {}
	assert_eq(PauseMenu.unseen_hint(species), "", "nothing before the place was entered")
	GameState.visited_maps = {map_id: [0, 0]}
	var hint: String = PauseMenu.unseen_hint(species)
	assert_string_contains(hint, "Look in:")
	var m: MapData = MapData.load_map(map_id)
	assert_string_contains(hint, m.display_name if not m.display_name.is_empty() else map_id)

## Item 1880: photo mode has a first-time tip with the controls, for touch and buttons.
func test_photo_tip_names_the_controls() -> void:
	assert_true(Tips.LINES.has("photo"))
	assert_true(Tips.TOPICS.has("photo"), "it is in the Guide too")
	var line: Dictionary = Tips.LINES["photo"][0]
	assert_string_contains(str(line.touch), "B leaves")
	assert_string_contains(str(line.buttons), "A takes a photo")
