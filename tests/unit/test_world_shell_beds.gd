extends GutTest
## Area 3 item 995: shell beds in Sablecove give a find at low tide and are gone at high tide.

func test_shell_beds_only_at_low_tide() -> void:
	var m: MapData = MapData.load_map("sablecove")
	var beds: Array = m.secrets.filter(func(sc: Dictionary) -> bool: return str(sc.get("when", "")) == "_low_tide")
	assert_eq(beds.size(), 2)
	for sc: Dictionary in beds:
		var c := Vector2i(int(sc.x), int(sc.y))
		assert_true(m.secret_at(c, {}).is_empty(), "under water at high tide")
		assert_false(m.secret_at(c, {"_low_tide": true}).is_empty(), "on the sand at low tide")
		assert_true(m.secret_at(c, {"_low_tide": true, str(sc.flag): true}).is_empty(), "taken once")

func test_plain_finds_ignore_the_tide() -> void:
	var m: MapData = MapData.load_map("sablecove")
	assert_false(m.secret_at(Vector2i(1, 1), {}).is_empty())
