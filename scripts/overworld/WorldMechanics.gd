class_name WorldMechanics
extends RefCounted
## Area 3 world mechanics in the overworld: pushing boulders, pressure plates, cracked floor,
## plank gaps, rope ladders, wading water and vine walls, with undo and room reset
## (items 1011 to 1014, 1044 to 1047). Rules live in PuzzleRoom; this class wires them to the
## Overworld scene, so Overworld.gd only needs a few hooks.

const PUSH_TIME: float = 0.16
## Undo steps kept per room.
const UNDO_MAX: int = 40

var ow: Overworld
## Boulder layouts before each push on this map, newest last (for "Undo push").
var _undo: Array = []
## Cracked cell the player is standing on (it breaks when they step off).
var _cracking: Vector2i = Vector2i(-1, -1)
## Last pressed state per puzzle flag, to play a sound when it changes.
var _pressed: Dictionary = {}
## Hidden finds glint briefly every few seconds (area 3 item 1078).
const GLINT_EVERY: float = 4.0
const GLINT_TIME: float = 0.35
var _glints: Node2D
var _glint_timer: Timer

func _init(overworld: Overworld) -> void:
	ow = overworld

## Called by Overworld.load_map before painting: saved state, then blocks with live plates.
func prepare(m: MapData, cell: Vector2i) -> void:
	_undo.clear()
	_cracking = Vector2i(-1, -1)
	PuzzleRoom.apply_state(m, GameState.world_of(m.id))
	m.apply_blocks(PuzzleRoom.live_flags(m, GameState.flags, cell))
	_pressed = _pressed_now(m, cell)
	_build_glints(m)

func _build_glints(m: MapData) -> void:
	if _glints == null:
		_glints = Node2D.new()
		_glints.name = "glints"
		_glints.z_index = 2
		ow.add_child(_glints)
		_glint_timer = Timer.new()
		_glint_timer.wait_time = GLINT_EVERY
		_glint_timer.autostart = true
		_glint_timer.timeout.connect(_glint)
		_glints.add_child(_glint_timer)
	for c: Node in _glints.get_children():
		if c != _glint_timer:
			_glints.remove_child(c)
			c.queue_free()
	for sc: Dictionary in m.secrets:
		if GameState.has_flag(str(sc.get("flag", ""))):
			continue
		var g := Node2D.new()
		g.position = Vector2(int(sc.x), int(sc.y)) * TilesetFactory.TILE
		g.visible = false
		g.set_meta("flag", str(sc.flag))
		for p: Vector2i in [Vector2i(7, 4), Vector2i(6, 5), Vector2i(8, 5), Vector2i(7, 6), Vector2i(7, 5)]:
			var px := ColorRect.new()
			px.color = UITheme.BG if p != Vector2i(7, 5) else UITheme.ACCENT
			px.position = Vector2(p)
			px.size = Vector2.ONE
			px.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.add_child(px)
		_glints.add_child(g)

func _glint() -> void:
	for g: Node in _glints.get_children():
		if g is Node2D and not GameState.has_flag(str(g.get_meta("flag", ""))):
			(g as Node2D).visible = true
	await ow.get_tree().create_timer(GLINT_TIME).timeout
	if is_instance_valid(_glints):
		for g: Node in _glints.get_children():
			if g is Node2D:
				(g as Node2D).visible = false

## Glint nodes still on the map (for tests).
func glint_count() -> int:
	return _glints.get_child_count() - 1 if _glints != null else 0

func _pressed_now(m: MapData, cell: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in m.puzzles:
		out[str(p.get("flag", ""))] = PuzzleRoom.pressed(m, p, cell)
	return out

func has_puzzle() -> bool:
	return not ow.map.puzzles.is_empty() or not PuzzleRoom.start_boulders(ow.map).is_empty()

## Redraws after a change and plays a sound if a puzzle opened or closed.
func refresh(cell: Vector2i) -> void:
	var m: MapData = ow.map
	m.apply_blocks(PuzzleRoom.live_flags(m, GameState.flags, cell))
	m.paint(ow.ground_layer())
	var now: Dictionary = _pressed_now(m, cell)
	for f: String in now:
		if bool(now[f]) != bool(_pressed.get(f, false)):
			Sound.sfx("warp" if now[f] else "bump")
	_pressed = now

func _save_state(state: Dictionary) -> void:
	GameState.set_world_of(ow.map.id, state)

## -1: no opinion (normal rules), 0: blocked, 1: the player may step into [param cell].
func can_enter(cell: Vector2i) -> int:
	var m: MapData = ow.map
	if not m.in_bounds(cell):
		return -1
	var dir: Vector2i = cell - ow.player.cell
	if m.char_at(cell) == "B":
		if PathFinder.is_adjacent(cell, ow.player.cell) and _push(cell, dir):
			return 1
		Sound.sfx("bump")
		return 0
	if PuzzleRoom.is_broken(GameState.world_of(m.id), cell) and not m.drop_to.is_empty():
		return 1
	var k: int = m.kind_at(cell)
	if TilesetFactory.GEAR_KINDS.has(k):
		var gear: String = TilesetFactory.GEAR_KINDS[k]
		if GameState.has_gear(gear):
			return 1
		ow.gear_hint_deferred(gear)
		return 0
	return -1

func _blocked_cells() -> Dictionary:
	var out: Dictionary = {}
	for n: NPC in ow.npcs():
		out[n.cell] = true
	return out

func _push(at: Vector2i, dir: Vector2i) -> bool:
	var m: MapData = ow.map
	var before: Array[Vector2i] = PuzzleRoom.boulders(m)
	if not PuzzleRoom.push(m, at, dir, _blocked_cells()):
		return false
	_undo.append({"boulders": before, "cell": ow.player.cell, "facing": ow.player.facing})
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_save_state(PuzzleRoom.capture(m, GameState.world_of(m.id)))
	Sound.sfx("confirm")
	refresh(at)
	return true

## After each step: cracked floor, falling, plates. Returns true if the step was handled
## (the player fell to the floor below).
func stepped(cell: Vector2i) -> bool:
	var m: MapData = ow.map
	var state: Dictionary = GameState.world_of(m.id)
	if _cracking.x >= 0 and _cracking != cell:
		_save_state(PuzzleRoom.break_floor(m, state, _cracking))
		Sound.sfx("bump")
		_cracking = Vector2i(-1, -1)
		refresh(cell)
		state = GameState.world_of(m.id)
	if PuzzleRoom.is_broken(state, cell) and not m.drop_to.is_empty():
		await ow.drop_to(m.drop_to, cell)
		return true
	if m.kind_at(cell) == TilesetFactory.Kind.CRACKED:
		_cracking = cell
		Sound.sfx("bump")
	if not m.puzzles.is_empty():
		refresh(cell)
	return false

## A on a hidden find, a secret passage, a plank gap or a ladder anchor. Returns true if handled.
func interact(cell: Vector2i) -> bool:
	var m: MapData = ow.map
	var find: Dictionary = m.secret_at(cell, GameState.flags)
	if not find.is_empty():
		await ow.take_find(find)
		_build_glints(m)
		return true
	var passage: Dictionary = m.passage_at(cell)
	if not passage.is_empty() and not GameState.has_flag(str(passage.get("flag", ""))):
		open_passage(passage)
		await ow.say_locked(["The smooth rock gives under your hands and slides aside. A way opens."] as Array[String])
		return true
	var state: Dictionary = GameState.world_of(m.id)
	var ladder: Dictionary = m.ladder_at(cell)
	if not ladder.is_empty():
		var hung: bool = bool(state.get("ladder_%d_%d" % [cell.x, cell.y], false))
		if not hung:
			if not GameState.has_gear("rope_ladder"):
				await ow.say_locked([str(Database.item("rope_ladder").get("hint", ""))] as Array[String])
				return true
			var out: Dictionary = state.duplicate(true)
			out["ladder_%d_%d" % [cell.x, cell.y]] = true
			_save_state(out)
			Sound.sfx("confirm")
			await ow.say_locked(["You tie the rope ladder to the edge. It will stay here."] as Array[String])
		await ow.climb_to(str(ladder.to), Vector2i(int(ladder.tx), int(ladder.ty)))
		return true
	if m.kind_at(cell) == TilesetFactory.Kind.PLANK and not PuzzleRoom.is_broken(state, cell):
		if not GameState.has_gear("plank_bundle"):
			await ow.say_locked([str(Database.item("plank_bundle").get("hint", ""))] as Array[String])
			return true
		_save_state(PuzzleRoom.lay_plank(m, state, cell))
		Sound.sfx("confirm")
		refresh(ow.player.cell)
		await ow.say_locked(["You lay a plank over the gap. It holds."] as Array[String])
		return true
	return false

## Slides the smooth rock of [param passage] aside for good (item 1082).
func open_passage(passage: Dictionary) -> void:
	GameState.set_flag(str(passage.flag))
	Sound.sfx("warp")
	refresh(ow.player.cell)

## "Undo push" (item 1012): the last push in this room is taken back.
func undo() -> bool:
	if _undo.is_empty():
		return false
	var last: Dictionary = _undo.pop_back()
	var m: MapData = ow.map
	PuzzleRoom.set_boulders(m, last.boulders)
	_save_state(PuzzleRoom.capture(m, GameState.world_of(m.id)))
	ow.player.place(last.cell, str(last.facing))
	GameState.player_cell = last.cell
	refresh(last.cell)
	return true

## "Reset room" (item 1014): boulders back to the start, the player back to where they came in.
func reset_room(entry: Vector2i) -> void:
	var m: MapData = ow.map
	_save_state(PuzzleRoom.reset(m, GameState.world_of(m.id)))
	_undo.clear()
	ow.player.place(entry, ow.player.facing)
	GameState.player_cell = entry
	refresh(entry)

func can_undo() -> bool:
	return not _undo.is_empty()
