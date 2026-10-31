class_name ListPicker
extends PanelContainer
## Modal list of choices. pick() is awaitable and returns the chosen index, or -1 on cancel.

signal picked(index: int)

const ROW_HEIGHT: int = 16

var _box: VBoxContainer
var _title: Label
var _buttons: Array[Button] = []
var _cancellable: bool = true

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	visible = false
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(1, 0)
	root.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 1)
	scroll.add_child(_box)

## [param entries]: Array of {"text": String, "disabled": bool}. [param cancellable] adds a Back row.
func pick(title: String, entries: Array[Dictionary], cancellable: bool = true) -> int:
	_title.text = title
	_cancellable = cancellable
	for b: Button in _buttons:
		b.queue_free()
	_buttons.clear()
	var rows: Array[Dictionary] = entries.duplicate()
	if cancellable:
		rows.append({"text": "Back", "cancel": true})
	for i: int in rows.size():
		var b := Button.new()
		b.text = str(rows[i].get("text", ""))
		b.disabled = bool(rows[i].get("disabled", false))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		b.clip_text = true
		var result: int = -1 if bool(rows[i].get("cancel", false)) else i
		b.pressed.connect(func() -> void: picked.emit(result))
		_box.add_child(b)
		_buttons.append(b)
	visible = true
	for b: Button in _buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break
	var index: int = await picked
	visible = false
	return index

func _unhandled_input(event: InputEvent) -> void:
	if visible and _cancellable and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		picked.emit(-1)
