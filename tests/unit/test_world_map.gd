extends GutTest
## Area 3 world map (items 1242-1248, 1169, 1260, 1273).

var _cells: Dictionary
var _marks: Array

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_cells = GameState.map_cells
	_marks = GameState.map_marks
	GameState.map_cells = {}
	GameState.map_marks = []

func after_each() -> void:
	GameState.map_cells = _cells
	GameState.map_marks = _marks

func _visit(id: String) -> void:
	var m: MapData = MapData.load_map(id)
	Survey.reveal(m, Vector2i(m.width / 2, m.height / 2))

func test_places_cover_the_layout_grid() -> void:
	# Item 1242.
	var places: Dictionary = WorldAtlas.places()
	assert_true(places.has("brindlewick"))
	assert_false(places.has("lighthouse"), "interiors are not places")
	assert_eq(WorldAtlas.place_of("lighthouse"), "brindlewick")
	assert_eq(WorldAtlas.grid_cell("brindlewick"), Vector2i(3, 4))
	assert_eq(WorldAtlas.grid_cell("corvane_quay"), Vector2i(8, 4), "Corvane right of Veydal")
	assert_eq(WorldAtlas.place_at(Vector2i(3, 4)), "brindlewick")
	var size: Vector2i = WorldAtlas.grid_size()
	assert_eq(size, Vector2i(21, 7), "Solenne right of Ashmere")

func test_unknown_sighted_visited() -> void:
	# Item 1244.
	var k: Dictionary = WorldAtlas.known()
	assert_eq(int(k.brindlewick), WorldAtlas.Known.UNKNOWN)
	_visit("lighthouse")
	k = WorldAtlas.known()
	assert_eq(int(k.brindlewick), WorldAtlas.Known.VISITED, "a house counts for its town")
	assert_eq(int(k.fernstair), WorldAtlas.Known.SIGHTED, "neighbours are sighted")
	assert_eq(int(k.reedhaven), WorldAtlas.Known.SIGHTED, "so are stops of the Lake Line")
	assert_eq(int(k.cinder_rift), WorldAtlas.Known.UNKNOWN)
	assert_eq(int(k.corvane_quay), WorldAtlas.Known.UNKNOWN, "Corvane stays hidden until the crossing")
	assert_eq(int(WorldAtlas.known("crowcrest").crowcrest), WorldAtlas.Known.VISITED, "the current map counts")

func test_symbols_and_detail() -> void:
	# Items 1243, 1247.
	assert_has(WorldAtlas.symbols("reedhaven"), "heal")
	assert_has(WorldAtlas.symbols("reedhaven"), "stop")
	assert_has(WorldAtlas.symbols("cinder_rift"), "rift")
	var f: Array[int] = WorldAtlas.finds("brindlewick")
	assert_gt(f[1], 0)
	assert_eq(f[0], 0)
	var sp: Array[String] = WorldAtlas.species("fernstair")
	assert_false(sp.is_empty())
	var text: String = WorldAtlas.detail_text("fernstair")
	for part: String in ["Mapped:", "Finds:", "Weather:", "Time of day:", "Spirlings:"]:
		assert_string_contains(text, part)

func test_rows_list_visited_then_sighted() -> void:
	_visit("brindlewick")
	var rows: Array[Dictionary] = WorldMapMenu.place_rows(WorldAtlas.known())
	assert_eq(str(rows[0].place), "brindlewick")
	assert_string_contains(str(rows[0].text), "%")
	assert_true(rows.any(func(r: Dictionary) -> bool: return bool(r.get("sighted", false))))

func test_view_zoom_here_and_tap() -> void:
	# Items 1248, 1169.
	_visit("brindlewick")
	var view := WorldMapView.new()
	view.current = "brindlewick"
	view.size = Vector2(132, 104)
	add_child_autofree(view)
	view.refresh("brindlewick")
	assert_eq(view.cell_px(), WorldMapView.CELL_1X)
	view.toggle_zoom()
	assert_eq(view.zoom, 2)
	var r: Rect2 = view.cell_rect("brindlewick")
	assert_almost_eq(r.get_center().x, view.size.x / 2.0, 1.0, "Here centres the player's place")
	assert_eq(view.place_at_point(r.get_center()), "brindlewick")
	assert_eq(view.place_at_point(view.cell_rect("cinder_rift").get_center()), "", "unknown places don't answer")
	var tapped: Array = []
	view.place_tapped.connect(func(id: String) -> void: tapped.append(id))
	var down := InputEventMouseButton.new()
	down.pressed = true
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = r.get_center()
	view._gui_input(down)
	var up := InputEventMouseButton.new()
	up.pressed = false
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = r.get_center()
	view._gui_input(up)
	assert_eq(tapped, ["brindlewick"])
	assert_not_null(view.get_node_or_null("phase_icon"), "the time of day shows on the map")

func test_menu_opens_and_closes() -> void:
	_visit("brindlewick")
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var state: Dictionary = {"done": false}
	var run := func() -> void:
		await WorldMapMenu.run(host, "brindlewick")
		state.done = true
	run.call()
	for i: int in 30:
		await wait_process_frames(1)
		if host.picker.visible:
			break
	assert_eq(host.last_title, "World map")
	assert_true(host.get_node_or_null("world_map") != null)
	host.picker.picked.emit(-1)
	for i: int in 30:
		await wait_process_frames(1)
		if state.done:
			break
	assert_true(state.done)
	await wait_process_frames(1)
	assert_null(host.get_node_or_null("world_map"))

func test_dungeon_banner_counts_rooms() -> void:
	# Items 993 and 1026.
	assert_eq(WorldAtlas.room_flags("lanternwell").size(), 5)
	var m: MapData = MapData.load_map("lanternwell@1")
	assert_eq(WorldAtlas.banner(m, {}), "%s  0/5" % Loc.t(m.display_name))
	assert_eq(WorldAtlas.banner(m, {"beam_room_1": true, "beam_room_2": true}), "%s  2/5" % Loc.t(m.display_name))
	assert_true(WorldAtlas.room_flags("brackwater_sluice").is_empty(), "water levels are no rooms")
	var g: MapData = MapData.load_map("gloamwood")
	assert_true(WorldAtlas.banner(g, {}).ends_with("%"), "routes show the survey share")

func test_gloamwood_has_a_rest_spring() -> void:
	# Item 921.
	var g: MapData = MapData.load_map("gloamwood")
	assert_ne(g.heal_point, Vector2i(-1, -1))
	var heals: bool = false
	for s: Dictionary in g.signs:
		if str(Dialogue.get_entry(str(s.dialogue)).get("action", "")) == "heal":
			heals = true
	assert_true(heals)
