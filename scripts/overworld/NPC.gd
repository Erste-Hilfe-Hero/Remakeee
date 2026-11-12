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
## It pops in (1 px bigger for a moment) with a short two-tone call (items 2306, 2505).
var alert: bool = false:
	set(v):
		var was: bool = alert
		alert = v
		if v and not was:
			Sound.sfx("spot")
			_alert_pop = not Juice.reduced()
			if _alert_pop and is_inside_tree():
				get_tree().create_timer(ALERT_POP_TIME).timeout.connect(func() -> void:
					_alert_pop = false
					queue_redraw())
		queue_redraw()
var _alert_pop: bool = false
const ALERT_POP_TIME: float = 0.06

func _draw() -> void:
	super._draw()
	# From Era II the "!" is a bubble drawn by EraActors (data/era_actor_look.json).
	if alert and EraActorLook.plain_emotes():
		var g: int = 1 if _alert_pop else 0
		draw_rect(Rect2(6 - g, -9 - g, 4 + g * 2, 8 + g * 2), UITheme.BG)
		draw_rect(Rect2(6 - g, -9 - g, 4 + g * 2, 8 + g * 2), UITheme.INK, false, 1.0)
		draw_rect(Rect2(7, -8, 2, 4), UITheme.INK)
		draw_rect(Rect2(7, -3, 2, 1), UITheme.INK)

## When talked to, a villager pauses this long before turning (item 2307).
const TURN_PAUSE: float = 0.1
## Standing villagers glance in another direction every 3 to 7 seconds (item 2310). Only the
## drawn direction changes, so a Wayfarer's line of sight stays as placed. A map entry with
## "still": true, a walk or a team keeps the villager as placed.
const GLANCE_MIN: float = 3.0
const GLANCE_MAX: float = 7.0
## After a talk the villager keeps facing the player this long before glancing again.
const GLANCE_AFTER_TALK: float = 10.0
var _glance_in: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_glance_in = _rng.randf_range(GLANCE_MIN, GLANCE_MAX)

## True if this villager may glance around on its own.
func may_glance() -> bool:
	return walk_route.size() < 2 and not definition.has("trainer") and not definition.has("team") \
		and not bool(definition.get("still", false))

func _process(delta: float) -> void:
	super._process(delta)
	if moving or not may_glance():
		return
	_glance_in -= delta
	if _glance_in <= 0.0:
		_glance_in = _rng.randf_range(GLANCE_MIN, GLANCE_MAX)
		glance()

## Looks in a random direction other than the current one (facing itself stays).
func glance() -> void:
	var dirs: Array[String] = []
	for d: String in DIRS:
		if d != shown_facing():
			dirs.append(d)
	look = dirs[_rng.randi() % dirs.size()]

## Waits [constant TURN_PAUSE], then turns toward [param who_cell]. Awaitable.
func turn_toward(who_cell: Vector2i) -> void:
	_glance_in = GLANCE_AFTER_TALK
	EraActors.react_on(self, "talk_beaten" if TrainerData.is_trainer(definition) else "talk")
	if is_inside_tree():
		await get_tree().create_timer(TURN_PAUSE).timeout
	face_toward(who_cell)

## Turns toward [param who_cell].
func face_toward(who_cell: Vector2i) -> void:
	_glance_in = maxf(_glance_in, GLANCE_AFTER_TALK)
	var d: Vector2i = who_cell - cell
	if absi(d.x) > absi(d.y):
		face("right" if d.x > 0 else "left")
	else:
		face("down" if d.y > 0 else "up")
