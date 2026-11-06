extends GutTest
## Area 3 day plans and walks for townsfolk (items 1212-1216, 1229).

const TOWNS: Array[String] = ["brindlewick", "thornridge", "copperfold", "wrenhollow", "reedhaven"]
const DAWN: int = DayCycle.Phase.DAWN
const DAY: int = DayCycle.Phase.DAY
const DUSK: int = DayCycle.Phase.DUSK
const NIGHT: int = DayCycle.Phase.NIGHT

func before_all() -> void:
	Database.load_all()
	NpcSchedule.reset()

func _ids(defs: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for d: Dictionary in defs:
		out.append(str(d.id))
	return out

func test_place_for_follows_the_phase() -> void:
	# Item 1212.
	var def: Dictionary = {"id": "a", "x": 2, "y": 3, "facing": "down",
		"schedule": [{"phase": "dusk", "x": 5, "y": 6, "facing": "left"}, {"phase": ["night"], "away": true},
			{"phase": "dawn", "map": "elsewhere", "x": 1, "y": 1}]}
	var day: Dictionary = NpcSchedule.place_for(def, "home", DAY)
	assert_eq([day.map, day.x, day.y], ["home", 2, 3], "no entry: the home cell")
	var dusk: Dictionary = NpcSchedule.place_for(def, "home", DUSK)
	assert_eq([dusk.map, dusk.x, dusk.y, dusk.facing], ["home", 5, 6, "left"])
	assert_true(NpcSchedule.place_for(def, "home", NIGHT).is_empty(), "away at night")
	assert_eq(NpcSchedule.place_for(def, "home", DAWN).map, "elsewhere")

func test_commuters_visit_the_next_town() -> void:
	# Item 1214: Wim from Brindlewick spends dusk in Thornridge.
	var thorn: MapData = MapData.load_map("thornridge")
	assert_does_not_have(_ids(NpcSchedule.defs_for(thorn, DAY)), "wim")
	var dusk: Array[Dictionary] = NpcSchedule.defs_for(thorn, DUSK)
	assert_has(_ids(dusk), "wim")
	for d: Dictionary in dusk:
		if d.id == "wim":
			assert_eq(str(d.home), "brindlewick")
			assert_eq(str(d.dialogue), "brindlewick/wim")
	var brindle: MapData = MapData.load_map("brindlewick")
	assert_has(_ids(NpcSchedule.defs_for(brindle, DAY)), "wim")
	assert_does_not_have(_ids(NpcSchedule.defs_for(brindle, DUSK)), "wim")
	assert_does_not_have(_ids(NpcSchedule.defs_for(brindle, NIGHT)), "wim")

func test_every_town_has_six_planned_people_two_commuting() -> void:
	# Item 1214.
	for town: String in TOWNS:
		var planned: Dictionary = {}
		var commuters: Dictionary = {}
		for v: Array in NpcSchedule.visitors(town):
			planned[v[1].id] = true
			commuters[v[1].id] = true
		for def: Dictionary in MapData.load_map(town).npcs:
			if not NpcSchedule.has_plan(def):
				continue
			planned[def.id] = true
			for e: Dictionary in def.get("schedule", []):
				if e.has("map") and str(e.map) != town:
					commuters[def.id] = true
		assert_gte(planned.size(), 6, "%s has six people with a day plan" % town)
		assert_gte(commuters.size(), 2, "%s has two commuters" % town)

func test_lines_change_after_the_rift() -> void:
	# Item 1215: a different line once the nearby Rift is sealed (area 4 flags).
	var entry: Dictionary = Dialogue.get_entry("copperfold/hask")
	var before: Array[String] = Dialogue.lines_for(entry, {})
	var after: Array[String] = Dialogue.lines_for(entry, {"rift_cinder_sealed": true})
	assert_false(before.is_empty())
	assert_ne(before, after)
	var tide: Dictionary = Dialogue.get_entry("reedhaven/gunn")
	assert_ne(Dialogue.lines_for(tide, {}), Dialogue.lines_for(tide, {"rift_tide_sealed": true}))

func test_walk_goes_there_and_back_and_waits() -> void:
	# Item 1213.
	var n := NPC.new()
	add_child_autofree(n)
	n.setup({"id": "w", "x": 1, "y": 1, "walk": [[1, 1], [2, 1], [3, 1]]})
	var free: Callable = func(_c: Vector2i) -> bool: return true
	var path: Array[Vector2i] = []
	for i: int in 4:
		assert_true(n.walk_tick(free))
		n.place(n.cell)
		path.append(n.cell)
	assert_eq(path, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1)] as Array[Vector2i])
	var blocked: Callable = func(_c: Vector2i) -> bool: return false
	assert_false(n.walk_tick(blocked), "waits when someone is in the way")
	assert_eq(n.cell, Vector2i(1, 1))

func test_validator_catches_bad_plans() -> void:
	# Item 1216: a plan may never stand on a warp, a door or a puzzle block for good.
	var errors: PackedStringArray = []
	WorldValidator.check_schedules(errors, MapData.all_ids())
	assert_eq(errors.size(), 0, "\n".join(errors))
	var m: MapData = MapData.load_map("brindlewick")
	assert_eq(WorldValidator._plan_cell_problem(m, Vector2i(3, 11), []), "is a warp")
	assert_eq(WorldValidator._plan_cell_problem(m, Vector2i(0, 0), []), "is not floor")
	assert_eq(WorldValidator._plan_cell_problem(m, Vector2i(8, 12), [Vector2i(8, 12)]), "is where the player arrives")
	assert_eq(WorldValidator._plan_cell_problem(m, Vector2i(1, 6), []), "")

func test_every_plan_cell_is_floor() -> void:
	# Item 1229: every place of every day plan lies on walkable ground.
	for town: String in TOWNS:
		for def: Dictionary in MapData.load_map(town).npcs:
			if not NpcSchedule.has_plan(def):
				continue
			for phase: int in 4:
				var p: Dictionary = NpcSchedule.place_for(def, town, phase)
				if p.is_empty():
					continue
				var tm: MapData = MapData.load_map(str(p.map))
				assert_true(tm.is_walkable(Vector2i(int(p.x), int(p.y))), "%s/%s at %s" % [town, def.id, DayCycle.phase_name(phase)])
				for c: Vector2i in p.walk:
					assert_true(tm.is_walkable(c), "%s/%s walk %s" % [town, def.id, c])
