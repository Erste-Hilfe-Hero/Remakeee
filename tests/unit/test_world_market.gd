extends GutTest
## Area 3 item 959: on Wednesday and Saturday (device clock) three extra stalls stand in
## Brindlewick's market.

const STALLS: Array[String] = ["stall_fish", "stall_herbs", "stall_tinker"]

func before_all() -> void:
	Database.load_all()

func _stall_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in MapData.load_map("brindlewick").npcs:
		if str(def.id) in STALLS:
			out.append(def)
	return out

func test_three_stalls_with_shops() -> void:
	var defs: Array[Dictionary] = _stall_defs()
	assert_eq(defs.size(), 3)
	for def: Dictionary in defs:
		var e: Dictionary = Dialogue.get_entry(str(def.dialogue))
		var act: PackedStringArray = str(e.get("action", "")).split(" ")
		assert_eq(act[0], "shop", str(def.id))
		for i: int in range(1, act.size()):
			assert_gt(int(Database.item(act[i]).get("price", 0)), 0, act[i] + " has a price")

func test_stalls_stand_on_wednesday_and_saturday_only() -> void:
	for def: Dictionary in _stall_defs():
		for wd: int in 7:
			assert_eq(DayCycle.on_weekday(def, wd), wd == 3 or wd == 6, "%s on weekday %d" % [def.id, wd])

func test_plain_people_stand_every_day() -> void:
	for wd: int in 7:
		assert_true(DayCycle.on_weekday({"id": "x"}, wd))

func test_weekday_from_unix_time() -> void:
	var keep: int = DayCycle.shift()
	GameState.records["clock_shift"] = 0
	assert_eq(DayCycle.weekday(0), 4, "1 Jan 1970 was a Thursday")
	assert_eq(DayCycle.weekday(86400 * 6), 3, "7 Jan 1970 was a Wednesday")
	GameState.records["clock_shift"] = keep
