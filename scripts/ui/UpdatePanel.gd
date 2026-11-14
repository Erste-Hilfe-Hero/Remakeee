class_name UpdatePanel
extends CanvasLayer
## The update panel over everything (docs/LIVE_CONTENT.md, "In-game updates"): a title, a text,
## an optional progress bar with its size line, and up to three buttons. AppUpdater fills it.

signal chosen(index: int)

var _root: Control
var _title: Label
var _body: Label
var _bar: ProgressBar
var _size: Label
var _buttons: VBoxContainer

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -64
	panel.offset_right = 64
	panel.offset_top = -60
	panel.offset_bottom = 60
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_title = _label()
	_title.text = "Update available"
	v.add_child(_title)
	_body = _label()
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_body.accessibility_live = AccessibilityServer.LIVE_POLITE
	v.add_child(_body)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.visible = false
	v.add_child(_bar)
	_size = _label()
	_size.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_size.visible = false
	v.add_child(_size)
	_buttons = VBoxContainer.new()
	v.add_child(_buttons)

func _label() -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(1, 0)
	return l

## Shows [param body] (English, translated here) with [param buttons] (English labels, the
## buttons translate themselves). No buttons: the panel only informs, e.g. while Google's
## update screen is open.
func show_view(body: String, buttons: Array[String] = []) -> void:
	visible = true
	_body.text = Loc.t(body)
	for b: Node in _buttons.get_children():
		b.queue_free()
	for i: int in buttons.size():
		var btn := Button.new()
		btn.text = buttons[i]
		btn.pressed.connect(func() -> void: chosen.emit(i))
		_buttons.add_child(btn)
		if i == 0:
			btn.call_deferred("grab_focus")

## [param p] from 0.0 to 1.0, or below 0 while the size is unknown; [param line] under the bar.
func set_progress(p: float, line: String) -> void:
	_bar.visible = true
	_bar.indeterminate = p < 0.0
	_bar.value = maxf(p, 0.0)
	_size.visible = not line.is_empty()
	_size.text = line

func hide_progress() -> void:
	_bar.visible = false
	_size.visible = false

func close() -> void:
	visible = false
	hide_progress()

func body_text() -> String:
	return _body.text

func button_texts() -> Array[String]:
	var out: Array[String] = []
	for b: Node in _buttons.get_children():
		if b is Button and not b.is_queued_for_deletion():
			out.append((b as Button).text)
	return out
