extends GutTest
## Area 3 item 965: the Wrenhollow library. Its books hint at hidden places, bound to the
## flags of those places, not to quest texts.

func before_all() -> void:
	Database.load_all()

func test_door_leads_in_and_out() -> void:
	var town: MapData = MapData.load_map("wrenhollow")
	var into: Dictionary = town.warp_at(Vector2i(3, 13))
	assert_eq(str(into.get("to", "")), "wren_library")
	var lib: MapData = MapData.load_map("wren_library")
	assert_true(lib.is_walkable(Vector2i(int(into.tx), int(into.ty))), "arrival inside is floor")
	var out: Dictionary = lib.warp_at(Vector2i(3, 7))
	assert_eq(str(out.get("to", "")), "wrenhollow")

func test_books_follow_the_flags_of_their_places() -> void:
	var lib: MapData = MapData.load_map("wren_library")
	assert_eq(lib.signs.size(), 4)
	for s: Dictionary in lib.signs:
		var e: Dictionary = Dialogue.get_entry(str(s.dialogue))
		var flag: String = str(e.after_flag.flag)
		var before: Array[String] = Dialogue.lines_for(e, {})
		var after: Array[String] = Dialogue.lines_for(e, {flag: true})
		assert_eq(before.size(), 1, str(s.dialogue))
		assert_eq(after.size(), 2, "a tick once %s is found" % flag)
		assert_false(flag.begins_with("quest"), "bound to a place, not a quest")
