class_name CodePrompt
extends PanelContainer
## Asks for a code (transfer code, friend code) with the game's own keys: letters and digits,
## grouped by four, plus Paste. The phone keyboard does not always open in the browser build
## (plan items 1963, 2172). [code]var c: String = await CodePrompt.ask(parent, "Friend code", 8)[/code]
## returns the letters and digits only, or "" when cancelled.

signal _done(text: String)

var _edit: LineEdit
var keys: NameKeyboard

static func ask(parent: Node, title: String, length: int) -> String:
	var p := CodePrompt.new()
	parent.add_child(p)
	p._build(title, length)
	var t: String = await p._done
	p.queue_free()
	return NameKeyboard.raw_code(t)

func _build(title: String, length: int) -> void:
	theme = UITheme.get_theme()
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -68
	offset_right = 68
	offset_top = -70
	offset_bottom = 70
	var v := VBoxContainer.new()
	add_child(v)
	var l := Label.new()
	l.text = title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	v.add_child(l)
	_edit = LineEdit.new()
	# Dashes are added by the keys; the field takes the grouped code.
	_edit.max_length = length + maxi(0, (length - 1) / NameKeyboard.GROUP)
	_edit.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_edit.add_theme_color_override("font_color", UITheme.INK)
	_edit.text_submitted.connect(func(t: String) -> void: _done.emit(t))
	v.add_child(_edit)
	keys = NameKeyboard.new()
	keys.mode = NameKeyboard.Mode.CODE
	keys.code_length = length
	keys.target = _edit
	keys.confirmed.connect(func() -> void: _done.emit(_edit.text))
	keys.cancelled.connect(func() -> void: _done.emit(""))
	v.add_child(keys)
	v.add_child(keys.make_extra_row())
	keys.focus_first()

## Typed so far (tests).
func text() -> String:
	return _edit.text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_done.emit("")
