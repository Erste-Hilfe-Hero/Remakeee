extends GutTest
## Area 3 new routes and settlements (items 914 to 920, 950 to 954, 1082, 1108, 1112, 1113).

const ROUTES: Array[String] = ["gloamwood", "quillbrook", "brackwater_fen", "lantern_steps"]
const TOWNS: Array[String] = ["wrenhollow", "reedhaven", "copperfold"]
const RINGS: Dictionary = {"gloamwood": [4, 7], "quillbrook": [8, 11], "brackwater_fen": [12, 15], "lantern_steps": [10, 13]}

func before_all() -> void:
	Database.load_all()

func test_routes_have_wayfarers_finds_passage_and_table() -> void:
	for id: String in ROUTES:
		var m: MapData = MapData.load_map(id)
		assert_not_null(m, id)
		var wayfarers: int = 0
		for n: Dictionary in m.npcs:
			if n.has("trainer"):
				assert_eq(int(n.get("sight", 0)), 0, "%s: %s only duels when talked to" % [id, n.id])
				wayfarers += 1
		assert_gte(wayfarers, 3, id)
		assert_between(m.secrets.size(), 3, 5, id)
		assert_gte(m.passages.size(), 1, "%s has a secret passage" % id)
		assert_eq(m.encounter_table, id)
		assert_false(EncounterTable.table(id).is_empty(), id)

func test_route_rings_follow_the_plan() -> void:
	for id: String in RINGS:
		for s: Dictionary in EncounterTable.table(id).spawns:
			assert_between(int(s.min), int(RINGS[id][0]), int(RINGS[id][1]), "%s %s" % [id, s.species])
			assert_between(int(s.max), int(RINGS[id][0]), int(RINGS[id][1]), "%s %s" % [id, s.species])

func test_unfolded_forms_are_rare() -> void:
	# Item 1113: Riptail, Thornback and Smoldrake show up with weight 5 only.
	var want: Dictionary = {"brackwater_fen": "Riptail", "gloamwood": "Thornback", "kindle_vents": "Smoldrake"}
	for id: String in want:
		var found: bool = false
		for s: Dictionary in EncounterTable.table(id).spawns:
			if s.species == want[id]:
				found = true
				assert_eq(int(s.weight), 5)
		assert_true(found, "%s has %s" % [id, want[id]])

func test_base_forms_live_on_two_maps() -> void:
	# Item 1112.
	var maps: Dictionary = {}
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for id: String in raw:
		for s: Dictionary in raw[id].spawns:
			var arr: Array = maps.get(str(s.species), [])
			if not id in arr:
				arr.append(id)
			maps[str(s.species)] = arr
	for sp: String in ["Kindlop", "Puddlet", "Mossling", "Zippit", "Shalebat", "Zephlet", "Wickit", "Mirkmole", "Kelpup"]:
		assert_gte((maps.get(sp, []) as Array).size(), 2, sp)

func test_towns_have_rest_spot_and_trader() -> void:
	for id: String in TOWNS:
		var m: MapData = MapData.load_map(id)
		assert_gte(m.heal_point.x, 0, "%s has a rest spot" % id)
		var heal: bool = false
		var shop: bool = false
		for n: Dictionary in m.npcs:
			var act: String = str(Dialogue.get_entry(str(n.dialogue)).get("action", ""))
			heal = heal or act == "heal"
			shop = shop or act.begins_with("shop ")
		assert_true(heal, "%s: someone heals" % id)
		assert_true(shop, "%s: someone trades" % id)

func test_new_places_join_the_world() -> void:
	var links: Dictionary = {"fernstair": "gloamwood", "crowcrest": "gloamwood", "brindlewick": "quillbrook",
		"saltmarsh": "brackwater_fen", "thornridge": "lantern_steps"}
	for a: String in links:
		var tos: Array = MapData.load_map(a).warps.map(func(w: Dictionary) -> String: return str(w.to))
		assert_has(tos, links[a], a)

func test_passage_opens_and_stays_open() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	var m: MapData = MapData.load_map("gloamwood")
	var p: Dictionary = m.passages[0]
	var cell := Vector2i(int(p.x), int(p.y))
	ow.load_map("gloamwood", Vector2i(int(m.warps[0].x), int(m.warps[0].y)), "down")
	assert_eq(ow.map.char_at(cell), "@", "closed at first")
	assert_eq(ow.map.passage_at(cell), p)
	ow._world.open_passage(p)
	assert_true(GameState.has_flag(str(p.flag)))
	assert_ne(ow.map.char_at(cell), "@", "open now")
	ow.load_map("gloamwood", Vector2i(int(m.warps[0].x), int(m.warps[0].y)), "down")
	assert_ne(ow.map.char_at(cell), "@", "still open after coming back")

func test_spots_read_from_the_map() -> void:
	var m := MapData.from_dict("t", {"rows": ["...", "..."], "spots": {"juna": [1, 1]}})
	assert_eq(m.spot("juna"), Vector2i(1, 1))
	assert_eq(m.spot("nobody"), Vector2i(-1, -1))
	var errors := PackedStringArray()
	assert_true(WorldValidator.is_object_spot("page_7"))
	assert_false(WorldValidator.is_object_spot("juna"))
	assert_eq(errors.size(), 0)
