class_name WeatherLayer
extends Control
## Plain weather dots over the world (area 3 item 1144): rain falls, wind drifts sideways, fog is
## a pale veil, a storm adds heavier rain. UITheme colours only; area 6 brings the real look.
## With "Less motion" on, the dots stand still.

const DOTS: int = 36
var kind: String = "clear"
var _dots: Array[ColorRect] = []
var _veil: ColorRect

func _ready() -> void:
	name = "weather"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	for i: int in DOTS:
		var d := ColorRect.new()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		_dots.append(d)
	show_kind("clear")

func show_kind(k: String) -> void:
	kind = k
	if _veil == null:
		return
	var fog: bool = k == "fog"
	_veil.visible = fog or k == "storm"
	_veil.color = Color(UITheme.BG, 0.35) if fog else Color(UITheme.INK, 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w: float = maxf(size.x, 320.0)
	var h: float = maxf(size.y, 180.0)
	for i: int in _dots.size():
		var d: ColorRect = _dots[i]
		d.visible = k in ["rain", "storm", "wind"] and (k != "rain" or i % 2 == 0)
		d.size = Vector2(3, 1) if k == "wind" else Vector2(1, 3)
		d.color = Color(UITheme.BG, 0.8) if k == "wind" else Color(UITheme.MID, 0.7)
		d.position = Vector2(rng.randf() * w, rng.randf() * h)

func visible_dots() -> int:
	var n: int = 0
	for d: ColorRect in _dots:
		if d.visible:
			n += 1
	return n

func _process(delta: float) -> void:
	if kind == "clear" or kind == "fog" or GameState.reduce_motion:
		return
	var v: Vector2 = Vector2(90, 10) if kind == "wind" else Vector2(-12, 140 if kind == "storm" else 100)
	var w: float = maxf(size.x, 1.0)
	var h: float = maxf(size.y, 1.0)
	for d: ColorRect in _dots:
		if not d.visible:
			continue
		d.position += v * delta
		d.position = Vector2(fposmod(d.position.x, w), fposmod(d.position.y, h))
