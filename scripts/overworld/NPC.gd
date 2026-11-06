class_name NPC
extends GridWalker
## A standing character. Talks using a dialogue reference; Wayfarers also carry a team (M5).

var npc_id: String = ""
var dialogue_ref: String = ""
var definition: Dictionary = {}

func setup(def: Dictionary) -> void:
	definition = def
	npc_id = str(def.get("id", ""))
	dialogue_ref = str(def.get("dialogue", ""))
	body_color = Color(str(def.get("color", "b04a4a")))
	sprite_style = str(def.get("sprite", "villager"))
	place(Vector2i(int(def.x), int(def.y)), str(def.get("facing", "down")))
	walk_route.assign(def.get("walk_cells", NpcSchedule.cells(def.get("walk", []))))
	_walk_i = 0
	_walk_dir = 1

## Short walk (area 3 item 1213): cells from the start cell; walked to the end and back.
var walk_route: Array[Vector2i] = []
var _walk_i: int = 0
var _walk_dir: int = 1

## The next cell of the walk, or the current cell when there is no walk.
func next_walk_cell() -> Vector2i:
	if walk_route.size() < 2:
		return cell
	var i: int = _walk_i + _walk_dir
	if i < 0 or i >= walk_route.size():
		_walk_dir = -_walk_dir
		i = _walk_i + _walk_dir
	return walk_route[i]

## Takes one slow step along the walk if [param free] (Callable(Vector2i) -> bool) lets it.
## Returns true if it moved; a person in the way just makes it wait.
func walk_tick(free: Callable) -> bool:
	if moving or walk_route.size() < 2:
		return false
	var next: Vector2i = next_walk_cell()
	var d: Vector2i = next - cell
	if absi(d.x) + absi(d.y) != 1 or not free.call(next):
		return false
	for dir: String in DIRS:
		if DIRS[dir] == d:
			step(dir)
	_walk_i += _walk_dir
	return true

## Shows a "!" above the head when a Wayfarer spots the player.
var alert: bool = false:
	set(v):
		alert = v
		queue_redraw()

func _draw() -> void:
	super._draw()
	if alert:
		draw_rect(Rect2(6, -9, 4, 8), UITheme.BG)
		draw_rect(Rect2(6, -9, 4, 8), UITheme.INK, false, 1.0)
		draw_rect(Rect2(7, -8, 2, 4), UITheme.INK)
		draw_rect(Rect2(7, -3, 2, 1), UITheme.INK)

## Turns toward [param who_cell].
func face_toward(who_cell: Vector2i) -> void:
	var d: Vector2i = who_cell - cell
	if absi(d.x) > absi(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")
