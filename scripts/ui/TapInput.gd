class_name TapInput
extends RefCounted
## One tap = one press. Godot turns every touch into an emulated left click as well
## (input_devices/pointing/emulate_mouse_from_touch, on by default), so a handler that accepts
## both InputEventScreenTouch and InputEventMouseButton sees each finger tap twice: text skipped
## a line, and the echo call registered every mark twice and always failed on phones.
## These helpers accept the click and only fall back to the raw touch when emulation is off.

static func _touch_counts() -> bool:
	return not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))

## True for a finger/left-button press.
static func is_press(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null:
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	var st := event as InputEventScreenTouch
	return st != null and st.pressed and _touch_counts()

## True for a finger/left-button release.
static func is_release(event: InputEvent) -> bool:
	var mb := event as InputEventMouseButton
	if mb != null:
		return not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	var st := event as InputEventScreenTouch
	return st != null and not st.pressed and _touch_counts()

## Position of a press or release (only meaningful when is_press / is_release is true).
static func position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO

## Each finger on its own, for the on-screen D-pad (item 1809), which must follow a thumb while
## another finger presses A: {"finger": index, "pos": Vector2, "kind": "down"/"move"/"up"},
## or {} for any other event. Menus and the map use is_press / is_release instead.
static func finger(event: InputEvent) -> Dictionary:
	var st := event as InputEventScreenTouch
	if st != null:
		return {"finger": st.index, "pos": st.position, "kind": "down" if st.pressed else "up"}
	var sd := event as InputEventScreenDrag
	if sd != null:
		return {"finger": sd.index, "pos": sd.position, "kind": "move"}
	return {}
