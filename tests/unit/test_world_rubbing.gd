extends GutTest
## Area 3 items 1051, 1088: the Rubbing Charcoal reads weathered stones on five burial
## mounds; each inscription points to a hidden find close by.

const MOUNDS: Dictionary = {"stillwater": [Vector2i(11, 8), Vector2i(9, 6)], "quillbrook": [Vector2i(3, 15), Vector2i(1, 15)],
	"fernstair": [Vector2i(1, 20), Vector2i(2, 22)], "crowcrest": [Vector2i(11, 12), Vector2i(10, 10)],
	"greyreach": [Vector2i(0, 22), Vector2i(3, 24)]}

func before_all() -> void:
	Database.load_all()

func test_charcoal_is_gear_with_a_giver() -> void:
	var it: Dictionary = Database.item(Overworld.RUBBING_ITEM)
	assert_true(bool(it.get("gear", false)))
	assert_true(str(it.description).begins_with("Wayfarer Gear"))
	assert_true(str(Dialogue.get_entry("gloamwood/charcoaler").get("action", "")).begins_with("give_item rubbing_charcoal"))
	var m: MapData = MapData.load_map("gloamwood")
	var found: bool = false
	for n: Dictionary in m.npcs:
		found = found or str(n.id) == "charcoaler"
	assert_true(found, "the charcoal burner stands in Gloamwood")

func test_five_mounds_point_to_finds() -> void:
	var n: int = 0
	for mid: String in MOUNDS:
		n += 1
		var m: MapData = MapData.load_map(mid)
		var s: Dictionary = m.sign_at(MOUNDS[mid][0])
		assert_eq(str(s.get("dialogue", "")), mid + "/mound_stone", mid)
		assert_eq(str(Dialogue.get_entry(mid + "/mound_stone").get("action", "")), "rubbing %s/mound_words" % mid)
		var sc: Dictionary = m.secret_at(MOUNDS[mid][1], {})
		assert_eq(str(sc.get("flag", "")), "find_mound_%d" % n, mid + " has the find the stone points to")
		assert_true(m.is_walkable(MOUNDS[mid][1]), mid + " find is on open ground")

func test_inscription_needs_the_charcoal() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var plain: Array[String] = Overworld.rubbing_lines("stillwater/mound_words")
	assert_eq(plain.size(), 1, "without charcoal the letters stay worn")
	GameState.add_item(Overworld.RUBBING_ITEM, 1)
	var read: Array[String] = Overworld.rubbing_lines("stillwater/mound_words")
	assert_gt(read.size(), 1, "with charcoal the inscription appears")
	assert_true(read[1].contains("west"), read[1])
