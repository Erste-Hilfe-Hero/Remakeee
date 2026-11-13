class_name TextPrompt
extends PanelContainer
## A small box that asks for one line of text (email, password, friend code).
## [code]var t: String = await TextPrompt.ask(parent, "Email")[/code]; "" means cancelled.

signal _done(text: String)

var _edit: LineEdit
## Boxes of up to this many characters show the "4/10" counter.
const NAME_COUNTER_MAX: int = 16

static func ask(parent: Node, title: String, secret: bool = false, max_len: int = 64, initial: String = "") -> String:
	var p := TextPrompt.new()
	parent.add_child(p)
	p._build(title, secret, max_len, initial)
	var t: String = await p._done
	p.queue_free()
	return t.strip_edges()

func _build(title: String, secret: bool, max_len: int, initial: String) -> void:
	theme = UITheme.get_theme()
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -64
	offset_right = 64
	offset_top = -34
	offset_bottom = 34
	var v := VBoxContainer.new()
	add_child(v)
	var l := Label.new()
	l.text = title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	_edit = LineEdit.new()
	_edit.max_length = max_len
	_edit.secret = secret
	_edit.text = initial
	_edit.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_edit.add_theme_color_override("font_color", UITheme.INK)
	_edit.text_submitted.connect(func(t: String) -> void: _done.emit(t))
	v.add_child(_edit)
	# Short names (nicknames, box names) show how many characters are left (item 1966).
	if not secret and max_len <= NAME_COUNTER_MAX:
		v.add_child(CharCounter.make(_edit, max_len))
	var row := HBoxContainer.new()
	v.add_child(row)
	var ok := Button.new()
	ok.text = "OK"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void: _done.emit(_edit.text))
	row.add_child(ok)
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: _done.emit(""))
	row.add_child(back)
	_edit.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_done.emit("")
