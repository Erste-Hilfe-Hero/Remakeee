extends Node
## Renders every element effect (charge, travel, impact at mid-phase) into one PNG for review.
## Run as a scene so the autoloads exist:
## xvfb-run godot --path . --rendering-driver opengl3 res://tools/fx_gallery.tscn -- out.png

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://fx.png"
	var cell := Vector2(144, 80)
	var root := Control.new()
	root.size = Vector2(cell.x * 3, cell.y * 8)
	var vp := SubViewport.new()
	vp.size = Vector2i(root.size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(root)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = root.size
	root.add_child(bg)
	for e: int in 8:
		for p: int in 3:
			var fx := ElementFx.new()
			root.add_child(fx)
			fx.set_anchors_preset(Control.PRESET_TOP_LEFT)
			fx.position = Vector2(p * cell.x, e * cell.y)
			fx.size = cell
			fx.element = e
			fx.phase = [ElementFx.Phase.CHARGE, ElementFx.Phase.TRAVEL, ElementFx.Phase.IMPACT][p]
			fx.t = 0.5
			fx._from = Vector2(110, 55)
			fx._to = Vector2(34, 25)
			fx._ground_from = Vector2(110, 72)
			fx._ground_to = Vector2(34, 42)
			fx.queue_redraw()
	for i: int in 4:
		await get_tree().process_frame
	vp.get_texture().get_image().save_png(out)
	get_tree().quit()
