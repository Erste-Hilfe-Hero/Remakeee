class_name Player
extends GridWalker
## The Tamer. Reads only input actions: ui_up/down/left/right to walk, hold ui_cancel to run,
## ui_accept to interact. Tapping a new direction turns in place first.

signal interact(cell: Vector2i)
signal stepped(cell: Vector2i)

## Seconds a direction must be held after turning before walking starts.
const TURN_GRACE: float = 0.09

var can_move: Callable = func(_c: Vector2i) -> bool: return true
var frozen: bool = false
var _turn_timer: float = 0.0

func _ready() -> void:
	step_finished.connect(func(c: Vector2i) -> void: stepped.emit(c))

func _process(delta: float) -> void:
	super._process(delta)
	if frozen or moving:
		return
	var dir: String = _held_direction()
	if dir.is_empty():
		_turn_timer = 0.0
		return
	if dir != facing:
		face(dir)
		_turn_timer = TURN_GRACE
		return
	if _turn_timer > 0.0:
		_turn_timer -= delta
		return
	if can_move.call(cell + DIRS[dir]):
		step(dir, Input.is_action_pressed("ui_cancel"))

func _held_direction() -> String:
	for dir: String in ["up", "down", "left", "right"]:
		if Input.is_action_pressed("ui_" + dir):
			return dir
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if frozen or moving:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		interact.emit(facing_cell())
