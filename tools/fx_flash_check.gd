extends Node
## Flash check for the battle effects (plan area 6, item 2656): plays every element's art
## frame by frame at 30 frames per second over the battle backdrop colour and fails when a
## cell gets more than MAX_FLASHES flashes in any one-second window. A flash is a frame where
## more than AREA of the cell's pixels change brightness by more than two palette steps.
## Run as a scene so the autoloads exist (the UI golden job runs it on every UI change):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/fx_flash_check.tscn

const FPS: int = 30
const MAX_FLASHES: int = 3
## Era I has four ink shades between paper and ink: two steps are two thirds of that range.
const STEP_DELTA: float = 2.0 / 3.0
const AREA: float = 0.25
const CELL := Vector2i(144, 80)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = CELL
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(CELL)
	vp.add_child(bg)
	var range_l: float = absf(UITheme.BG.get_luminance() - UITheme.INK.get_luminance())
	var bad: Array[String] = []
	for e: int in 8:
		var fx := ElementFx.new()
		vp.add_child(fx)
		fx.position = Vector2.ZERO
		fx.size = Vector2(CELL)
		fx.element = e
		fx._from = Vector2(110, 55)
		fx._to = Vector2(34, 25)
		fx._ground_from = Vector2(110, 72)
		fx._ground_to = Vector2(34, 42)
		var frames: Array[Image] = []
		for p: ElementFx.Phase in [ElementFx.Phase.CHARGE, ElementFx.Phase.TRAVEL, ElementFx.Phase.IMPACT]:
			var n: int = maxi(1, roundi(ElementFx.phase_time(p, false) * FPS))
			for i: int in n:
				fx.phase = p
				fx.t = (i + 0.5) / n
				fx.queue_redraw()
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				frames.append(vp.get_texture().get_image())
		fx.phase = ElementFx.Phase.NONE
		fx.queue_redraw()
		await RenderingServer.frame_post_draw
		frames.append(vp.get_texture().get_image())
		var flashes: Array[int] = []
		var peak: float = 0.0
		for i: int in range(1, frames.size()):
			var share: float = _changed_share(frames[i - 1], frames[i], range_l * STEP_DELTA)
			peak = maxf(peak, share)
			if share > AREA:
				flashes.append(i)
		var worst: int = 0
		for i: int in flashes.size():
			var in_window: int = 0
			for j: int in flashes:
				if j >= flashes[i] and j < flashes[i] + FPS:
					in_window += 1
			worst = maxi(worst, in_window)
		print("FX flash: %s %d frames, largest change %.1f%%, %d flash frames, worst second %d" % [Elements.E.keys()[e], frames.size(), peak * 100.0, flashes.size(), worst])
		if worst > MAX_FLASHES:
			bad.append(String(Elements.E.keys()[e]))
		fx.queue_free()
	print("FX flash: %s" % ("OK" if bad.is_empty() else "too many flashes: " + ", ".join(bad)))
	get_tree().quit(0 if bad.is_empty() else 1)

static func _changed_share(a: Image, b: Image, delta: float) -> float:
	var changed: int = 0
	var total: int = a.get_width() * a.get_height()
	for y: int in a.get_height():
		for x: int in a.get_width():
			if absf(a.get_pixel(x, y).get_luminance() - b.get_pixel(x, y).get_luminance()) > delta:
				changed += 1
	return float(changed) / total
