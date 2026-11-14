class_name BattlePause
extends Control
## The battle pause (KAMPF_PLAN_1000 item 912): the menu button or the "II" button stops the
## battle at any moment, in the middle of an art or a line of text. The whole tree waits; only
## this panel runs, and a tap, confirm, back or the menu button again lets the battle go on.

signal changed(on: bool)

var _paused_by_us: bool = false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	for line: String in BattleCalm.pause_lines():
		var l := Label.new()
		l.text = line
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(110, 0)
		box.add_child(l)
	add_child(panel)

func is_paused() -> bool:
	return visible

func open() -> void:
	if visible:
		return
	visible = true
	_paused_by_us = not get_tree().paused
	if _paused_by_us:
		get_tree().paused = true
	Sound.sfx("cancel")
	changed.emit(true)

func close() -> void:
	if not visible:
		return
	visible = false
	if _paused_by_us:
		get_tree().paused = false
	_paused_by_us = false
	Sound.sfx("confirm")
	changed.emit(false)

func _gui_input(event: InputEvent) -> void:
	if visible and BattleCalm.pause_toggle(event, true):
		accept_event()
		close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and BattleCalm.pause_toggle(event, true):
		get_viewport().set_input_as_handled()
		close()

func _exit_tree() -> void:
	if _paused_by_us:
		get_tree().paused = false
	_paused_by_us = false
