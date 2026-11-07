class_name ReconnectOverlay
extends CanvasLayer
## "Connection lost" screen over everything while the game is playing (item 7). The game is
## paused underneath and nothing is lost; Online keeps retrying and hides this when it is back.
## Short drops under SHORT_DROP seconds only show a small mark in the top right corner (item
## 2150). The big screen counts the tries, says when the next one comes, has "Try now" and,
## after a minute, "To title" (item 2147).

signal try_now
signal to_title

## Seconds without connection before the big screen and the pause.
const SHORT_DROP: float = 3.0
## Seconds before "To title" appears.
const TITLE_AFTER: float = 60.0
## The big screen fades in and out in 0.2 s and leaves the game at 60 % brightness (item 2291).
const FADE_TIME: float = 0.2
const DIM_ALPHA: float = 0.4

var _paused_by_us: bool = false
## True while the big screen fades out.
var _closing: bool = false
var _root: Control
var _label: Label
var _mark: Label
var _try_button: Button
var _title_button: Button

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mark = Label.new()
	_mark.theme = UITheme.get_theme()
	_mark.text = "(!)"
	_mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mark.offset_left = -18
	_mark.offset_top = 2
	_mark.offset_right = -2
	_mark.add_theme_stylebox_override("normal", UITheme.flat_style(UITheme.BG, UITheme.INK))
	_mark.accessibility_name = "Connection lost. Reconnecting."
	add_child(_mark)
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -64
	panel.offset_right = 64
	panel.offset_top = -48
	panel.offset_bottom = 48
	_root.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(1, 0)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	v.add_child(_label)
	_try_button = Button.new()
	_try_button.text = "Try now"
	_try_button.pressed.connect(func() -> void: try_now.emit())
	v.add_child(_try_button)
	_title_button = Button.new()
	_title_button.text = "To title"
	_title_button.visible = false
	_title_button.pressed.connect(func() -> void: to_title.emit())
	v.add_child(_title_button)
	update_view(1, 0.0, 0.0)

## Text of the big screen for try [param tries], [param next_in] seconds to the next one.
static func status_text(tries: int, next_in: float) -> String:
	var lines: Array[String] = [Loc.t("Connection lost. Your journey is safe.")]
	if next_in > 0.5:
		lines.append(Loc.t("Try %d. Next try in %d s." % [tries, ceili(next_in)]))
	else:
		lines.append(Loc.t("Try %d. Connecting..." % tries))
	return "\n".join(lines)

## Called by Online every frame while there is no connection.
func update_view(tries: int, next_in: float, offline_for: float) -> void:
	var big: bool = offline_for >= SHORT_DROP
	_mark.visible = not big
	if big and (not _root.visible or _closing):
		if not _root.visible:
			_root.modulate.a = 0.0
		_closing = false
		_root.visible = true
		Juice.tween(_root, "modulate:a", 1.0, "fade", FADE_TIME)
	elif not big:
		_root.visible = false
	_label.text = status_text(tries, next_in)
	_title_button.visible = offline_for >= TITLE_AFTER
	if big:
		if not get_tree().paused:
			get_tree().paused = true
			_paused_by_us = true
		if not (_try_button.has_focus() or _title_button.has_focus()):
			_try_button.grab_focus()

func is_big() -> bool:
	return visible and _root.visible

func show_overlay() -> void:
	visible = true

func hide_overlay() -> void:
	# Online calls this every frame while connected; one fade-out at a time.
	if not visible or _closing:
		return
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false
	if _root.visible:
		_closing = true
		await Juice.tween(_root, "modulate:a", 0.0, "fade", FADE_TIME).finished
		# Connection lost again while fading out: the screen stays.
		if not _closing:
			return
		_closing = false
	visible = false
	_root.visible = false
