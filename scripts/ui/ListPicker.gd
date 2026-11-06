class_name ListPicker
extends PanelContainer
## Modal list of choices. pick() is awaitable and returns the chosen index, or -1 on cancel.
##
## Tap safety (plan items 1781, 1782, 1785, 1786): a row fires on release, only when the finger
## moved at most TAP_SLOP pixels since it went down (so scrolling never picks a row), and only
## when that finger went down after the list opened plus a short guard (so the second tap of a
## quick double tap cannot pick a row in the next menu).

signal picked(index: int)

const ROW_HEIGHT: int = 16
## Pixels a finger may move between press and release and still count as a tap.
const TAP_SLOP: float = 6.0
## Taps that start this soon after a list opens are ignored (double-tap guard).
const TAP_GUARD_MS: int = 120
## Guard for questions whose answer cannot be undone.
const DANGER_GUARD_MS: int = 300
## Left room in every row for the focus pointer (item 2088).
const POINTER_SPACE: int = 5

var _box: VBoxContainer
var _title: Label
var _scroll: ScrollContainer
var _buttons: Array[Button] = []
var _cancellable: bool = true
var _opened_ms: int = 0
var _guard_ms: int = TAP_GUARD_MS
## Pointer bookkeeping: where and when the last finger went down, and the frame of the last
## release together with how far it moved.
var _press_pos: Vector2 = Vector2(NAN, NAN)
var _press_ms: int = -1
var _release_frame: int = -1
var _release_ok: bool = true
## Last chosen row per menu title (item 1836), so coming back keeps your place.
var _remembered: Dictionary[String, int] = {}

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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A calm tap never counts as a swipe (item 1785).
	_scroll.scroll_deadzone = int(TAP_SLOP)
	root.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 1)
	_scroll.add_child(_box)

## [param entries]: Array of {"text": String, "disabled": bool, "danger": bool}.
## [param cancellable] adds a Back row. [param focus]: row to focus first (-1 = remembered or
## first enabled row). [param guard_ms]: how long taps are ignored after the list opens.
func pick(title: String, entries: Array[Dictionary], cancellable: bool = true, focus: int = -1,
		guard_ms: int = TAP_GUARD_MS) -> int:
	_title.text = title
	_cancellable = cancellable
	_guard_ms = guard_ms
	for b: Button in _buttons:
		b.queue_free()
	_buttons.clear()
	var rows: Array[Dictionary] = entries.duplicate()
	if cancellable:
		rows.append({"text": "Back", "cancel": true})
	for i: int in rows.size():
		var b := Button.new()
		var text: String = str(rows[i].get("text", ""))
		# Irreversible answers carry a warning mark (item 1837).
		if bool(rows[i].get("danger", false)):
			b.text = Loc.t(text)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			b.text = "! " + b.text
		else:
			b.text = text
		b.disabled = bool(rows[i].get("disabled", false))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		b.clip_text = true
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := b.get_theme_stylebox(state, "Button").duplicate() as StyleBox
			sb.content_margin_left = POINTER_SPACE
			b.add_theme_stylebox_override(state, sb)
		var result: int = -1 if bool(rows[i].get("cancel", false)) else i
		b.pressed.connect(func() -> void: _on_row(result))
		b.focus_entered.connect(func() -> void:
			if visible:
				Sound.sfx("select")
			b.queue_redraw())
		b.focus_exited.connect(b.queue_redraw)
		b.draw.connect(func() -> void: _draw_pointer(b))
		_box.add_child(b)
		_buttons.append(b)
	_set_accessibility(title)
	_opened_ms = Time.get_ticks_msec()
	_press_pos = Vector2(NAN, NAN)
	_press_ms = -1
	visible = true
	var want: int = focus
	if want < 0:
		want = int(_remembered.get(title, -1))
	_focus_row.call_deferred(want)
	var index: int = await picked
	visible = false
	if index >= 0:
		_remembered[title] = index
	return index

## The row the list would focus, or the first enabled one.
func _focus_row(want: int) -> void:
	var target: Button = null
	if want >= 0 and want < _buttons.size() and not _buttons[want].disabled:
		target = _buttons[want]
	else:
		for b: Button in _buttons:
			if not b.disabled:
				target = b
				break
	if target != null and is_instance_valid(target):
		target.grab_focus()
		_scroll.ensure_control_visible.call_deferred(target)

func _on_row(result: int) -> void:
	if not visible or not _tap_allowed():
		return
	Sound.sfx("cancel" if result < 0 else "confirm")
	picked.emit(result)

## A press from a finger or mouse must be a calm tap that started after the guard time.
## Keyboard and gamepad presses (no pointer release this frame) always count.
func _tap_allowed() -> bool:
	if _release_frame != Engine.get_process_frames():
		return true
	if not _release_ok:
		return false
	return _press_ms >= 0 and _press_ms - _opened_ms >= _guard_ms

## Seen before the GUI, so the row's own pressed signal can ask how the finger moved.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if TapInput.is_press(event):
		_press_pos = TapInput.position(event)
		_press_ms = Time.get_ticks_msec()
	elif TapInput.is_release(event):
		_release_frame = Engine.get_process_frames()
		_release_ok = not is_nan(_press_pos.x) and TapInput.position(event).distance_to(_press_pos) <= TAP_SLOP
		_press_pos = Vector2(NAN, NAN)

## A small ink triangle left of the focused row, so focus shows without colour (item 2088).
func _draw_pointer(b: Button) -> void:
	if not b.has_focus():
		return
	var cy: float = floorf(b.size.y / 2.0)
	var col: Color = b.get_theme_color("font_focus_color", "Button")
	b.draw_colored_polygon(PackedVector2Array([Vector2(1, cy - 2), Vector2(4, cy + 0.5), Vector2(1, cy + 3)]), col)

## Screen readers: each row says its text, state and place (item 2085).
func _set_accessibility(title: String) -> void:
	var n: int = _buttons.size()
	for i: int in n:
		var b: Button = _buttons[i]
		var state: String = Loc.t("unavailable") + ", " if b.disabled else ""
		var shown: String = b.text if b.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else Loc.t(b.text)
		b.accessibility_name = "%s, %s%s" % [shown, state, Loc.t("%d of %d" % [i + 1, n])]
	_title.accessibility_live = AccessibilityServer.LIVE_POLITE
	_title.accessibility_name = Loc.t(title)

## The Back row's index while a cancellable list is open (tests and the back button).
func back_index() -> int:
	return _buttons.size() - 1 if _cancellable else -1

## Rows currently shown (tests).
func buttons() -> Array[Button]:
	return _buttons

func _unhandled_input(event: InputEvent) -> void:
	if visible and _cancellable and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sound.sfx("cancel")
		picked.emit(-1)
