class_name EraWarp
extends RefCounted
## Door warp variants of the later eras that come from data/era_text.json. "spiral" (Era III):
## arms of ink wind in around the Wayfarer until the screen is covered (shaders/era_spiral).
## The overworld only asks for a variant when motion is not reduced (EraText.warp).

const SPIRAL_SHADER: Shader = preload("res://shaders/era_spiral.gdshader")

## The covering rectangle of the spiral on [param layer], not yet moving (progress 0).
static func spiral_rect(layer: CanvasLayer, center: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SPIRAL_SHADER
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("size_px", layer.get_viewport().get_visible_rect().size)
	mat.set_shader_parameter("ink", color)
	mat.set_shader_parameter("arms", EraText.spiral_value("arms", 2.0))
	mat.set_shader_parameter("turns", EraText.spiral_value("turns", 1.5))
	mat.set_shader_parameter("progress", 0.0)
	rect.material = mat
	layer.add_child(rect)
	return rect

## Spiral close around [param center] in [param time] seconds. Awaitable; the caller covers the
## screen with its fade afterwards.
static func spiral_close(layer: CanvasLayer, center: Vector2, color: Color, time: float) -> void:
	var rect: ColorRect = spiral_rect(layer, center, color)
	var mat: ShaderMaterial = rect.material
	var tw: Tween = rect.create_tween()
	tw.tween_method(func(p: float) -> void: mat.set_shader_parameter("progress", p), 0.0, 1.0,
			time * EraText.spiral_value("time_mult", 3.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	rect.queue_free()
