class_name UITheme
extends RefCounted
## Builds the shared UI Theme in code. Original look: flat panels with a 1 px inner rule,
## square corners, no rounded "battle box" shapes.

const FONT_SIZE: int = 8
const BG: Color = Color("f4f1e6")
const INK: Color = Color("20241c")
const MID: Color = Color("7d8a6a")
const ACCENT: Color = Color("c7d6a4")
const DISABLED: Color = Color("a6a89c")

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func panel_style(bg: Color = BG, border: Color = INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	sb.anti_aliasing = false
	return sb

static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.default_font = PixelFont.get_font()
	t.set_color("font_color", "Label", INK)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg: Color = BG
		if state == "hover" or state == "focus":
			bg = ACCENT
		elif state == "pressed":
			bg = MID
		var sb: StyleBoxFlat = panel_style(bg, INK if state != "disabled" else DISABLED)
		sb.set_content_margin_all(2)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", DISABLED)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	return t
