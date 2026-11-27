extends GutTest
## Chimora 200 list items 31 (world map "last here"), 32 (way to the nearest rest point) and
## 41 (on-screen "Reset room" in boulder rooms).

var _cells: Dictionary
var _here: String
var _last: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_cells = GameState.map_cells
	_here = GameState.here_place
	_last = GameState.last_place
	GameState.map_cells = {}
	GameState.here_place = ""
	GameState.last_place = ""

func after_each() -> void:
	GameState.map_cells = _cells
	GameState.here_place = _here
	GameState.last_place = _last

func _visit(id: String) -> void:
	var m: MapData = MapData.load_map(id)
	Survey.reveal(m, Vector2i(m.width / 2, m.height / 2))

func test_last_here_follows_map_changes() -> void:
	GameState.note_place("brindlewick")
	assert_eq(GameState.last_place, "", "nothing before the first place")
	GameState.note_place("brindlewick")
	assert_eq(GameState.last_place, "", "the same place again changes nothing")
	GameState.note_place("fernstair")
	assert_eq(GameState.last_place, "brindlewick")
	GameState.note_place("")
	assert_eq(GameState.here_place, "fernstair", "maps outside the layout are ignored")
	assert_eq(WorldAtlas.last_here("fernstair"), "brindlewick")
	assert_eq(WorldAtlas.last_here("lighthouse"), "", "not when the player stands in it (a house of it)")

func test_last_here_survives_saving() -> void:
	GameState.note_place("brindlewick")
	GameState.note_place("fernstair")
	var d: Dictionary = GameState.to_dict()
	GameState.last_place = ""
	GameState.here_place = ""
	GameState.from_dict(d)
	assert_eq(GameState.last_place, "brindlewick")
	assert_eq(GameState.here_place, "fernstair")

func test_rows_mark_last_here() -> void:
	_visit("brindlewick")
	_visit("fernstair")
	var rows: Array[Dictionary] = WorldMapMenu.place_rows(WorldAtlas.known("fernstair"), "brindlewick")
	var marked: Array[String] = []
	for r: Dictionary in rows:
		if bool(r.get("last", false)):
			marked.append(str(r.place))
			assert_eq(str(r.hint), "You were here last.")
	assert_eq(marked, ["brindlewick"] as Array[String])

func test_view_knows_last_here() -> void:
	_visit("brindlewick")
	_visit("fernstair")
	GameState.note_place("brindlewick")
	GameState.note_place("fernstair")
	var view := WorldMapView.new()
	view.size = Vector2(160, 104)
	add_child_autofree(view)
	view.refresh("fernstair")
	assert_eq(view.last_here, "brindlewick")

func test_nearest_heal_walks_the_roads() -> void:
	_visit("brindlewick")
	var known: Dictionary = WorldAtlas.known("fernstair")
	assert_has(WorldAtlas.symbols("brindlewick"), "heal")
	assert_eq(WorldAtlas.nearest_heal("fernstair", known), "brindlewick")
	assert_eq(WorldAtlas.nearest_heal("lighthouse", known), "brindlewick", "its own place counts")
	assert_eq(WorldAtlas.nearest_heal("fernstair", {}), "", "only visited rest points")
	assert_eq(WorldAtlas.nearest_heal("nowhere", known), "")

func test_heal_hint_says_the_way() -> void:
	assert_eq(WorldAtlas.direction("fernstair", "brindlewick"), "south", "Brindlewick lies one cell south")
	assert_eq(WorldAtlas.direction("brindlewick", "fernstair"), "north")
	assert_eq(WorldAtlas.direction("brindlewick", "reedhaven"), "east", "two east, one south reads as east")
	assert_eq(WorldAtlas.direction("fernstair", "reedhaven"), "south-east")
	assert_string_contains(WorldAtlas.heal_hint("fernstair", "brindlewick"), "to the south")
	assert_string_contains(WorldAtlas.heal_hint("lighthouse", "brindlewick"), "right here")
	assert_string_contains(WorldAtlas.heal_hint("fernstair", ""), "No rest point")

func test_view_rings_the_highlight() -> void:
	var view := WorldMapView.new()
	view.restore({"zoom": 2, "pan": Vector2.ZERO, "highlight": "brindlewick", "show_highlight": true})
	assert_eq(view.highlight, "brindlewick")
	assert_eq(view.state().highlight, "brindlewick", "carried over to the next list")
	view.free()

func _room() -> MapData:
	return MapData.from_dict("t_room", {"name": "Test Room", "rows": [
		"WWWWfWWWW",
		"WfffffffW",
		"WfBfffPfW",
		"WfffBfffW",
		"WfffffPfW",
		"WffffkffW",
		"WWWWDWWWW"],
		"blocks": [{"x": 4, "y": 0, "open_flag": "t_room_open"}],
		"puzzles": [{"id": "plates", "flag": "t_room_open"}],
		"warps": [{"x": 4, "y": 6, "to": "brindlewick", "tx": 2, "ty": 5}]})

func test_reset_button_shows_after_a_push_until_solved() -> void:
	var m: MapData = _room()
	assert_false(PuzzleRoom.reset_offered(m), "nothing moved yet")
	PuzzleRoom.step(m, Vector2i(1, 2), Vector2i.RIGHT)
	assert_true(PuzzleRoom.reset_offered(m), "a boulder moved and the door is shut")
	PuzzleRoom.set_boulders(m, [Vector2i(6, 2), Vector2i(6, 4)])
	assert_false(PuzzleRoom.reset_offered(m), "solved: no reset to undo it by mistake")
	PuzzleRoom.reset(m, {})
	assert_false(PuzzleRoom.reset_offered(m), "back at the start")

func test_reset_button_in_a_room_without_plates() -> void:
	var m := MapData.from_dict("t_push", {"rows": ["WWWWW", "WfBfW", "WfffW", "WWWWW"]})
	PuzzleRoom.step(m, Vector2i(1, 1), Vector2i.RIGHT)
	assert_true(PuzzleRoom.reset_offered(m))
