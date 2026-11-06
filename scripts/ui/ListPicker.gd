class_name ListPicker
extends PanelContainer
## Modal list of choices. pick() is awaitable and returns the chosen index, or -1 on cancel.

signal picked(index: int)

const ROW_HEIGHT: int = 16

var _box: VBoxContainer
var _title: Label
var _buttons: Array[Button] = []
var _cancellable: bool = true
## Paper marker at the right end of the focused (ink) row; glides between rows (item 2416). A Node2D, so the
## VBoxContainer does not lay it out.
var _cursor: ListCursor
const CURSOR_TIME: float = 0.06
var _cursor_btn: Button
var _cursor_tw: Tween

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
	_cursor = ListCursor.new()
	_cursor.visible = false
	_cursor.z_index = 1
	_box.add_child(_cursor)

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
		b.pressed.connect(func() -> void:
			Sound.sfx("cancel" if result < 0 else "confirm")
			picked.emit(result))
		b.focus_entered.connect(func() -> void:
			_move_cursor(b)
			if visible:
				Sound.sfx("select"))
		Juice.press_feedback(b)
		_box.add_child(b)
		_buttons.append(b)
	visible = true
	for b: Button in _buttons:
		if not b.disabled:
			b.grab_focus.call_deferred()
			break
	var index: int = await picked
	visible = false
	_cursor.visible = false
	return index

## Glides the marker to [param b]'s row with the "move" curve in 0.06 s (jumps on the first row).
func _move_cursor(b: Button) -> void:
	var first: bool = not _cursor.visible or not is_instance_valid(_cursor_btn)
	_cursor_btn = b
	if first:
		_cursor.position = _cursor_spot(b)
		_cursor.visible = true
		return
	_cursor_tw = Juice.tween(_cursor, "position", _cursor_spot(b), "move", CURSOR_TIME)

func _cursor_spot(b: Button) -> Vector2:
	return Vector2(b.position.x + b.size.x - 6.0, b.position.y + floorf(b.size.y / 2.0) - 2.0).round()

## Keeps the marker on its row when the list is laid out again (first frame, scrolling).
func _process(_delta: float) -> void:
	if not visible or not _cursor.visible or not is_instance_valid(_cursor_btn):
		return
	if _cursor_tw != null and _cursor_tw.is_running():
		return
	_cursor.position = _cursor_spot(_cursor_btn)
