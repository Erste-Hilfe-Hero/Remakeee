class_name PuzzleRoom
extends RefCounted
## Puzzle rules shared by the overworld, the validator and the tests (area 3 items 1011 to 1014):
## boulders "B" that slide one cell when pushed, pressure plates "P" held down by a boulder or
## the player, cracked floor "k" that gives way once you step off it, and plank gaps "Y".
##
## A map lists its puzzles under "puzzles": [{"id", "flag", "plates": [[x, y], ...]}]. While
## every plate of a puzzle is pressed, its flag counts as set for the map's blocks
## ("open_flag"), so a door stays open as long as the boulders hold the plates down. Boulder
## positions, broken floor and laid planks live in GameState.world_state, so they survive saving.
## Without "plates", a puzzle uses every "P" on the map.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## Tile a boulder or a broken cell leaves behind when it was drawn on the map from the start.
static func ground_char(m: MapData) -> String:
	return m.boulder_ground

## The map character under [param cell] without any boulder: the base tile, or the map's
## boulder ground where a boulder started.
static func under(m: MapData, cell: Vector2i) -> String:
	var ch: String = m.base_char(cell)
	return ground_char(m) if ch == "B" else ch

## Current boulder cells (from the rows).
static func boulders(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in m.height:
		for x: int in m.rows[y].length():
			if m.rows[y][x] == "B":
				out.append(Vector2i(x, y))
	return out

## Boulder cells as drawn in the map file.
static func start_boulders(m: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in m.height:
		for x: int in m.base_row(y).length():
			if m.base_row(y)[x] == "B":
				out.append(Vector2i(x, y))
	return out

## Moves the boulders to [param cells] (same count as on the map).
static func set_boulders(m: MapData, cells: Array) -> void:
	for c: Vector2i in boulders(m):
		m.set_char(c, under(m, c))
	for v: Variant in cells:
		var c: Vector2i = v if v is Vector2i else Vector2i(int(v[0]), int(v[1]))
		if m.in_bounds(c):
			m.set_char(c, "B")

## True if a boulder can slide into [param cell]: plain ground or a plate, not a warp, not an
## exit and no other boulder. [param blocked] can add NPC cells.
static func can_take_boulder(m: MapData, cell: Vector2i, blocked: Dictionary = {}) -> bool:
	if not m.in_bounds(cell) or blocked.has(cell) or not m.warp_at(cell).is_empty():
		return false
	var k: int = m.kind_at(cell)
	if k == TilesetFactory.Kind.CRACKED or TilesetFactory.is_solid(k) or k == TilesetFactory.Kind.DOOR:
		return false
	return k != TilesetFactory.Kind.STAIRS

## Pushes the boulder at [param at] one cell along [param dir]. Returns true if it moved.
static func push(m: MapData, at: Vector2i, dir: Vector2i, blocked: Dictionary = {}) -> bool:
	if m.char_at(at) != "B" or not can_take_boulder(m, at + dir, blocked):
		return false
	m.set_char(at, under(m, at))
	m.set_char(at + dir, "B")
	return true

## Plate cells of [param puzzle].
static func plates(m: MapData, puzzle: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if puzzle.has("plates"):
		for p: Variant in puzzle.plates:
			out.append(Vector2i(int(p[0]), int(p[1])))
		return out
	for y: int in m.height:
		for x: int in m.base_row(y).length():
			if m.base_row(y)[x] == "P":
				out.append(Vector2i(x, y))
	return out

## True while every plate of [param puzzle] has a boulder or the player on it.
static func pressed(m: MapData, puzzle: Dictionary, player: Vector2i = Vector2i(-1, -1)) -> bool:
	var ps: Array[Vector2i] = plates(m, puzzle)
	if ps.is_empty():
		return false
	for p: Vector2i in ps:
		if m.char_at(p) != "B" and p != player:
			return false
	return true

## [param flags] plus the flag of every puzzle whose plates are all pressed right now.
static func live_flags(m: MapData, flags: Dictionary, player: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if m.puzzles.is_empty():
		return flags
	var out: Dictionary = flags.duplicate()
	for p: Dictionary in m.puzzles:
		if pressed(m, p, player):
			out[str(p.get("flag", ""))] = true
	return out

# --- Saved state (GameState.world_state[map id]) -------------------------------------------

static func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Variant in list:
		out.append(Vector2i(int(v[0]), int(v[1])))
	return out

static func _pairs(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append([c.x, c.y])
	return out

## Applies saved state to [param m]: boulder cells, broken floor, laid planks, hung ladders.
static func apply_state(m: MapData, state: Dictionary) -> void:
	if state.has("boulders") and (state.boulders as Array).size() == start_boulders(m).size():
		set_boulders(m, _cells(state.boulders))
	for c: Vector2i in _cells(state.get("broken", [])):
		if m.in_bounds(c):
			m.set_char(c, "Y")
	for c: Vector2i in _cells(state.get("planks", [])):
		if m.in_bounds(c):
			m.set_char(c, "+")

## The state to save for [param m] after a push, a break or a plank; merged into [param state].
static func capture(m: MapData, state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var now: Array[Vector2i] = boulders(m)
	if now != start_boulders(m):
		out["boulders"] = _pairs(now)
	else:
		out.erase("boulders")
	return out

## Cracked floor: after the player steps off [param cell], it breaks.
static func break_floor(m: MapData, state: Dictionary, cell: Vector2i) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var broken: Array = out.get("broken", [])
	if not _has_cell(broken, cell):
		broken.append([cell.x, cell.y])
	out["broken"] = broken
	m.set_char(cell, "Y")
	return out

static func is_broken(state: Dictionary, cell: Vector2i) -> bool:
	return _has_cell(state.get("broken", []), cell)

## [x, y] pairs from a save may come back as floats, so compare as whole numbers.
static func _has_cell(list: Array, cell: Vector2i) -> bool:
	for v: Variant in list:
		if int(v[0]) == cell.x and int(v[1]) == cell.y:
			return true
	return false

## Lays a plank over the gap at [param cell] (Plank Bundle). It stays for good.
static func lay_plank(m: MapData, state: Dictionary, cell: Vector2i) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	var planks: Array = out.get("planks", [])
	if not _has_cell(planks, cell):
		planks.append([cell.x, cell.y])
	out["planks"] = planks
	m.set_char(cell, "+")
	return out

## A room reset (menu "Reset room", item 1014): boulders go back to the start. Broken floor
## and planks stay, they are not part of the puzzle.
static func reset(m: MapData, state: Dictionary) -> Dictionary:
	var out: Dictionary = state.duplicate(true)
	out.erase("boulders")
	set_boulders(m, start_boulders(m))
	return out

# --- One step, as the overworld does it -----------------------------------------------------

## Moves the player one cell along [param dir] from [param from], pushing a boulder if one is
## in the way. Returns the new player cell (unchanged if the way is blocked). Gear in
## [param gear] (item ids) opens wading water and vine walls.
static func step(m: MapData, from: Vector2i, dir: Vector2i, gear: Array = []) -> Vector2i:
	var to: Vector2i = from + dir
	if m.char_at(to) == "B":
		return to if push(m, to, dir) else from
	return to if passable(m, to, gear) else from

## True if the player may walk into [param cell] with [param gear] (no boulders, no NPCs).
static func passable(m: MapData, cell: Vector2i, gear: Array = []) -> bool:
	if not m.in_bounds(cell):
		return false
	var k: int = m.kind_at(cell)
	if TilesetFactory.GEAR_KINDS.has(k):
		return TilesetFactory.GEAR_KINDS[k] in gear
	return m.is_walkable(cell)
