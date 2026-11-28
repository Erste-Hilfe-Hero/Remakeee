class_name BackButton
extends RefCounted
## The Android back button (item 1787). The game no longer quits on it
## (application/config/quit_on_go_back is off): in menus it works like B, in the world it opens
## the pause menu, and on the title it asks "Quit Chimora?". Overworld and TitleScreen catch
## NOTIFICATION_WM_GO_BACK_REQUEST and call these helpers.

## Presses and releases B (ui_cancel) as if the player tapped it.
static func press_cancel() -> void:
	for ev: InputEventAction in cancel_events():
		Input.parse_input_event(ev)
	Input.flush_buffered_events()

## A press and a release of ui_cancel.
static func cancel_events() -> Array[InputEventAction]:
	var out: Array[InputEventAction] = []
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"ui_cancel"
		ev.pressed = pressed
		out.append(ev)
	return out
