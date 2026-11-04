class_name TextBox
extends PanelContainer
## Typewriter text box. show_text() is awaitable: it returns once the player taps / presses
## accept after the text is fully shown (or immediately-ish in auto mode).

signal advanced

## Seconds to linger before auto-advancing when [member auto_advance] is on.
const AUTO_DELAY: float = 0.35
const MARGIN: int = 3

var auto_advance: bool = false
var chars_per_second: float = 60.0

var _label: Label
var _arrow: Label
## Right padding reserved for the continue marker.
const ARROW_SPACE: int = 6
var _typing: bool = false
var _waiting: bool = false
var _visible_chars: float = 0.0

func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style())
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	# Text is translated once in show_text() so the typewriter counts the shown characters.
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# Screen readers announce each new line as it appears (item 77).
	_label.accessibility_live = AccessibilityServer.LIVE_POLITE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Keep wrapped text clear of the continue marker in the corner.
	var pad := StyleBoxEmpty.new()
	pad.content_margin_right = ARROW_SPACE
	_label.add_theme_stylebox_override("normal", pad)
	add_child(_label)
	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_arrow.visible = false
	add_child(_arrow)

## Shows [param text] with the typewriter effect and waits for the player (or the auto timer).
func show_text(text: String) -> void:
	# Story lines may address the player by name: "{name}" (after translation).
	_label.text = Loc.t(text).replace("{name}", GameState.tamer_name)
	_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	_waiting = false
	_arrow.visible = false
	while _typing:
		await get_tree().process_frame
	if auto_advance:
		await get_tree().create_timer(AUTO_DELAY).timeout
		return
	_waiting = true
	_arrow.visible = true
	await advanced
	_arrow.visible = false

## Shows text without waiting (prompts such as "Orders for Kindlop?").
func show_prompt(text: String) -> void:
	_label.text = Loc.t(text)
	_label.visible_characters = -1
	_typing = false
	_waiting = false
	_arrow.visible = false

func _process(delta: float) -> void:
	if not _typing:
		return
	_visible_chars += delta * chars_per_second
	_label.visible_characters = int(_visible_chars)
	if _label.visible_characters >= _label.get_total_character_count():
		_label.visible_characters = -1
		_typing = false

func _skip_or_advance() -> void:
	if _typing:
		_label.visible_characters = -1
		_typing = false
	elif _waiting:
		_waiting = false
		advanced.emit()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_skip_or_advance()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if (_typing or _waiting) and event.is_action_pressed("ui_accept"):
		_skip_or_advance()
		get_viewport().set_input_as_handled()
