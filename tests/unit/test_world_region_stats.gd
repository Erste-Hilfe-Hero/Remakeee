extends GutTest
## Area 3 item 1096: finds and secrets in total per region, for the records.

func test_every_region_has_finds() -> void:
	var t: Dictionary = RegionStats.totals({})
	for r: String in ["veydal", "corvane", "ashmere"]:
		assert_true(t.has(r), r)
		assert_gt((t[r].finds as Vector2i).y, 0, r + " has hidden finds")
		assert_eq((t[r].finds as Vector2i).x, 0, "nothing taken on a fresh save")

func test_marker_stones_count_as_secrets() -> void:
	var t: Dictionary = RegionStats.totals({})
	assert_gte((t.veydal.secrets as Vector2i).y, MarkerStones.TOTAL, "12 stones plus the passages")
	var after: Dictionary = RegionStats.totals({MarkerStones.flag(1): true, MarkerStones.flag(5): true})
	assert_eq((after.veydal.secrets as Vector2i).x, 2)

func test_taken_find_is_counted() -> void:
	var m: MapData = MapData.load_map("quillbrook")
	assert_false(m.secrets.is_empty())
	var flag: String = str(m.secrets[0].flag)
	var t: Dictionary = RegionStats.totals({flag: true})
	assert_eq((t[m.region].finds as Vector2i).x, 1)

func test_lines_name_regions() -> void:
	var l: Array[String] = RegionStats.lines({})
	assert_true("Veydal" in l)
	assert_true(l.any(func(s: String) -> bool: return s.contains("Finds: 0/")))
