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
## At most this many lines per window; longer texts go on to the next window (item 2043).
const MAX_LINES: int = 3
## Holding the box (or A) this long runs on to the next question (item 2013).
const LONG_PRESS_MS: int = 600
## Set by the overworld: a long press fast-forwards. Battles keep every line.
var allow_fast_forward: bool = false
## True after a long press, until the box hides (questions open after the box hides).
var fast_forward: bool = false
var _press_ms: int = -1

var _label: Label
var _arrow: Label
## Name tag over the box for the one who speaks (plan item 1343).
var _tag: Label
const TAG_HEIGHT: int = 11
## Right padding reserved for the continue marker.
const ARROW_SPACE: int = 6
var _typing: bool = false
var _waiting: bool = false
var _visible_chars: float = 0.0
## Taps this soon after a line is fully shown are ignored, so the second tap of a double tap
## cannot skip a line unread (item 1783).
const READ_GUARD_MS: int = 150
var _shown_ms: int = -100000

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
	_tag = Label.new()
	_tag.top_level = true
	_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tag.add_theme_stylebox_override("normal", UITheme.panel_style())
	_tag.visible = false
	add_child(_tag)
	visibility_changed.connect(func() -> void:
		if not visible:
			fast_forward = false
			_press_ms = -1)

## Shows [param text] with the typewriter effect and waits for the player (or the auto timer).
func show_text(text: String, speaker: String = "") -> void:
	# Story lines may address the player by name: "{name}" (after translation).
	var shown: String = Loc.t(text).replace("{name}", GameState.tamer_name)
	# Old lines carry the speaker as "Aldo: ..."; it moves to the name tag. A name in the
	# line wins over the one passed in (the NPC's role, item 2011).
	var parts: PackedStringArray = Dialogue.split_speaker(shown)
	if not parts[0].is_empty():
		speaker = parts[0]
		shown = parts[1]
	else:
		speaker = Loc.t(speaker).replace("{name}", GameState.tamer_name)
	set_speaker(speaker)
	for page: String in split_lines(shown, _text_width(), _label.get_theme_font("font"),
			_label.get_theme_font_size("font_size"), MAX_LINES):
		await _show_page(page)

func _show_page(page: String) -> void:
	_label.text = page
	if fast_forward:
		_label.visible_characters = -1
		_typing = false
		_waiting = false
		await get_tree().process_frame
		return
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
func show_prompt(text: String, speaker: String = "") -> void:
	var shown: String = Loc.t(text).replace("{name}", GameState.tamer_name)
	if speaker.is_empty():
		var parts: PackedStringArray = Dialogue.split_speaker(shown)
		speaker = parts[0]
		shown = parts[1]
	set_speaker(speaker)
	_label.text = shown
	_label.visible_characters = -1
	_typing = false
	_waiting = false
	_arrow.visible = false

## Shows [param who] on the name tag over the box ("" hides it).
func set_speaker(who: String) -> void:
	_tag.text = who
	_tag.visible = not who.is_empty()
	_place_tag()

func speaker() -> String:
	return _tag.text if _tag.visible else ""

func _place_tag() -> void:
	if _tag.visible:
		_tag.global_position = global_position + Vector2(2, -TAG_HEIGHT + 1)
		_tag.visible = is_visible_in_tree()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _tag != null:
		_tag.visible = is_visible_in_tree() and not _tag.text.is_empty()
		_place_tag()

## Width the text can use inside the box.
func _text_width() -> float:
	var w: float = size.x if size.x > 0.0 else get_viewport_rect().size.x
	var sb: StyleBox = get_theme_stylebox("panel")
	if sb != null:
		w -= sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	return w - ARROW_SPACE

## Wraps [param text] word by word to [param width] and groups the lines into windows of
## [param max_lines]. A line break in the text starts a new line.
static func split_lines(text: String, width: float, font: Font, font_size: int, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	for para: String in text.split("\n"):
		var line: String = ""
		for word: String in para.split(" ", false):
			var tried: String = word if line.is_empty() else line + " " + word
			if line.is_empty() or font.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
				line = tried
			else:
				lines.append(line)
				line = word
		lines.append(line)
	var pages: Array[String] = []
	for i: int in range(0, lines.size(), maxi(1, max_lines)):
		pages.append("\n".join(lines.slice(i, i + max_lines)))
	return pages

## Starts fast-forward: the current line ends, the next ones run without waiting.
func start_fast_forward() -> void:
	if not allow_fast_forward:
		return
	fast_forward = true
	_press_ms = -1
	if _typing:
		_label.visible_characters = -1
		_typing = false
	elif _waiting:
		_waiting = false
		advanced.emit()

func _process(delta: float) -> void:
	if _press_ms >= 0 and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		start_fast_forward()
	if _tag.visible:
		_place_tag()
	if not _typing:
		return
	_visible_chars += delta * chars_per_second
	_label.visible_characters = int(_visible_chars)
	if _label.visible_characters >= _label.get_total_character_count():
		_label.visible_characters = -1
		_typing = false
		_shown_ms = Time.get_ticks_msec()

## Finishes the current line and continues at once (scene "Skip").
func advance_now() -> void:
	if _typing:
		_label.visible_characters = -1
		_typing = false
	if _waiting:
		_waiting = false
		advanced.emit()

func _skip_or_advance(tap: bool = false) -> void:
	if _typing:
		_label.visible_characters = -1
		_typing = false
		_shown_ms = Time.get_ticks_msec()
	elif _waiting:
		if tap and Time.get_ticks_msec() - _shown_ms < READ_GUARD_MS:
			return
		_waiting = false
		advanced.emit()

func _gui_input(event: InputEvent) -> void:
	if TapInput.is_press(event):
		_press_ms = Time.get_ticks_msec()
		_skip_or_advance(true)
		accept_event()
	elif TapInput.is_release(event):
		_press_ms = -1

func _unhandled_input(event: InputEvent) -> void:
	if (_typing or _waiting) and event.is_action_pressed("ui_accept"):
		_press_ms = Time.get_ticks_msec()
		_skip_or_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_accept"):
		_press_ms = -1
