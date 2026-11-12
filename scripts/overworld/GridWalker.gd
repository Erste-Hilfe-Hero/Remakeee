class_name GridWalker
extends Node2D
## Shared grid movement for the player and NPCs: 16 px cells, 4-direction facing,
## tweened in _process (never physics), integer positions.

signal step_finished(cell: Vector2i)
signal step_started(dir: String, run: bool)

const TILE: int = 16
const WALK_TIME: float = 0.22
const RUN_TIME: float = 0.11
const DIRS: Dictionary[String, Vector2i] = {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

@export var body_color: Color = Color("3a5a9a")
## Sprite sheet style in art/era1/chars/ (tamer, villager, ranger, elder, warden).
@export var sprite_style: String = "villager"
## Worn shop hat kind (HatArt.KINDS, item 4283); "" for none.
var hat: String = "":
	set(v):
		hat = v
		queue_redraw()

const CHAR_REL: String = "chars/%s.png"
## Era walk cycle (data/era_feel.json via EraManager): 2 = stand and step; 3 = the step frame
## alternates left and right foot (drawn mirrored on every second step when facing up or down).
static var walk_frames: int = 2
## Era V: standing figures breathe, a 1 px dip every other beat.
static var breathe: bool = false
const BREATHE_MS: int = 700
var _stride: int = 0
var _breath: int = 0
const SHEET_COLUMNS: Dictionary[String, int] = {"down": 0, "up": 1, "left": 2, "right": 3}
static var _sheets: Dictionary[String, Texture2D] = {}
var _step_frame: int = 0

var cell: Vector2i = Vector2i.ZERO
var facing: String = "down"
var moving: bool = false
var _from: Vector2
var _to: Vector2
var _t: float = 0.0
var _duration: float = WALK_TIME
## Dips the sprite 1 px in the middle of each step so walking has weight (item 2303).
var bob: bool = false
## Drawn 1 px jolt toward a wall the walker ran into (item 2263); the node and the camera
## stay where they are.
var jolt: Vector2 = Vector2.ZERO:
	set(v):
		jolt = v
		queue_redraw()
## Length of the 1 px greeting hop after a battle (item 2292).
const GREET_TIME: float = 0.2

## Hops the drawn figure 1 px up and back, as a small hello when the world brightens after a
## battle (item 2292). Skipped under reduced motion.
func greet() -> void:
	if Juice.reduced():
		return
	jolt = Vector2(0, -1)
	await get_tree().create_timer(GREET_TIME).timeout
	if is_instance_valid(self):
		jolt = Vector2.ZERO

## True while the current step is a running step.
var running: bool = false
## Direction the sprite looks in without turning the walker (idle glances, items 2308 and
## 2310); "" draws [member facing]. Talking, walking and interacting always use facing.
var look: String = "":
	set(v):
		look = v
		queue_redraw()

func place(c: Vector2i, face: String = "") -> void:
	cell = c
	position = cell_to_pos(c)
	moving = false
	if not face.is_empty():
		facing = face
	queue_redraw()

static func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, c.y * TILE)

func face(dir: String) -> void:
	facing = dir
	look = ""
	queue_redraw()

## The direction the sprite is drawn in.
func shown_facing() -> String:
	return facing if look.is_empty() else look

func facing_cell() -> Vector2i:
	return cell + DIRS[facing]

## Starts a one-cell move. The caller checks walkability.
func step(dir: String, run: bool = false) -> void:
	facing = dir
	look = ""
	_from = position
	cell += DIRS[dir]
	_to = cell_to_pos(cell)
	_t = 0.0
	_duration = RUN_TIME if run else WALK_TIME
	_stride += 1
	running = run
	moving = true
	queue_redraw()
	step_started.emit(dir, run)

## Row of the sheet drawn now: 0 standing, 1 mid-step.
func step_frame() -> int:
	return _step_frame

## True when this step's frame is drawn mirrored (the other foot).
func mirrored_step() -> bool:
	return walk_frames >= 3 and moving and _step_frame == 1 and _stride % 2 == 1 and shown_facing() in ["up", "down"]

func _process(delta: float) -> void:
	if not moving:
		if breathe:
			var b: int = int((Time.get_ticks_msec() + (cell.x * 97 + cell.y * 31) * 13) / BREATHE_MS) % 2
			if b != _breath:
				_breath = b
				queue_redraw()
		return
	_t += delta
	var k: float = clampf(_t / _duration, 0.0, 1.0)
	position = _from.lerp(_to, k).round()
	var frame: int = 1 if k > 0.25 and k < 0.75 else 0
	if frame != _step_frame:
		_step_frame = frame
		queue_redraw()
	if k >= 1.0:
		moving = false
		position = _to
		step_finished.emit(cell)

static func sheet_for(style: String) -> Texture2D:
	if not _sheets.has(style):
		var path: String = EraManager.art_path(CHAR_REL % style)
		_sheets[style] = load(path) if not path.is_empty() else null
	return _sheets[style]

static func clear_cache() -> void:
	_sheets.clear()

func _draw() -> void:
	var sheet: Texture2D = sheet_for(sprite_style)
	var shift: Vector2 = jolt
	if bob and moving and _step_frame == 1:
		shift += Vector2(0, 1)
	if breathe and not moving and _breath == 1 and not Juice.reduced():
		shift += Vector2(0, 1)
	if mirrored_step():
		draw_set_transform(shift + Vector2(TILE, 0), 0.0, Vector2(-1, 1))
	elif shift != Vector2.ZERO:
		draw_set_transform(shift)
	if sheet != null:
		var src := Rect2(SHEET_COLUMNS[shown_facing()] * TILE, _step_frame * TILE, TILE, TILE)
		draw_texture_rect_region(sheet, Rect2(0, 0, TILE, TILE), src)
		HatArt.draw(self, Vector2(8, 3), hat)
		return
	# Fallback body: coloured rectangle with a facing marker.
	draw_rect(Rect2(2, 1, 12, 14), body_color)
	draw_rect(Rect2(2, 1, 12, 14), UITheme.INK, false, 1.0)
	HatArt.draw(self, Vector2(8, 2), hat)
	var d: Vector2i = DIRS[shown_facing()]
	var c := Vector2(8, 8) + Vector2(d) * 4.0
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), UITheme.BG)
