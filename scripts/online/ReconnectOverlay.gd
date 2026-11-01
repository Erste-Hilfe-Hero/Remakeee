class_name ReconnectOverlay
extends CanvasLayer
## "Connection lost" screen over everything while the game is playing (item 7). The game is
## paused underneath and nothing is lost; Online keeps retrying and hides this when it is back.

var _paused_by_us: bool = false
var _label: Label

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -62
	panel.offset_right = 62
	panel.offset_top = -30
	panel.offset_bottom = 30
	root.add_child(panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.text = "Connection lost.\nReconnecting...\nYour journey is safe."
	panel.add_child(_label)

func show_overlay() -> void:
	if visible:
		return
	visible = true
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true

func hide_overlay() -> void:
	if not visible:
		return
	visible = false
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
