class_name SafeArea
extends RefCounted
## Notch / Dynamic Island / gesture bar insets in viewport units (item 60).
## Every full-screen UI root applies these so nothing important sits under the cut-outs.

## A pretend screen for tests (plan item 2212): screen size and safe area in screen pixels.
## Empty means the real display.
static var simulated: Dictionary = {}

## Pretends the screen is [param screen] pixels with [param top] and [param bottom] pixels
## taken by the notch and the gesture bar.
static func simulate(screen: Vector2, top: float, bottom: float, left: float = 0.0, right: float = 0.0) -> void:
	simulated = {"screen": screen, "safe": Rect2(left, top, screen.x - left - right, screen.y - top - bottom)}

## Back to the real display.
static func stop_simulating() -> void:
	simulated = {}

## The safe rect inside a viewport of size [param vp].
static func rect(vp: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, vp)
	if simulated.is_empty() and DisplayServer.get_name() == "headless":
		return full
	var screen_size: Vector2 = simulated.get("screen", Vector2(DisplayServer.window_get_size()))
	var safe_px: Rect2 = simulated.get("safe", Rect2(DisplayServer.get_display_safe_area()))
	if screen_size.x <= 0.0 or safe_px.size.x <= 0.0:
		return full
	var scale: Vector2 = vp / screen_size
	var r := Rect2(safe_px.position * scale, safe_px.size * scale)
	return full.intersection(r) if full.intersects(r) else full

## Insets the offsets of a full-rect [param c] so its content stays inside the safe area.
## [param extra] is added on every side (the control's own margin).
static func apply(c: Control, extra: float = 0.0) -> void:
	var vp: Vector2 = c.get_viewport().get_visible_rect().size if c.is_inside_tree() else Vector2.ZERO
	var r: Rect2 = rect(vp) if vp != Vector2.ZERO else Rect2()
	var top: float = r.position.y if vp != Vector2.ZERO else 0.0
	var left: float = r.position.x if vp != Vector2.ZERO else 0.0
	var right: float = (vp.x - r.end.x) if vp != Vector2.ZERO else 0.0
	var bottom: float = (vp.y - r.end.y) if vp != Vector2.ZERO else 0.0
	c.offset_left = left + extra
	c.offset_top = top + extra
	c.offset_right = -(right + extra)
	c.offset_bottom = -(bottom + extra)
