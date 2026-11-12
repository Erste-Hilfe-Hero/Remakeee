extends GutTest
## Map design plan items 508, 509: every act looks different. Each outdoor place of Acts I-III
## has a landmark from its own act's set, and the Corvane and Ashmere roads wind instead of
## running straight down the middle.

## Outdoor places of Acts I-III (Solenne gets its landmarks with its own look).
const PLACES: Array[String] = ["brindlewick", "brackwater_fen", "copperfold", "crowcrest", "fernstair",
	"gloamwood", "lantern_steps", "quillbrook", "reedhaven", "saltmarsh", "thornridge", "wrenhollow",
	"corvane_quay", "madderby", "stillwater", "woadfen", "greyreach",
	"ashmere_station", "cinderfold", "saltglass"]
## Reworked road layouts (item 508): no straight run longer than this share of the map height.
const WINDING: Array[String] = ["madderby", "corvane_quay", "stillwater", "saltglass"]
const MAX_STRAIGHT: float = 0.45

func before_all() -> void:
	Database.load_all()

func test_every_place_has_a_landmark_of_its_own_act() -> void:
	for id: String in PLACES:
		var lm: Dictionary = Landmarks.for_map(id)
		assert_false(lm.is_empty(), "%s has a landmark" % id)
		var m: MapData = MapData.load_map(id)
		assert_eq(Landmarks.region_of(str(lm.get("kind", ""))), m.region, "%s: landmark from %s's own set" % [id, m.region])

func test_no_landmark_kind_is_shared_between_acts() -> void:
	var owner: Dictionary = {}
	for r: String in Landmarks.KINDS:
		for k: String in Landmarks.KINDS[r]:
			assert_false(owner.has(k), "%s drawn by %s and %s" % [k, owner.get(k, ""), r])
			owner[k] = r

func test_each_act_uses_at_least_three_kinds() -> void:
	var used: Dictionary = {}
	for id: String in Landmarks.all():
		var kind: String = str(Landmarks.for_map(id).kind)
		var r: String = Landmarks.region_of(kind)
		if not used.has(r):
			used[r] = {}
		used[r][kind] = true
	for r: String in ["veydal", "corvane", "ashmere"]:
		assert_gte((used.get(r, {}) as Dictionary).size(), 3, "%s shows at least 3 kinds of landmark" % r)

func test_landmark_art_exists_for_every_kind() -> void:
	for r: String in Landmarks.KINDS:
		for k: String in Landmarks.KINDS[r]:
			var path: String = Landmarks.art_path("%s_%s" % [r, k])
			assert_false(path.is_empty(), "%s_%s has art" % [r, k])
			var tex: Texture2D = load(path)
			assert_eq(tex.get_size(), Vector2(16, 32), "%s_%s is 16x32" % [r, k])

func test_landmarks_pass_the_validator() -> void:
	var errors := PackedStringArray()
	WorldValidator.check_landmarks(errors, MapData.all_ids())
	assert_eq(errors, PackedStringArray())

func test_reading_a_landmark_gives_name_and_line() -> void:
	var lm: Dictionary = Landmarks.for_map("madderby")
	var lines: Array[String] = Landmarks.lines_at("madderby", Landmarks.cell(lm))
	assert_eq(lines.size(), 2)
	assert_eq(Landmarks.lines_at("madderby", Landmarks.cell(lm) + Vector2i.LEFT), [] as Array[String])
	assert_eq(Landmarks.lines_at("nowhere", Vector2i.ZERO), [] as Array[String])

func test_landmark_names_and_lines_have_german() -> void:
	var de: Dictionary = {}
	var f: FileAccess = FileAccess.open("res://data/i18n/de/landmarks.json", FileAccess.READ)
	assert_not_null(f)
	if f != null:
		de = (JSON.parse_string(f.get_as_text()) as Dictionary).get("strings", {})
	for id: String in Landmarks.all():
		var lm: Dictionary = Landmarks.for_map(id)
		assert_true(de.has(str(lm.name)), "German name for %s" % id)
		assert_true(de.has(str(lm.line)), "German line for %s" % id)

func test_validator_rejects_a_landmark_on_a_walkable_or_busy_cell() -> void:
	var m: MapData = MapData.load_map("madderby")
	assert_eq(WorldValidator.landmark_cell_problem(m, Vector2i(9, 3)), "on a sign")
	assert_eq(WorldValidator.landmark_cell_problem(m, Vector2i(5, 21)), "on a warp")
	assert_eq(WorldValidator.landmark_cell_problem(m, Vector2i(0, 14)), "on a hidden find")
	assert_eq(WorldValidator.landmark_cell_problem(m, Vector2i(11, 7)), "")

func test_corvane_and_ashmere_roads_wind() -> void:
	for id: String in WINDING:
		var m: MapData = MapData.load_map(id)
		var run: int = WorldValidator.longest_straight_path(m)
		assert_lte(float(run), m.height * MAX_STRAIGHT, "%s: longest straight road %d of %d rows" % [id, run, m.height])

func test_straight_road_counter() -> void:
	var m: MapData = MapData.from_dict("t", {"rows": ["._..", "._..", "._+.", "...+"]})
	assert_eq(WorldValidator.longest_straight_path(m), 3)
