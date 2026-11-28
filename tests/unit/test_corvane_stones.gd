extends GutTest
## Plan item 1312: twelve cartographer's stones in Corvane, counted apart from Veydal's, with
## keepsakes at 4, 8 and 12; and at least fifteen hidden finds in Corvane.

var _flags: Dictionary
var _inv: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_inv = GameState.inventory.duplicate()
	for n: int in range(1, MarkerStones.TOTAL + 1):
		GameState.flags.erase(MarkerStones.flag(n, "corvane"))

func after_each() -> void:
	GameState.flags = _flags
	GameState.inventory = _inv

func _corvane_stones() -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for s: Dictionary in m.signs:
			var act: PackedStringArray = str(Dialogue.get_entry(str(s.get("dialogue", ""))).get("action", "")).split(" ")
			if act.size() == 3 and act[0] == "marker_stone" and act[2] == "corvane":
				out[int(act[1])] = id
	return out

func test_twelve_stones_in_corvane() -> void:
	var stones: Dictionary = _corvane_stones()
	assert_eq(stones.size(), MarkerStones.TOTAL)
	for n: int in stones:
		assert_between(n, 1, MarkerStones.TOTAL)
		assert_eq(MapData.load_map(stones[n]).region, "corvane", stones[n])

func test_corvane_stones_count_apart_from_veydal() -> void:
	assert_ne(MarkerStones.flag(3, "corvane"), MarkerStones.flag(3))
	var got: Array[String] = []
	for n: int in range(1, MarkerStones.TOTAL + 1):
		var r: Dictionary = MarkerStones.visit(n, "corvane")
		assert_true(r.new)
		assert_eq(r.found, n)
		if not str(r.reward).is_empty():
			got.append(str(r.reward))
	assert_eq(got.size(), 3)
	for id: String in got:
		assert_true(BattleRules.is_holdable(id), id)
	assert_false(MarkerStones.visit(3, "corvane").new, "a stone counts once")

func test_region_stats_count_corvane_stones() -> void:
	var t: Dictionary = RegionStats.totals({MarkerStones.flag(2, "corvane"): true})
	assert_gte((t.corvane.secrets as Vector2i).y, MarkerStones.TOTAL)
	assert_eq((t.corvane.secrets as Vector2i).x, 1)
	assert_gte((t.corvane.finds as Vector2i).y, 15, "fifteen hidden finds in Corvane")
