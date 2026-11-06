extends GutTest
## Area 3: the Act III maps of Ashmere, the mountain railway and the way into the Undrawn.

const MAPS: Array[String] = ["ashmere_station", "cinderfold", "gravers_hall", "kiln_rift", "saltglass",
	"glass_rift", "wide_rift_far", "undrawn_1", "undrawn_2", "undrawn_3"]

func before_all() -> void:
	Database.load_all()

func test_act3_maps_are_in_ashmere_and_have_every_story_spot() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		assert_not_null(m, id)
		if m == null:
			continue
		assert_eq(m.region, "ashmere", id)
		for sp: String in StoryPlacements.spots_needed(id):
			assert_true(m.spots.has(sp), "%s has spot %s" % [id, sp])

func test_story_warps_land_where_the_story_expects() -> void:
	# The railway arrives at 6 20 on the station, the scene undrawn_enter at 6 20 on undrawn_1.
	assert_eq(Transit.arrival("mountain_rail", "ashmere_station").cell, Vector2i(6, 20))
	var u: MapData = MapData.load_map("undrawn_1")
	assert_true(u.is_walkable(Vector2i(6, 20)))

func test_railway_runs_only_after_act_two() -> void:
	assert_eq(str(Transit.line("mountain_rail").kind), "rail")
	assert_true(Transit.open_stops("mountain_rail", "greyreach", {}).is_empty())
	assert_true(Transit.open_stops("mountain_rail", "greyreach", {"stop_ashmere_station": true}).is_empty(),
		"a stop flag alone does not run the train")
	assert_eq(Transit.open_stops("mountain_rail", "greyreach", {"act2_end": true}), ["ashmere_station"] as Array[String])
	assert_eq(Transit.open_stops("mountain_rail", "ashmere_station", {"act2_end": true}), ["greyreach"] as Array[String])
	assert_ne(Transit.trip_line("rail", "Ashmere"), Transit.trip_line("boat", "Ashmere"))

func _gate_flags(id: String) -> Array:
	var out: Array = []
	for b: Dictionary in MapData.load_map(id).blocks:
		out.append(str(b.get("open_flag", "")))
	return out

func test_the_way_opens_in_story_order() -> void:
	assert_has(_gate_flags("saltglass"), "veit_plate_done")
	assert_has(_gate_flags("wide_rift_far"), "undrawn_reached")

func test_ashmere_lies_right_of_corvane() -> void:
	assert_eq(WorldAtlas.grid_cell("ashmere_station"), Vector2i(14, 4))
