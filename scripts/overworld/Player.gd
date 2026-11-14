class_name Player
extends GridWalker
## The Wayfarer. Reads only input actions: ui_up/down/left/right to walk, hold ui_cancel to run (or to walk with Always run),
## ui_accept to interact. Tapping a new direction turns in place first.
## Tap-to-move: follow [member path] cell by cell; any held direction cancels it.

signal interact(cell: Vector2i)
signal stepped(cell: Vector2i)
## A tap-to-move path ran into [param next], which became blocked (item 1822).
signal path_blocked(next: Vector2i)

## Starts a one-cell move, twice as fast with the shop's Swift Steps (plan point 50).
func step(dir: String, run: bool = false) -> void:
	speed_mult = ShopEffects.walk_mult()
	super.step(dir, run)

## Seconds a direction must be held after turning before walking starts.
const TURN_GRACE: float = 0.08

var can_move: Callable = func(_c: Vector2i) -> bool: return true
var frozen: bool = false
var _turn_timer: float = 0.0
## Cells still to walk (tap-to-move), and the cell to interact with on arrival (or NO_TARGET).
var path: Array[Vector2i] = []
var path_target: Vector2i = NO_TARGET
## Counts steps taken with a held direction; a tap walk planned before one of them is stale.
var manual_steps: int = 0
const NO_TARGET := Vector2i(-9999, -9999)

## Starts walking [param cells]; on arrival, faces and interacts with [param target] if given.
func follow(cells: Array[Vector2i], target: Vector2i = NO_TARGET) -> void:
	path = cells.duplicate()
	path_target = target

func cancel_path() -> void:
	path.clear()
	path_target = NO_TARGET

## Leaving the app drops a tap-to-move walk, so the Wayfarer never walks on by itself
## after coming back (bug plan item 1311). The reconnect screen pausing the game does the same.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PAUSED:
		cancel_path()

func _ready() -> void:
	step_finished.connect(func(c: Vector2i) -> void: stepped.emit(c))

## Standing still this long, the Wayfarer looks left and right (item 2308), switching every
## IDLE_LOOK_EVERY seconds. Only the drawn direction changes.
const IDLE_LOOK_AFTER: float = 8.0
const IDLE_LOOK_EVERY: float = 1.2
var idle_time: float = 0.0

func _idle(delta: float, active: bool) -> void:
	if active:
		idle_time = 0.0
		if not look.is_empty():
			look = ""
		return
	idle_time += delta
	if idle_time < IDLE_LOOK_AFTER:
		return
	var n: int = int((idle_time - IDLE_LOOK_AFTER) / IDLE_LOOK_EVERY)
	var want: String = "left" if n % 2 == 0 else "right"
	if look != want:
		look = want

func _process(delta: float) -> void:
	super._process(delta)
	_idle(delta, frozen or moving or not _held_direction().is_empty() or not path.is_empty())
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
		_bumped = NO_TARGET
		return
	if dir != facing:
		face(dir)
		_turn_timer = TURN_GRACE
		return
	if _turn_timer > 0.0:
		_turn_timer -= delta
		return
	if can_move.call(cell + DIRS[dir]):
		_bumped = NO_TARGET
		manual_steps += 1
		step(dir, Input.is_action_pressed("ui_cancel") != GameState.always_run)
	else:
		bump(dir)

## Length of the wall jolt.
const BUMP_TIME: float = 0.08
## Cell last bumped into, so holding a direction against a wall jolts only once.
var _bumped: Vector2i = NO_TARGET

## Jolts the drawn figure 1 px toward a blocked cell, once per approach (item 2263).
## Skipped under reduced motion.
func bump(dir: String) -> void:
	var target: Vector2i = cell + DIRS[dir]
	if target == _bumped:
		return
	_bumped = target
	if Juice.reduced():
		return
	jolt = Vector2(DIRS[dir])
	await get_tree().create_timer(BUMP_TIME).timeout
	if is_instance_valid(self):
		jolt = Vector2.ZERO

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
		if not step_dir.is_empty():
			path_blocked.emit(next)
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
		_idle(0.0, true)
		get_viewport().set_input_as_handled()
		interact.emit(facing_cell())
