class_name FloatText
extends Label
## A short battle line that floats up over a Spirling and fades, instead of a text box the player
## has to tap away (owner, 9 Nov). The full line still goes to the battle log.

const RISE: float = 10.0
const TIME: float = 1.1
const WIDTH: float = 112.0
## Seconds the battle waits after a float before going on, so lines stay readable in order.
const GAP: float = 0.45

## Shows [param text] centred above [param at] under [param parent]; [param stack] lifts it
## further so lines that come quickly do not cover each other.
static func spawn(parent: Node, text: String, at: Vector2, stack: int = 0) -> FloatText:
	if parent == null or text.is_empty():
		return null
	var f := FloatText.new()
	f.text = Loc.t(text).replace("{name}", GameState.tamer_name)
	f.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.custom_minimum_size = Vector2(WIDTH, 0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_theme_color_override("font_color", UITheme.INK)
	f.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.BG, UITheme.INK))
	parent.add_child(f)
	f.reset_size()
	var vp: Vector2 = parent.get_viewport().get_visible_rect().size if parent.get_viewport() != null else Vector2(WIDTH, 0)
	var x: float = clampf(at.x - f.size.x / 2.0, 2.0, maxf(2.0, vp.x - f.size.x - 2.0))
	f.position = Vector2(x, at.y - f.size.y - stack * (f.size.y + 2)).round()
	f._run()
	return f

func _run() -> void:
	var t: Tween = create_tween().set_parallel(true)
	var time: float = TIME / Juice.speed()
	if not Juice.reduced():
		t.tween_property(self, "position:y", position.y - RISE, time)
	t.tween_property(self, "modulate:a", 0.0, time * 0.4).set_delay(time * 0.6)
	t.chain().tween_callback(queue_free)
