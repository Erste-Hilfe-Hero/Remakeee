extends GutTest
## Area 3 items 1084, 1085: twelve cartographer's stones in Veydal, keepsakes at 4, 8 and 12.

var _flags: Dictionary
var _inv: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_flags = GameState.flags.duplicate()
	_inv = GameState.inventory.duplicate()
	for n: int in range(1, MarkerStones.TOTAL + 1):
		GameState.flags.erase(MarkerStones.flag(n))

func after_each() -> void:
	GameState.flags = _flags
	GameState.inventory = _inv

func _stones() -> Dictionary:
	var out: Dictionary = {}
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for s: Dictionary in m.signs:
			var e: Dictionary = Dialogue.get_entry(str(s.get("dialogue", "")))
			var act: PackedStringArray = str(e.get("action", "")).split(" ")
			if act.size() == 2 and act[0] == "marker_stone":
				out[int(act[1])] = id
	return out

func test_twelve_stones_one_per_outdoor_veydal_map() -> void:
	var stones: Dictionary = _stones()
	assert_eq(stones.size(), MarkerStones.TOTAL)
	var maps: Dictionary = {}
	for n: int in stones:
		assert_between(n, 1, MarkerStones.TOTAL)
		var m: MapData = MapData.load_map(stones[n])
		assert_eq(m.region, "veydal", stones[n])
		assert_true(m.outdoor, stones[n])
		maps[stones[n]] = true
	assert_eq(maps.size(), MarkerStones.TOTAL, "one stone per map")

func test_keepsakes_at_four_eight_and_twelve() -> void:
	var got: Array[String] = []
	for n: int in range(1, MarkerStones.TOTAL + 1):
		var r: Dictionary = MarkerStones.visit(n)
		assert_true(r.new)
		assert_eq(r.found, n)
		if not str(r.reward).is_empty():
			got.append(str(r.reward))
	assert_eq(got, ["iron_burr", "keen_lens", "bark_wrap"] as Array[String])
	for id: String in got:
		assert_true(BattleRules.is_holdable(id), id)
	assert_false(MarkerStones.visit(3).new, "a stone counts once")
	assert_eq(MarkerStones.visit(3).reward, "")
