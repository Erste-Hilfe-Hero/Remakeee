extends GutTest
## Area 3: the Act II maps of Corvane with the story spots and gates (docs/STORY.md).

const MAPS: Array[String] = ["madderby", "madderby_guild", "woadfen", "rain_rift", "stillwater",
	"mirror_rift", "greyreach", "wide_rift_edge"]
const RINGS: Dictionary = {"woadfen": [18, 21], "rain_rift": [20, 23], "stillwater": [20, 23],
	"mirror_rift": [21, 24], "greyreach": [22, 25]}

func before_all() -> void:
	Database.load_all()

func test_act2_maps_are_in_corvane_and_have_every_story_spot() -> void:
	for id: String in MAPS:
		var m: MapData = MapData.load_map(id)
		assert_not_null(m, id)
		if m == null:
			continue
		assert_eq(m.region, "corvane", id)
		for sp: String in StoryPlacements.spots_needed(id):
			assert_true(m.spots.has(sp), "%s has spot %s" % [id, sp])

func test_weda_rests_next_to_the_spring() -> void:
	var m: MapData = MapData.load_map("madderby")
	var weda: Vector2i = m.spots["weda"]
	assert_ne(m.heal_point, Vector2i(-1, -1))
	assert_lte(absi(m.heal_point.x - weda.x) + absi(m.heal_point.y - weda.y), 1)

func _gate_flags(id: String) -> Array:
	var out: Array = []
	for b: Dictionary in MapData.load_map(id).blocks:
		out.append(str(b.get("open_flag", "")))
	return out

func test_the_way_opens_in_story_order() -> void:
	assert_has(_gate_flags("corvane_quay"), "madderby_road_open")
	assert_has(_gate_flags("madderby"), "guild_joined")
	assert_has(_gate_flags("stillwater"), "beat_story_kestra_2")
	assert_has(_gate_flags("greyreach"), "beat_veit_1")

func test_quay_leads_north_to_madderby() -> void:
	var to: Array = MapData.load_map("corvane_quay").warps.map(func(w: Dictionary) -> String: return str(w.to))
	assert_has(to, "madderby")

func test_rings_follow_the_story_levels() -> void:
	for id: String in RINGS:
		var t: Dictionary = EncounterTable.table(id)
		assert_false(t.is_empty(), id)
		for s: Dictionary in t.get("spawns", []):
			assert_between(int(s.min), int(RINGS[id][0]), int(RINGS[id][1]), "%s %s" % [id, s.species])
			assert_between(int(s.max), int(RINGS[id][0]), int(RINGS[id][1]), "%s %s" % [id, s.species])
