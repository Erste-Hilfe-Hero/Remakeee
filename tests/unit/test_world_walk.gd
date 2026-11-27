extends GutTest
## Runtime walk through every warp (map pass 1.3.2): the real Overworld loads each map, the
## player goes through each warp with Overworld._warp (the code a step onto a warp runs), lands
## on free floor (no wall, no person standing there, a way to step on), and for every door,
## stairs or Rift warp walks back: a path from the landing to the warp home exists and taking
## it lands in front of the door the player came through.
## All gear is owned and every puzzle block is open, so only the maps themselves can fail.

const TEST_SLOT: String = "user://test_world_walk_save.json"

var _old_slot: String
var _old_scale: float
## The map the last warp started on (a gate keeper on the landing was passed on the way there).
var _came_from: String = ""

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_old_slot = SaveManager.slot_path
	SaveManager.slot_path = TEST_SLOT
	_old_scale = Engine.time_scale
	Engine.time_scale = 20.0

func after_each() -> void:
	SaveManager.slot_path = _old_slot
	Engine.time_scale = _old_scale
	if FileAccess.file_exists(TEST_SLOT):
		DirAccess.remove_absolute(TEST_SLOT)

func _overworld() -> Overworld:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.reduce_motion = true
	for item: String in ["wading_boots", "climbing_pick", "grapple_line", "rope_ladder", "pry_bar", "storm_lantern", "plank_bundle"]:
		GameState.add_item(item)
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for b: Dictionary in m.blocks:
			GameState.set_flag(str(b.get("open_flag", "")))
		GameState.set_flag(Overworld.goal_flag(id))
	# Arrival scenes would wait for taps: count them as seen.
	for mid: Variant in StoryPlacements.data():
		for on: Dictionary in StoryPlacements.enter_entries(str(mid)):
			GameState.set_flag(ScenePlayer.seen_flag(str(on.get("scene", ""))))
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	return ow

## Floor the player can walk on in the loaded map (people are checked on their own).
func _floor(ow: Overworld) -> Callable:
	return func(c: Vector2i) -> bool:
		if not ow.map.in_bounds(c):
			return false
		var k: int = ow.map.kind_at(c)
		return ow.map.is_walkable(c) or TilesetFactory.GEAR_KINDS.has(k) or k == TilesetFactory.Kind.BOULDER \
			or k == TilesetFactory.Kind.PLANK or ow.map.gear_needed_at(c) != ""

func _landing_problem(ow: Overworld, to: String, cell: Vector2i) -> String:
	if ow.map == null or ow.map.id != to:
		return "is not on '%s' after the warp (on '%s')" % [to, ow.map.id if ow.map != null else "?"]
	if ow.player.cell != cell:
		return "player stands on %s, not %s" % [ow.player.cell, cell]
	if not ow.map.is_walkable(cell):
		return "lands on '%s' at %s" % [ow.map.char_at(cell), cell]
	if ow.npc_at(cell) != null and not WorldGraph.passed_keeper(ow.map, cell, _came_from, ow.npc_at(cell).definition):
		return "lands on %s at %s" % [ow.npc_at(cell).npc_id, cell]
	var floor: Callable = _floor(ow)
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if floor.call(cell + d) and ow.npc_at(cell + d) == null:
			return ""
	return "cannot take a step from %s" % cell

func _warps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in MapData.all_ids():
		var m: MapData = MapData.load_map(id)
		for w: Dictionary in m.warps:
			var c := Vector2i(int(w.x), int(w.y))
			var k: int = m.kind_at(c)
			out.append({"from": id, "warp": w, "door": k in [TilesetFactory.Kind.DOOR, TilesetFactory.Kind.STAIRS, TilesetFactory.Kind.RIFT]})
	return out

func test_every_warp_lands_on_free_floor_and_every_door_walks_back() -> void:
	var ow: Overworld = await _overworld()
	var fails: Array[String] = []
	var doors: int = 0
	var all: Array[Dictionary] = _warps()
	for e: Dictionary in all:
		var from: String = e.from
		var w: Dictionary = e.warp
		var at := Vector2i(int(w.x), int(w.y))
		var to: String = str(w.to)
		var land := Vector2i(int(w.tx), int(w.ty))
		ow.load_map(from, at, str(w.get("facing", "down")))
		_came_from = from
		await ow._warp(w)
		var why: String = _landing_problem(ow, to, land)
		if not why.is_empty():
			fails.append("%s warp %s -> %s: %s" % [from, at, to, why])
			continue
		if not e.door or to == from:
			continue
		# Walk back: a path from the landing to a warp home, then through it.
		var back: Dictionary = {}
		var route: Array[Vector2i] = []
		var homes: int = 0
		for b: Dictionary in ow.map.warps:
			if str(b.to) != from:
				continue
			homes += 1
			var bc := Vector2i(int(b.x), int(b.y))
			route = PathFinder.find(land, bc, _floor(ow)) if bc != land else [bc] as Array[Vector2i]
			if not route.is_empty():
				back = b
				break
		if homes == 0:
			continue  # the way back is no warp (cracked floor, ladder): WorldGraph follows those
		if back.is_empty():
			fails.append("%s door %s -> %s: no way back to '%s' from %s" % [from, at, to, from, land])
			continue
		ow.player.place(Vector2i(int(back.x), int(back.y)), ow.player.facing)
		_came_from = to
		await ow._warp(back)
		var home := Vector2i(int(back.tx), int(back.ty))
		why = _landing_problem(ow, from, home)
		if not why.is_empty():
			fails.append("%s door %s: walking back from %s: %s" % [from, at, to, why])
			continue
		doors += 1
	for f: String in fails:
		gut.p(f)
	assert_eq(fails.size(), 0, "warps that fail at runtime (listed above)")
	assert_gt(all.size(), 800, "every warp of every map was tried")
	assert_gt(doors, 300, "door, stairs and Rift warps walked both ways")
