class_name BattleCamera
extends RefCounted
## Era V battle camera: on an art the field zooms in a little around a point a share of the
## way from the field centre toward the attacker/target midpoint, then eases back. Works through
## scale and pivot_offset only, so the screen shake (which owns position) keeps working.
## Off below Era V and under reduced motion.

static func cam_cfg() -> Dictionary:
	return BattleAnim.config().get("camera", {})

## Zoom factor and pivot for a field of [param field_size] framing [param a] against [param b].
## The pivot stays inside the field, so zooming (factor >= 1) never shows an edge.
static func focus(field_size: Vector2, a: Rect2, b: Rect2) -> Dictionary:
	var c: Dictionary = cam_cfg()
	var z: float = maxf(float(c.get("zoom", 1.0)), 1.0)
	var share: float = clampf(float(c.get("pan_share", 0.0)), 0.0, 1.0)
	var mid: Vector2 = (a.get_center() + b.get_center()) / 2.0
	var look: Vector2 = (field_size / 2.0).lerp(mid, share)
	look = Vector2(clampf(look.x, 0.0, field_size.x), clampf(look.y, 0.0, field_size.y)).round()
	return {"scale": Vector2(z, z), "pivot": look}

static func active() -> bool:
	return BattleAnim.enabled() and not Juice.reduced()

## Zooms [param node] in on the attacker/target pair. Awaitable; returns at once when inactive.
static func push(node: Control, a: Rect2, b: Rect2) -> void:
	if not active() or node == null:
		return
	var f: Dictionary = focus(node.size, a, b)
	node.pivot_offset = f.pivot
	var t: float = float(cam_cfg().get("in_time", 0.18)) / Juice.speed()
	var tw: Tween = node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", f.scale, t)
	await tw.finished

## Eases [param node] back to rest framing after a short hold. Awaitable.
static func release(node: Control) -> void:
	if node == null or node.scale == Vector2.ONE:
		return
	var c: Dictionary = cam_cfg()
	var tw: Tween = node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(float(c.get("hold_time", 0.12)) / Juice.speed())
	tw.tween_property(node, "scale", Vector2.ONE, float(c.get("out_time", 0.22)) / Juice.speed())
	await tw.finished
