class_name GridWalker
extends Node2D
## Shared grid movement for the player and NPCs: 16 px cells, 4-direction facing,
## tweened in _process (never physics), integer positions.

signal step_finished(cell: Vector2i)

const TILE: int = 16
const WALK_TIME: float = 0.22
const RUN_TIME: float = 0.11
const DIRS: Dictionary[String, Vector2i] = {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

@export var body_color: Color = Color("3a5a9a")

var cell: Vector2i = Vector2i.ZERO
var facing: String = "down"
var moving: bool = false
var _from: Vector2
var _to: Vector2
var _t: float = 0.0
var _duration: float = WALK_TIME

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
	queue_redraw()

func facing_cell() -> Vector2i:
	return cell + DIRS[facing]

## Starts a one-cell move. The caller checks walkability.
func step(dir: String, run: bool = false) -> void:
	facing = dir
	_from = position
	cell += DIRS[dir]
	_to = cell_to_pos(cell)
	_t = 0.0
	_duration = RUN_TIME if run else WALK_TIME
	moving = true
	queue_redraw()

func _process(delta: float) -> void:
	if not moving:
		return
	_t += delta
	var k: float = clampf(_t / _duration, 0.0, 1.0)
	position = _from.lerp(_to, k).round()
	if k >= 1.0:
		moving = false
		position = _to
		step_finished.emit(cell)

func _draw() -> void:
	# Placeholder body: coloured rectangle with a facing marker.
	draw_rect(Rect2(2, 1, 12, 14), body_color)
	draw_rect(Rect2(2, 1, 12, 14), UITheme.INK, false, 1.0)
	var d: Vector2i = DIRS[facing]
	var c := Vector2(8, 8) + Vector2(d) * 4.0
	draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), UITheme.BG)
