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
## Clock flags (area 3 items 979 and 981): blocks can open on "_low_tide" (sea caves) or
## "_vents_calm" (hot vents that block the way every few seconds).
const CLOCK_FLAGS: Array[String] = ["_low_tide", "_vents_calm",
	"_water_ge_0", "_water_ge_1", "_water_ge_2", "_water_ge_3", "_water_le_0", "_water_le_1", "_water_le_2", "_water_le_3"]
## Vents: calm for VENT_HALF seconds, then blowing for VENT_HALF seconds (a 4 second beat).
const VENT_HALF: float = 2.0
var vents_calm: bool = true
var _vent_timer: Timer
## Test hook: -1 uses the device clock.
var hour_override: int = -1
var phase_override: int = -1

func _init(overworld: Overworld) -> void:
	ow = overworld

## Called by Overworld.load_map before painting: saved state, then blocks with live plates.
func prepare(m: MapData, cell: Vector2i) -> void:
	_undo.clear()
	_cracking = Vector2i(-1, -1)
	PuzzleRoom.apply_state(m, GameState.world_of(m.id))
	vents_calm = true
	m.apply_blocks(flags_now(m, cell))
	_pressed = _pressed_now(m, cell)
	_build_glints(m)
	_setup_vents(m)
	_draw_beam(m)

## True from midnight to 6 and from noon to 18 (two low tides a day, device clock).
static func low_tide(hour: int) -> bool:
	return posmod(hour, 12) < 6

func _hour() -> int:
	return hour_override if hour_override >= 0 else int(Time.get_time_dict_from_system().hour)

## Story flags plus clock flags plus puzzles held down right now.
func flags_now(m: MapData, cell: Vector2i) -> Dictionary:
	var f: Dictionary = GameState.flags.duplicate()
	f["_phase"] = phase_override if phase_override >= 0 else DayCycle.current()
	if low_tide(_hour()):
		f["_low_tide"] = true
	if vents_calm:
		f["_vents_calm"] = true
	if not m.sluices.is_empty():
		water_flags(water_level(m), f)
	return PuzzleRoom.live_flags(m, f, cell)

# --- Brackwater Sluice (item 1009): water level = sluices open on this map ---------------------

## Water level on [param m]: how many of the map's "sluices" flags are set (0 to 3).
func water_level(m: MapData, flags: Dictionary = GameState.flags) -> int:
	var n: int = 0
	for f: Variant in m.sluices:
		if bool(flags.get(str(f), false)):
			n += 1
	return n

## Clock-like flags for the water: "_water_ge_N" (level at least N) and "_water_le_N" (at most N).
static func water_flags(level: int, out: Dictionary) -> void:
	for n: int in range(0, 4):
		if level >= n:
			out["_water_ge_%d" % n] = true
		if level <= n:
			out["_water_le_%d" % n] = true

# --- Lanternwell (item 1010): a beam of light, mirrors "/" or "\\", target crystals --------

const MIRROR_TURN: Dictionary = {"/": "\\", "\\": "/"}

## Mirror cells of the map's beam with their current way ("/" or "\\").
func mirrors(m: MapData) -> Dictionary:
	var out: Dictionary = {}
	if m.beam.is_empty():
		return out
	var saved: Dictionary = GameState.world_of(m.id).get("mirrors", {})
	for mm: Variant in m.beam.get("mirrors", []):
		var c := Vector2i(int(mm[0]), int(mm[1]))
		out[c] = str(saved.get("%d_%d" % [c.x, c.y], str(mm[2]) if (mm as Array).size() > 2 else "/"))
	return out

## Cells the beam passes, from its source, bouncing off [param ways] (cell -> "/" or "\\").
static func trace_beam(m: MapData, ways: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if m.beam.is_empty():
		return out
	var c := Vector2i(int(m.beam.x), int(m.beam.y))
	var d: Vector2i = {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT}.get(str(m.beam.get("dir", "right")), Vector2i.RIGHT)
	var target := Vector2i(int(m.beam.target[0]), int(m.beam.target[1]))
	for i: int in 200:
		c += d
		if not m.in_bounds(c):
			break
		out.append(c)
		if c == target:
			break
		if ways.has(c):
			# "/" sends right to up and down to left; "\\" sends right to down.
			d = Vector2i(-d.y, -d.x) if ways[c] == "/" else Vector2i(d.y, d.x)
			continue
		if not m.is_walkable(c):
			break
	return out

static func beam_hits(m: MapData, ways: Dictionary) -> bool:
	var path: Array[Vector2i] = trace_beam(m, ways)
	return not path.is_empty() and path[-1] == Vector2i(int(m.beam.target[0]), int(m.beam.target[1]))

## Turns the mirror at [param cell]; sets the beam's flag once the crystal is lit.
func turn_mirror(cell: Vector2i) -> bool:
	var m: MapData = ow.map
	var ways: Dictionary = mirrors(m)
	if not ways.has(cell):
		return false
	ways[cell] = MIRROR_TURN[ways[cell]]
	var state: Dictionary = GameState.world_of(m.id).duplicate(true)
	var saved: Dictionary = state.get("mirrors", {})
	saved["%d_%d" % [cell.x, cell.y]] = ways[cell]
	state["mirrors"] = saved
	_save_state(state)
	var hit: bool = beam_hits(m, ways)
	if hit:
		GameState.set_flag(str(m.beam.flag))
	refresh(ow.player.cell)
	_draw_beam(m)
	return hit

var _beam_line: Line2D

func _draw_beam(m: MapData) -> void:
	if _beam_line == null:
		_beam_line = Line2D.new()
		_beam_line.name = "beam"
		_beam_line.width = 2.0
		_beam_line.default_color = UITheme.ACCENT
		_beam_line.z_index = 3
		ow.add_child(_beam_line)
	_beam_line.clear_points()
	if m.beam.is_empty():
		return
	var half := Vector2.ONE * TilesetFactory.TILE * 0.5
	_beam_line.add_point(Vector2(int(m.beam.x), int(m.beam.y)) * TilesetFactory.TILE + half)
	for c: Vector2i in trace_beam(m, mirrors(m)):
		_beam_line.add_point(Vector2(c) * TilesetFactory.TILE + half)

## Points of the drawn beam (for tests).
func beam_points() -> int:
	return _beam_line.get_point_count() if _beam_line != null else 0

static func has_vents(m: MapData) -> bool:
	for b: Dictionary in m.blocks:
		if str(b.get("open_flag", "")) == "_vents_calm":
			return true
	return false

func _setup_vents(m: MapData) -> void:
	if _vent_timer == null:
		_vent_timer = Timer.new()
		_vent_timer.wait_time = VENT_HALF
		_vent_timer.timeout.connect(vent_tick)
		ow.add_child(_vent_timer)
	if has_vents(m):
		_vent_timer.start()
	else:
		_vent_timer.stop()

## One half beat of the vents. They never blow up under the player: they wait a beat.
func vent_tick() -> void:
	var m: MapData = ow.map
	if vents_calm:
		for b: Dictionary in m.blocks:
			if str(b.get("open_flag", "")) == "_vents_calm" and Vector2i(int(b.x), int(b.y)) == ow.player.cell:
				return
	vents_calm = not vents_calm
	refresh(ow.player.cell)
	if not vents_calm:
		Sound.sfx("bump")

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
	m.apply_blocks(flags_now(m, cell))
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
