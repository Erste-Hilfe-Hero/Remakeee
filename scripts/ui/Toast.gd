class_name Toast
extends CanvasLayer
## Short notes at the top of the screen (plan area 8): unlocked badges and finished daily tasks.
## They never stop the game: input passes through and each note fades after SHOW_TIME.

const SHOW_TIME: float = 2.4
const LAYER: int = 90

var _panel: PanelContainer
var _icon: TextureRect
var _label: Label
var _queue: Array[Dictionary] = []
var _busy: bool = false

func _ready() -> void:
	layer = LAYER
	_panel = PanelContainer.new()
	_panel.theme = UITheme.get_theme()
	_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 4
	_panel.offset_right = -4
	_panel.offset_top = 4
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.custom_minimum_size = Vector2(1, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)

## Queues a note; [param icon] may be null.
func show_note(text: String, icon: Texture2D = null) -> void:
	_queue.append({"text": text, "icon": icon})
	if not _busy:
		_run()

func pending() -> int:
	return _queue.size() + (1 if _busy else 0)

func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var n: Dictionary = _queue.pop_front()
		_label.text = Loc.t(str(n.text))
		_icon.texture = n.icon
		_icon.visible = n.icon != null
		_panel.modulate.a = 1.0
		_panel.visible = true
		await get_tree().create_timer(SHOW_TIME).timeout
		if not GameState.reduce_motion:
			var tw: Tween = create_tween()
			tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
			await tw.finished
		_panel.visible = false
	_busy = false
