class_name PuzzleSolver
extends RefCounted
## Breadth-first solver for boulder rooms (area 3 item 893): finds a move list that presses
## every plate of a puzzle with boulders, using exactly the rules of PuzzleRoom.step. Used by
## WorldValidator (an unsolvable puzzle is an error) and by tests that replay the solution
## files in tests/fixtures/puzzles/.

## States explored before giving up (rooms are small; this keeps CI fast).
const MAX_STATES: int = 60000
const NAMES: Dictionary[Vector2i, String] = {Vector2i.UP: "up", Vector2i.DOWN: "down", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}

## Moves ("up", "left", ...) from [param start] that leave every plate of [param puzzle]
## under a boulder, or null if none was found. [param gear]: owned gear ids.
static func solve(m: MapData, puzzle: Dictionary, start: Vector2i, gear: Array = ["wading_boots", "climbing_pick"]) -> Variant:
	var work: MapData = _copy(m)
	var plates: Array[Vector2i] = PuzzleRoom.plates(work, puzzle)
	if plates.is_empty():
		return null
	var first: Array[Vector2i] = PuzzleRoom.boulders(work)
	var key0: String = _key(start, first)
	var came: Dictionary = {key0: null}
	var queue: Array = [[start, first]]
	var head: int = 0
	while head < queue.size():
		var cur: Array = queue[head]
		head += 1
		var pc: Vector2i = cur[0]
		var bs: Array[Vector2i] = cur[1]
		if _all_pressed(plates, bs):
			return _path(came, _key(pc, bs))
		if came.size() > MAX_STATES:
			return null
		for d: Vector2i in PuzzleRoom.DIRS:
			PuzzleRoom.set_boulders(work, bs)
			var np: Vector2i = PuzzleRoom.step(work, pc, d, gear)
			if np == pc:
				continue
			var nb: Array[Vector2i] = PuzzleRoom.boulders(work)
			var k: String = _key(np, nb)
			if came.has(k):
				continue
			came[k] = [_key(pc, bs), NAMES[d]]
			queue.append([np, nb])
	return null

## Plays [param moves] from [param start] on a copy of [param m]; returns the copy so tests
## can look at the boulders afterwards.
static func replay(m: MapData, start: Vector2i, moves: Array, gear: Array = ["wading_boots", "climbing_pick"]) -> Dictionary:
	var work: MapData = _copy(m)
	var pc: Vector2i = start
	for mv: Variant in moves:
		var d: Vector2i = GridWalker.DIRS.get(str(mv), Vector2i.ZERO)
		pc = PuzzleRoom.step(work, pc, d, gear)
	return {"map": work, "cell": pc}

static func _all_pressed(plates: Array[Vector2i], boulders: Array[Vector2i]) -> bool:
	for p: Vector2i in plates:
		if not p in boulders:
			return false
	return true

static func _key(p: Vector2i, bs: Array[Vector2i]) -> String:
	var parts: PackedStringArray = ["%d,%d" % [p.x, p.y]]
	for b: Vector2i in bs:
		parts.append("%d,%d" % [b.x, b.y])
	return "|".join(parts)

static func _path(came: Dictionary, end: String) -> Array:
	var out: Array = []
	var k: String = end
	while came[k] != null:
		var prev: Array = came[k]
		out.push_front(prev[1])
		k = prev[0]
	return out

static func _copy(m: MapData) -> MapData:
	var c := MapData.new()
	c.id = m.id
	c.rows = m.rows.duplicate()
	c._base_rows = m._base_rows.duplicate()
	c.width = m.width
	c.height = m.height
	c.warps = m.warps
	c.puzzles = m.puzzles
	c.boulder_ground = m.boulder_ground
	return c
