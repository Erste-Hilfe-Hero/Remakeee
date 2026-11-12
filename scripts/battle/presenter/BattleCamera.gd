class_name BattleCamera
extends RefCounted
## Era V battle camera: on an art the field zooms in a little around a point a share of the
## way from the field centre toward the attacker/target midpoint, then eases back. Works through
## scale and pivot_offset only, so the screen shake (which owns position) keeps working.
## Era IV pans mildly, Era V follows every strike (data/era_battle_feel.json "camera"); Era I-III
## keep a fixed screen. Off under reduced motion.

## data/era5_anim.json "camera" with the region's own "camera" from data/region_looks.json on top
## (Quivermoor sways a little more). [param region] defaults to the region on screen.
static func cam_cfg(region: String = "", era: int = 5) -> Dictionary:
	var out: Dictionary = EraBattleFeel.camera(era) if era < 5 else (BattleAnim.config().get("camera", {}) as Dictionary).duplicate()
	if out.is_empty():
		return out
	out.merge(RegionLook.look(region if not region.is_empty() else EraManager.current_region).get("camera", {}), true)
	return out

## Zoom factor and pivot for a field of [param field_size] framing [param a] against [param b].
## The pivot stays inside the field, so zooming (factor >= 1) never shows an edge.
static func focus(field_size: Vector2, a: Rect2, b: Rect2, era: int = 5) -> Dictionary:
	var c: Dictionary = cam_cfg("", era)
	var z: float = maxf(float(c.get("zoom", 1.0)), 1.0)
	var share: float = clampf(float(c.get("pan_share", 0.0)), 0.0, 1.0)
	var mid: Vector2 = (a.get_center() + b.get_center()) / 2.0
	var look: Vector2 = (field_size / 2.0).lerp(mid, share)
	look = Vector2(clampf(look.x, 0.0, field_size.x), clampf(look.y, 0.0, field_size.y)).round()
	return {"scale": Vector2(z, z), "pivot": look}

static func active() -> bool:
	return EraBattleFeel.camera_on(EraManager.active_era()) and not Juice.reduced()

## Zooms [param node] in on the attacker/target pair. Awaitable; returns at once when inactive.
static func push(node: Control, a: Rect2, b: Rect2) -> void:
	if not active() or node == null:
		return
	var era: int = EraManager.active_era()
	var f: Dictionary = focus(node.size, a, b, era)
	node.pivot_offset = f.pivot
	var t: float = float(cam_cfg("", era).get("in_time", 0.18)) / Juice.speed()
	var tw: Tween = node.create_tween()
	Juice.shaped(tw.tween_property(node, "scale", f.scale, t), "move")
	await tw.finished

## Eases [param node] back to rest framing after a short hold. Awaitable.
static func release(node: Control) -> void:
	if node == null or node.scale == Vector2.ONE:
		return
	var c: Dictionary = cam_cfg("", EraManager.active_era())
	var tw: Tween = node.create_tween()
	tw.tween_interval(float(c.get("hold_time", 0.12)) / Juice.speed())
	Juice.shaped(tw.tween_property(node, "scale", Vector2.ONE, float(c.get("out_time", 0.22)) / Juice.speed()), "move")
	await tw.finished

## Era V opening: the field starts zoomed in on the foe and pulls back to rest. Awaitable.
static func swoop_in(node: Control, foe: Rect2) -> void:
	if node == null or Juice.reduced() or not EraBattleFeel.camera_on(EraManager.active_era()):
		return
	var z: float = maxf(float(cam_cfg().get("zoom", 1.0)), 1.0) + 0.1
	node.pivot_offset = foe.get_center().round()
	node.scale = Vector2(z, z)
	var tw: Tween = node.create_tween()
	Juice.shaped(tw.tween_property(node, "scale", Vector2.ONE, 0.5 / Juice.speed()), "move")
	await tw.finished
