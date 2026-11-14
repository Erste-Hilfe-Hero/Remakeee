extends GutTest
## Plan area 8, P2 batch: the album in the collection tab (3487), album fields never filled by
## one daily task (3488) and album places only from reached places (3489).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_album_shows_in_the_collection_tab() -> void:
	var text: String = Goals.tab_text("Collection")
	for line: String in Album.lines():
		assert_string_contains(text, line)

func test_no_album_field_is_one_daily_task() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))
	var errors: PackedStringArray = EndgameValidator.album_vs_daily(d.album_tasks, d.daily_tasks)
	assert_eq(errors.size(), 0, "\n".join(errors))
	var clash: PackedStringArray = EndgameValidator.album_vs_daily([{"id": "a", "event": "photo", "n": 2}],
		[{"id": "t", "event": "photo", "n": 2}])
	assert_eq(clash.size(), 1, "the check finds a clash")

func test_album_places_only_where_the_save_has_been() -> void:
	var reached: Array[String] = DailyTasks.reached_maps()
	for m: int in range(1, 13):
		for id: String in Album.draw("2027-%02d" % m):
			var t: Dictionary = Album.def(id)
			if t.has("map"):
				assert_true(str(t.map) in reached, "%s in %s" % [id, t.map])
	# Once every place was reached, place fields can be drawn again.
	var all: Array = []
	for t: Dictionary in Album.defs():
		if t.has("map"):
			all.append(str(t.map))
	GameState.records["maps_visited"] = all
	var places: int = 0
	for m: int in range(1, 13):
		for id: String in Album.draw("2027-%02d" % m):
			if Album.def(id).has("map"):
				places += 1
	assert_gt(places, 0)
	assert_eq(Album.draw("2027-03"), Album.draw("2027-03"), "the same month draws the same")
