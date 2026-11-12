extends GutTest
## Buildings design plan: night windows (item 8) and doors that can be reached (item 10).

func test_windows_light_at_dusk_and_night_outdoors_only() -> void:
	assert_true(WindowGlow.lit(true, DayCycle.Phase.NIGHT, true))
	assert_true(WindowGlow.lit(true, DayCycle.Phase.DUSK, true))
	assert_false(WindowGlow.lit(true, DayCycle.Phase.DAY, true))
	assert_false(WindowGlow.lit(false, DayCycle.Phase.NIGHT, true), "rooms keep their own light")
	assert_false(WindowGlow.lit(true, DayCycle.Phase.NIGHT, false), "day-night option off")

func test_every_town_style_has_window_panes_inside_a_tile() -> void:
	for region: String in ["veydal", "corvane", "ashmere", "solenne"]:
		assert_true(WindowGlow.PANES.has(region), region)
		for r: Rect2i in WindowGlow.PANES[region]:
			assert_true(Rect2i(0, 0, TilesetFactory.TILE, TilesetFactory.TILE).encloses(r), region)

func test_window_cells_are_the_walls() -> void:
	var m := MapData.new()
	m.rows = PackedStringArray(["RRR", "HDH", "..."])
	m.height = 3
	m.width = 3
	m.outdoor = true
	assert_eq(WindowGlow.window_cells(m), [Vector2i(0, 1), Vector2i(2, 1)])
	m.outdoor = false
	assert_true(WindowGlow.window_cells(m).is_empty())

func test_every_door_opens_onto_ground() -> void:
	# No building tile blocks a door: each door has open ground or the map edge beside it.
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var m: MapData = MapData.load_map(f.get_basename())
		for y: int in m.height:
			for x: int in m.rows[y].length():
				if m.rows[y][x] != "D":
					continue
				var open: bool = false
				for d: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
					var n := Vector2i(x, y) + d
					if not m.in_bounds(n) or not TilesetFactory.is_solid(m.kind_at(n)):
						open = true
				assert_true(open, "%s door %d,%d" % [f, x, y])
