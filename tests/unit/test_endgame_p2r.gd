extends GutTest
## Plan area 8, P2 batch: places, art book, Prism page and collector cards
## (plan 3358, 3360, 3361, 3364, 3366).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

## A visible kind with at least one wild place.
func _wild_kind() -> SpirlingData:
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		if not Collection.habitat_maps(sd.species_name).is_empty():
			return sd
	return null

func test_places_are_ticked_where_seen() -> void:
	var sd: SpirlingData = _wild_kind()
	assert_not_null(sd)
	var maps: Array[String] = Collection.habitat_maps(sd.species_name)
	for id: String in maps:
		assert_true(MapData.exists(id), id)
	assert_false(Collection.places_done(sd.species_name))
	assert_string_contains(Collection.places_line(sd.species_name), "???")
	for id: String in maps:
		GameState.current_map = id
		GameState.mark_seen(sd.species_name)
	assert_true(Collection.places_done(sd.species_name))
	assert_false(Collection.places_line(sd.species_name).contains("???"))
	assert_string_contains(SpirlogBook.page_text(sd, GameState.spirlog), "(%d of %d)" % [maps.size(), maps.size()])

func test_places_goal_counts_and_pays_once() -> void:
	assert_gt(Collection.set_total("places"), 0)
	for sd: SpirlingData in SpirlogBook.visible_kinds(GameState.flags):
		for id: String in Collection.habitat_maps(sd.species_name):
			GameState.current_map = id
			GameState.mark_seen(sd.species_name)
	assert_eq(Collection.set_count("places"), Collection.set_total("places"))
	var before: int = GameState.waymarks
	Collection.claim()
	assert_true((GameState.records.get("collection", {}) as Dictionary).has("places"))
	assert_gt(GameState.waymarks, before)

func test_art_book_marks_used_arts() -> void:
	var arts: Array[String] = Collection.learnable_arts()
	Collection.note_art(arts[0])
	var lines: Array[String] = Collection.art_book_lines()
	assert_eq(lines.size(), arts.size() + 1)
	assert_true(lines[1].begins_with("+ "))
	assert_true(lines[2].begins_with("  "))
	assert_string_contains(lines[0], "1")

func test_prism_page_has_no_odds() -> void:
	assert_true(Collection.prism_kinds().is_empty())
	var sd: SpirlingData = GameState.party[0].data
	var e: Dictionary = GameState.spirlog[sd.species_name]
	e["prism_seen"] = true
	assert_eq(Collection.prism_kinds(), [sd.species_name] as Array[String])
	var text: String = "\n".join(Collection.prism_lines())
	assert_false(text.contains("%"), "no chance shown")
	assert_false(text.to_lower().contains("chance"))

func test_collector_card_needs_ring_30_and_every_art() -> void:
	var s: Spirling = GameState.party[0]
	assert_false(Collection.card_open(s.data))
	s.level = Collection.STAR_LEVEL
	assert_false(Collection.card_open(s.data), "arts still missing")
	for a: String in Collection.line_arts(s.data):
		Collection.note_art(a)
	assert_true(Collection.card_open(s.data))
	assert_eq(Collection.cards_open(), 1)
	assert_string_contains(SpirlogBook.page_text(s.data, GameState.spirlog), "Collector card")
