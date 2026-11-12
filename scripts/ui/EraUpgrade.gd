class_name EraUpgrade
extends CanvasLayer
## The era-change sequence (docs/ERA_FEEL_UI.md): EraManager switches to the new era, then this
## overlay shows the old era's look on top and lets it give way in the new era's style
## (data/era_feel.json "upgrade"), plays the era jingle and shows a one-line caption whose frame
## is first drawn in the old era's style and then redrawn in the new one. Frees itself.

signal finished

const LAYER: int = 101
const SHADER: Shader = preload("res://shaders/era_upgrade.gdshader")
## Whole sequence, the redraw sweep, and when the caption frame is redrawn.
const TIME: float = 3.2
const SWEEP: float = 1.5
const CAPTION_IN: float = 0.35
const STYLE_IDS: Dictionary[String, int] = {"radial": 1, "sharpen": 2, "unfold": 3, "breathe": 4}

var from_era: int = 1
var to_era: int = 2
var inks: Array[Color] = []
var center_px: Vector2 = Vector2(-1, -1)
var progress: float = 0.0:
	set(v):
		progress = v
		if _rect != null:
			(_rect.material as ShaderMaterial).set_shader_parameter("progress", v)

var _rect: ColorRect
var _caption: PanelContainer
var _label: Label

func setup(from: int, to: int, old_inks: Array[Color], center: Vector2) -> void:
	from_era = clampi(from, 1, 5)
	to_era = clampi(to, 1, 5)
	inks = old_inks
	center_px = center

## Shader settings for the sweep from [param from] to [param to]: style id, old resolution
## and old colour levels (0 = Era I inks).
static func params(from: int, to: int) -> Dictionary:
	return {
		"style": STYLE_IDS.get(str(EraFeel.value(to, "upgrade")), 1),
		"old_res": Vector2(EraManager.RESOLUTION[clampi(from, 1, 5)]),
		"old_levels": float(EraFeel.value(from, "levels")),
	}

func _ready() -> void:
	layer = LAYER
	var size: Vector2 = get_viewport().get_visible_rect().size
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var p: Dictionary = params(from_era, to_era)
	for k: String in p:
		mat.set_shader_parameter(k, p[k])
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	var c: Vector2 = Vector2(0.5, 0.5) if center_px.x < 0.0 else center_px / size.max(Vector2.ONE)
	mat.set_shader_parameter("center", c)
	for i: int in mini(inks.size(), 4):
		mat.set_shader_parameter("c%d" % i, inks[i])
	_rect.material = mat
	add_child(_rect)
	_caption = PanelContainer.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_bottom = -size.y * 0.18
	_caption.theme = UITheme.get_theme()
	_caption.add_theme_stylebox_override("panel", UITheme.frame_style_of(str(EraFeel.value(from_era, "frame"))))
	_caption.modulate.a = 0.0
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(size.x * 0.8, 0)
	_label.text = EraFeel.caption(to_era)
	_caption.add_child(_label)
	add_child(_caption)
	progress = 0.0
	var jingle: String = str(EraFeel.value(to_era, "jingle"))
	if not jingle.is_empty():
		Sound.sfx(jingle)
	_run()

func _run() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "progress", 1.0, SWEEP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_caption, "modulate:a", 1.0, 0.2).set_delay(CAPTION_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_redraw_frame)
	tw.tween_property(_caption, "modulate", Color(1, 1, 1, 1), 0.25).from(Color(1.6, 1.6, 1.6, 1)).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(TIME - SWEEP - 0.25 - 0.3)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_done)

## The caption frame is redrawn in the new era's style once the sweep is through.
func _redraw_frame() -> void:
	_rect.visible = false
	_caption.add_theme_stylebox_override("panel", UITheme.frame_style_of(str(EraFeel.value(to_era, "frame"))))

func _done() -> void:
	finished.emit()
	queue_free()
