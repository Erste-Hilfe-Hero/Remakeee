extends GutTest
## Rustling spots (era function "rustling_spots", Era V): one shaking patch per map and day.

const MAP: String = "breathing_bog"
const DAY: String = "2026-11-12"

func _map() -> MapData:
	return MapData.load_map(MAP)

func test_spot_is_encounter_ground_and_stable() -> void:
	var m: MapData = _map()
	assert_not_null(m)
	var c: Vector2i = RustleSpots.spot(m, DAY)
	assert_true(c.x >= 0, "the bog has a spot")
	assert_true(m.kind_at(c) in TilesetFactory.ENCOUNTER_KINDS)
	assert_eq(RustleSpots.spot(m, DAY), c, "same spot all day for everyone")

func test_spot_moves_between_days() -> void:
	var m: MapData = _map()
	var seen: Dictionary = {}
	for d: int in range(1, 11):
		seen[RustleSpots.spot(m, "2026-11-%02d" % d)] = true
	assert_gt(seen.size(), 1)

func test_only_from_era_five() -> void:
	var m: MapData = _map()
	var c: Vector2i = RustleSpots.spot(m, DAY)
	assert_false(RustleSpots.due(m, c, DAY, {}, 4))
	assert_true(RustleSpots.due(m, c, DAY, {}, 5))
	assert_false(RustleSpots.due(m, c + Vector2i(99, 0), DAY, {}, 5), "only the spot itself")

func test_used_once_per_map_and_day() -> void:
	var m: MapData = _map()
	var rec: Dictionary = {}
	var c: Vector2i = RustleSpots.spot(m, DAY)
	RustleSpots.mark_done(rec, m.id, DAY)
	assert_false(RustleSpots.active(m, DAY, rec, 5))
	assert_true(RustleSpots.active(m, "2026-11-13", rec, 5), "a new day shakes again")
	assert_false(RustleSpots.due(m, c, DAY, rec, 5))

func test_indoor_maps_have_none() -> void:
	var m := MapData.new()
	m.id = "room"
	m.outdoor = false
	assert_eq(RustleSpots.spot(m, DAY), Vector2i(-1, -1))
	assert_false(RustleSpots.active(m, DAY, {}, 5))

func test_rare_spirling_rings_higher() -> void:
	var m: MapData = _map()
	var best: Dictionary = RustleSpots.rarest(m.encounter_table)
	assert_false(best.is_empty())
	for s: Dictionary in EncounterTable.spawns_on(m.encounter_table, ""):
		assert_true(int(s.get("weight", 1)) >= int(best.get("weight", 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wild: Spirling = RustleSpots.make_wild(m.encounter_table, rng)
	assert_not_null(wild)
	assert_eq(wild.data.species_name, str(best.species))
	assert_eq(wild.level, int(best.get("max", 4)) + RustleSpots.RING_BONUS)

func test_line_has_german() -> void:
	var de: Dictionary = Loc.load_table("de").get("strings", {})
	assert_true(de.has(RustleSpots.LINE))
