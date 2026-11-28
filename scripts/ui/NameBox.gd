class_name NameBox
extends PanelContainer
## The Wayfarer's name box (items 1961, 1966, 36): a line with a "4/10" counter, the phone's own
## keyboard where there is one and the game's letter keys for gamepads and the iPhone browser.
## Since 1.3.2 it opens in Brindlewick, when the story goes on (Opening); until then the
## journey uses the default name.

signal _done(text: String)

const MAX: int = 10
## What ask() returns when Back was pressed.
const BACK: String = "\n"
const TITLE: String = "Your name?"

var _edit: LineEdit
var _keys: NameKeyboard

func _init() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(136, 128)
	offset_left = -68
	offset_right = 68
	offset_top = -64
	offset_bottom = 64
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var l := Label.new()
	l.text = TITLE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# "Please pick another name." wraps instead of widening the box (200 list item 7).
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(l)
	_edit = LineEdit.new()
	_edit.max_length = MAX
	var counter: CharCounter = CharCounter.make(_edit, MAX)
	counter.ask_label = l
	counter.ask_text = l.text
	head.add_child(counter)
	_edit.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.ACCENT, UITheme.INK))
	_edit.add_theme_color_override("font_color", UITheme.INK)
	_edit.text_submitted.connect(func(t: String) -> void: _done.emit(t))
	# Gamepad / virtual pad confirm also submits the name.
	_edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_accept") and not (ev is InputEventKey):
			_done.emit(_edit.text))
	v.add_child(_edit)
	# Own letter keys: the phone keyboard does not always open (iPhone browser, Ali 2026-11-04).
	_keys = NameKeyboard.new()
	_keys.target = _edit
	_keys.confirmed.connect(func() -> void: _done.emit(_edit.text))
	_keys.cancelled.connect(func() -> void: _done.emit(BACK))
	v.add_child(_keys)
	v.add_child(_keys.make_extra_row())

## Android back closes the box like B.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		_done.emit(BACK)

## Opens a name box on [param parent] with [param suggestion] until a real name comes (empty or
## only spaces is refused and the suggestion comes back); BACK when Back was pressed.
static func ask(parent: Node, suggestion: String) -> String:
	var box := NameBox.new()
	parent.add_child(box)
	box._edit.text = suggestion
	box._keys.fresh = true
	# Phones open their own keyboard (any script), gamepads use the letter keys (item 36).
	if NameKeyboard.system_keyboard_first():
		box._keys.open_system_keyboard.call_deferred()
	else:
		box._keys.focus_first()
	var name: String = ""
	while true:
		name = await box._done
		if name == BACK or NameKeyboard.valid_name(name):
			break
		Sound.sfx("cancel")
		box._edit.text = suggestion
		box._keys.fresh = true
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	box.queue_free()
	return name
