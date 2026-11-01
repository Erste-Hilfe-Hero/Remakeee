class_name Player
extends GridWalker
## The Tamer. Reads only input actions: ui_up/down/left/right to walk, hold ui_cancel to run,
## ui_accept to interact. Tapping a new direction turns in place first.
## Tap-to-move: follow [member path] cell by cell; any held direction cancels it.

signal interact(cell: Vector2i)
signal stepped(cell: Vector2i)

## Seconds a direction must be held after turning before walking starts.
const TURN_GRACE: float = 0.09

var can_move: Callable = func(_c: Vector2i) -> bool: return true
var frozen: bool = false
var _turn_timer: float = 0.0
## Cells still to walk (tap-to-move), and the cell to interact with on arrival (or NO_TARGET).
var path: Array[Vector2i] = []
var path_target: Vector2i = NO_TARGET
const NO_TARGET := Vector2i(-9999, -9999)

## Starts walking [param cells]; on arrival, faces and interacts with [param target] if given.
func follow(cells: Array[Vector2i], target: Vector2i = NO_TARGET) -> void:
	path = cells.duplicate()
	path_target = target

func cancel_path() -> void:
	path.clear()
	path_target = NO_TARGET

func _ready() -> void:
	step_finished.connect(func(c: Vector2i) -> void: stepped.emit(c))

func _process(delta: float) -> void:
	super._process(delta)
	if frozen:
		cancel_path()
		return
	if moving:
		return
	var dir: String = _held_direction()
	if not dir.is_empty():
		cancel_path()
	elif not path.is_empty() or path_target != NO_TARGET:
		_follow_step()
		return
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

func _follow_step() -> void:
	if path.is_empty():
		var target: Vector2i = path_target
		cancel_path()
		var d: Vector2i = target - cell
		for k: String in DIRS:
			if DIRS[k] == d:
				face(k)
				interact.emit(target)
		return
	var next: Vector2i = path[0]
	var step_dir: String = ""
	for k: String in DIRS:
		if DIRS[k] == next - cell:
			step_dir = k
	if step_dir.is_empty() or not can_move.call(next):
		cancel_path()
		return
	path.remove_at(0)
	step(step_dir, path.size() >= RUN_AFTER)

## Long tap-to-move paths run instead of walk.
const RUN_AFTER: int = 6

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
