class_name SpirlingSprite
extends Control
## Battle sprite. Uses the era sprite if one exists, otherwise a coloured placeholder
## rectangle (element colours, initial letter) as AGENTS.md asks until real art exists.

const STEP_OUT_DISTANCE: float = 40.0
const STEP_TIME: float = 0.3
const HIT_FLASHES: int = 3
const KNOCKBACK_PX: float = 3.0
## Prism variants are drawn with a warm tint over the era palette.
const PRISM_TINT: Color = Color(1.0, 0.78, 0.5)

var spirling: Spirling
var facing: String = "front"
## Draws the sprite flipped horizontally (art faces left; the battle layout needs it facing right).
var mirrored: bool = false
var speed_scale: float = 1.0
var _texture: Texture2D
var _home: Vector2

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

## Steps out beside the Wayfarer (slides in from the screen edge; never thrown). Awaitable.
## Durations come from Juice curves, so the 2x / 4x battle speed applies on its own.
func step_out(from_left: bool) -> void:
	_home = position
	position = _home + Vector2(-STEP_OUT_DISTANCE if from_left else STEP_OUT_DISTANCE, 0)
	modulate.a = 0.0
	visible = true
	Juice.tween(self, "modulate:a", 1.0, "move", STEP_TIME)
	await Juice.tween(self, "position", _home, "move", STEP_TIME).finished

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
	if _texture != null:
		if mirrored:
			draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(_texture, r, false, PRISM_TINT if spirling.prism else Color.WHITE)
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
