class_name SpirlingSprite
extends Control
## Battle sprite. Uses the era sprite if one exists, otherwise a coloured placeholder
## rectangle (element colours, initial letter) as AGENTS.md asks until real art exists.

const STEP_OUT_DISTANCE: float = 40.0
const STEP_TIME: float = 0.3
const HIT_FLASHES: int = 3
const KNOCKBACK_PX: float = 3.0
const HOPS: float = 2.0
const HOP_HEIGHT: float = 4.0
const MOTION_PATH: String = "res://data/spirling_motion.json"
const MOTIONS: Array[String] = ["hop", "creep", "sway", "stomp", "slide"]
static var _motion: Dictionary = {}
## Prism variants are drawn with a warm tint over the era palette.
const PRISM_TINT: Color = Color(1.0, 0.78, 0.5)
## Gleam form (shop item 4792): a cool Riftglass sheen.
const GLEAM_TINT: Color = Color(0.72, 0.92, 1.0)
## Idle bob: 1 px up for half of each period (item 2335).
const BOB_PERIOD: float = 1.0
## Under a quarter of its strength a Spirling sits 1 px lower and bobs at half the pace.
const LOW_HP_SHARE: float = 0.25
const LOW_BOB_PERIOD: float = 2.0
const LOW_SAG_PX: float = 1.0
## Sidestep on a missed art: 4 px aside and back in 0.2 s (item 2337).
const DODGE_PX: float = 4.0
const DODGE_TIME: float = 0.2

var spirling: Spirling
var facing: String = "front"
## Draws the sprite flipped horizontally (art faces left; the battle layout needs it facing right).
var mirrored: bool = false
var speed_scale: float = 1.0
var _texture: Texture2D
var _home: Vector2
var _bob_time: float = 0.0
## Drawn offset of the idle bob and the low-strength sag; never moves the node itself.
var draw_offset: Vector2 = Vector2.ZERO

func setup(s: Spirling, p_facing: String) -> void:
	spirling = s
	facing = p_facing
	accessibility_name = s.display_name()
	_texture = null
	var path: String = EraManager.sprite_path(s.data.species_name, facing)
	if not path.is_empty():
		_texture = load(path)
	modulate.a = 1.0
	queue_redraw()

## The era sprite in use, or null while the placeholder rectangle is drawn.
func texture() -> Texture2D:
	return _texture

func _ready() -> void:
	_home = position

func _process(delta: float) -> void:
	if spirling == null or not visible:
		return
	_bob_time += delta
	var o: Vector2 = idle_offset(spirling, _bob_time, Juice.reduced())
	if o != draw_offset:
		draw_offset = o
		queue_redraw()

## True under a quarter of the Spirling's strength (but not fainted).
static func is_weak(s: Spirling) -> bool:
	return s != null and s.hp > 0 and s.hp < s.max_hp() * LOW_HP_SHARE

## Idle drawing offset at time t: weak Spirlings sag 1 px and bob at half the pace; under
## reduced motion only the sag stays.
static func idle_offset(s: Spirling, t: float, reduced: bool) -> Vector2:
	var weak: bool = is_weak(s)
	var y: float = LOW_SAG_PX if weak else 0.0
	if not reduced and s != null and s.hp > 0:
		var period: float = LOW_BOB_PERIOD if weak else BOB_PERIOD
		if fmod(t, period) >= period * 0.5:
			y -= 1.0
	return Vector2(0, y)

## A newly bonded Spirling hops 4 px once before its name shows (item 2344). Skipped
## under reduced motion. Awaitable.
const GREET_HOP_PX: float = 4.0
const GREET_HOP_TIME: float = 0.2

func greet_hop() -> void:
	if Juice.reduced():
		return
	await Juice.tween(self, "position", _home + Vector2(0, -GREET_HOP_PX), "move", GREET_HOP_TIME * 0.45).finished
	await Juice.tween(self, "position", _home, "impact", GREET_HOP_TIME * 0.55).finished

## Where a sidestep in `dir` (sign of x; 0 counts as right) lands.
static func dodge_spot(home: Vector2, dir: float) -> Vector2:
	return home + Vector2(-DODGE_PX if dir < 0.0 else DODGE_PX, 0)

## Sidesteps a missed art: 4 px in `dir` (sign of x) and back in 0.2 s. Skipped under
## reduced motion. Awaitable.
func dodge(dir: float) -> void:
	if Juice.reduced():
		return
	await Juice.tween(self, "position", dodge_spot(_home, dir), "move", DODGE_TIME * 0.4).finished
	await Juice.tween(self, "position", _home, "move", DODGE_TIME * 0.6).finished

## Steps out beside the Wayfarer (slides in from the screen edge; never thrown). Awaitable.
## Durations come from Juice curves, so the 2x / 4x battle speed applies on its own.
## The way the Spirling moves follows its motion profile (item 2330).
func step_out(from_left: bool) -> void:
	_home = position
	position = _home + Vector2(-STEP_OUT_DISTANCE if from_left else STEP_OUT_DISTANCE, 0)
	modulate.a = 0.0
	visible = true
	Juice.tween(self, "modulate:a", 1.0, "move", STEP_TIME)
	var m: String = motion_of(spirling.data.species_name, spirling.elements()) if spirling != null else "slide"
	if Juice.reduced():
		m = "slide"
	match m:
		"hop":
			# Two hops of 4 px each on the way in.
			var start: Vector2 = position
			var hop := func(k: float) -> void:
				var arc: float = absf(sin(k * PI * HOPS))
				position = (start.lerp(_home, k) + Vector2(0, -HOP_HEIGHT * arc)).round()
			var tw: Tween = create_tween()
			Juice.shaped(tw.tween_method(hop, 0.0, 1.0, STEP_TIME / Juice.speed()), "move")
			await tw.finished
			position = _home
		"stomp":
			await Juice.tween(self, "position", _home, "impact", STEP_TIME).finished
			Juice.add_trauma(0.1)
		"creep":
			await Juice.tween(self, "position", _home, "move", STEP_TIME * 1.3).finished
		"sway":
			var start2: Vector2 = position
			var sway := func(k: float) -> void:
				position = (start2.lerp(_home, k) + Vector2(0, -sin(k * PI * 3.0))).round()
			var tw2: Tween = create_tween()
			tw2.tween_method(sway, 0.0, 1.0, STEP_TIME / Juice.speed()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await tw2.finished
			position = _home
		_:
			await Juice.tween(self, "position", _home, "move", STEP_TIME).finished

## Motion profile for [param species]: data/spirling_motion.json, else by first element.
static func motion_of(species: String, elements: Array[int]) -> String:
	if _motion.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOTION_PATH)) if FileAccess.file_exists(MOTION_PATH) else null
		_motion = raw if raw is Dictionary else {"species": {}, "by_element": {}}
	var sp: Dictionary = _motion.get("species", {})
	if sp.has(species):
		return str(sp[species])
	if not elements.is_empty():
		return str((_motion.get("by_element", {}) as Dictionary).get(Elements.E.keys()[elements[0]], "slide"))
	return "slide"

## Wind-up before an art (item 2331): physical arts pull back 3 px and snap forward, focus arts
## rise 2 px and drop as they fire, status arts bob twice.
func windup(kind: int, toward: Vector2) -> void:
	if Juice.reduced():
		return
	match kind:
		MoveData.Kind.PHYSICAL:
			await Juice.tween(self, "position", _home - (toward.normalized() * 3.0).round(), "move", 0.08).finished
			await lunge(toward)
		MoveData.Kind.FOCUS:
			await Juice.tween(self, "position", _home + Vector2(0, -2), "move", 0.1).finished
			await Juice.tween(self, "position", _home, "impact", 0.06).finished
		_:
			for i: int in 2:
				await Juice.tween(self, "position", _home + Vector2(0, -1), "impact", 0.05).finished
				await Juice.tween(self, "position", _home, "move", 0.05).finished

func step_back(to_left: bool) -> void:
	Juice.tween(self, "modulate:a", 0.0, "move", STEP_TIME)
	await Juice.tween(self, "position", _home + Vector2(-STEP_OUT_DISTANCE if to_left else STEP_OUT_DISTANCE, 0), "move", STEP_TIME).finished
	position = _home

func lunge(toward: Vector2) -> void:
	if Juice.reduced():
		return
	await Juice.tween(self, "position", _home + toward, "impact", 0.08).finished
	await Juice.tween(self, "position", _home, "move", 0.12).finished

## Pushed 3 px away from the attacker, springs back in 0.15 s (item 2332). Under reduced
## motion only a 1 px jolt (item 2258).
func knockback(away: Vector2) -> void:
	var d: Vector2 = away.normalized()
	if Juice.reduced():
		position = _home + d.round()
		await get_tree().create_timer(0.05).timeout
		position = _home
		return
	await Juice.tween(self, "position", _home + (d * KNOCKBACK_PX).round(), "impact").finished
	await Juice.tween(self, "position", _home, "move", 0.15).finished

func hit_flash() -> void:
	if Juice.reduced():
		# One soft dim instead of blinking (no flashes).
		modulate.a = 0.6
		await get_tree().create_timer(0.12 / Juice.speed()).timeout
		modulate.a = 1.0
		return
	for i: int in HIT_FLASHES:
		visible = false
		await get_tree().create_timer(0.05 / Juice.speed()).timeout
		visible = true
		await get_tree().create_timer(0.05 / Juice.speed()).timeout

func faint() -> void:
	Juice.tween(self, "modulate:a", 0.0, "move", 0.4)
	await Juice.tween(self, "position", _home + Vector2(0, 12), "move", 0.4).finished
	visible = false
	position = _home

func _draw() -> void:
	if spirling == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_set_transform(draw_offset)
	if _texture != null:
		if mirrored:
			draw_set_transform(Vector2(size.x, 0) + draw_offset, 0.0, Vector2(-1, 1))
		draw_texture_rect(_texture, r, false, GLEAM_TINT if spirling.gleam else (PRISM_TINT if spirling.prism else Color.WHITE))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var els: Array[int] = spirling.elements()
	draw_rect(r, Elements.color(els[0]))
	if els.size() > 1:
		# Second element as a lower band.
		draw_rect(Rect2(0, size.y * 0.66, size.x, size.y * 0.34), Elements.color(els[1]))
	draw_rect(r, UITheme.INK, false, 1.0)
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size() * 2
	draw_string(font, Vector2(0, size.y / 2 + fs / 3.0), spirling.data.species_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, UITheme.INK)
	# Back sprites get a small notch so the two sides read differently.
	if facing == "back":
		draw_rect(Rect2(0 if mirrored else size.x - 8, 0, 8, 8), UITheme.BG)
