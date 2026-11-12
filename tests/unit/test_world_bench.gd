extends GutTest
## Area 3 item 935: the bench on the Quillbrook fishing pier moves the clock to the next time of day.

var _saved: Variant

func before_each() -> void:
	_saved = GameState.records.get("clock_shift")
	GameState.records.erase("clock_shift")

func after_each() -> void:
	if _saved == null:
		GameState.records.erase("clock_shift")
	else:
		GameState.records["clock_shift"] = _saved

func test_hours_to_next_phase() -> void:
	assert_eq(DayCycle.hours_to_next(5), 2, "dawn 5-7")
	assert_eq(DayCycle.hours_to_next(12), 6, "day until 18")
	assert_eq(DayCycle.hours_to_next(19), 1, "dusk until 20")
	assert_eq(DayCycle.hours_to_next(22), 7, "night until 5")

func test_skip_moves_through_all_phases() -> void:
	assert_eq(DayCycle.skip_to_next(12), DayCycle.Phase.DUSK)
	assert_eq(DayCycle.shift(), 6)
	assert_eq(DayCycle.skip_to_next(12), DayCycle.Phase.NIGHT)
	assert_eq(DayCycle.skip_to_next(12), DayCycle.Phase.DAWN)
	assert_eq(DayCycle.skip_to_next(12), DayCycle.Phase.DAY)
	assert_eq(DayCycle.shift(), 19, "game clock now at 7, the start of day")

func test_bench_on_the_pier() -> void:
	var m: MapData = MapData.load_map("quillbrook")
	var s: Dictionary = m.sign_at(Vector2i(4, 5))
	assert_eq(str(s.get("dialogue", "")), "quillbrook/bench")
	assert_eq(m.kind_at(Vector2i(5, 5)), TilesetFactory.Kind.PIER)
	var e: Dictionary = Dialogue.get_entry("quillbrook/bench")
	assert_true((e.choices as Array).any(func(c: Dictionary) -> bool: return str(c.get("action", "")) == "bench"))
