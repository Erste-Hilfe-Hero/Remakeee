extends Node
## The work of tools/boot_shots.gd, run as a node so the autoloads exist.

var out: String = "user://boot_shots"
var langs: PackedStringArray = ["de"]
var sizes: PackedStringArray = ["146x317", "150x267"]
var seconds: PackedStringArray = ["0.3", "0.6", "0.8", "1.0", "1.2", "1.6"]
var era: int = 1

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	DirAccess.make_dir_recursive_absolute(out)
	EraBoot.shown = true
	GameState.reduce_motion = false
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.call("from_dict", {"unlocked_era": era})
	for lang: String in langs:
		Loc.set_language(lang)
		GameState.language = lang
		for sz: String in sizes:
			var view := Vector2i(sz.get_slice("x", 0).to_int(), sz.get_slice("x", 1).to_int())
			# Twice the view: ScreenFit then picks pixel scale 2 and the view is exactly this size.
			get_window().size = view * 2
			await _frames(3)
			ScreenFit.apply(get_window(), EraManager.RESOLUTION[era])
			await _frames(3)
			print("view %s for %s" % [get_viewport().get_visible_rect().size, sz])
			var b := EraBoot.new()
			b.era = era
			b.manual = true
			add_child(b)
			var frames: Array[Image] = []
			for s: String in seconds:
				b.t = s.to_float()
				b.stage.queue_redraw()
				frames.append(await _grab())
			b.queue_free()
			await _frames(1)
			var tag: String = "%s_%s_era%d" % [lang, sz, era]
			frames[-1].save_png("%s/boot_%s.png" % [out, tag])
			_strip(frames).save_png("%s/boot_%s_frames.png" % [out, tag])
			print("saved boot_%s" % tag)
	get_tree().quit()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _grab() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _strip(frames: Array[Image]) -> Image:
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var strip: Image = Image.create((w + 4) * frames.size() - 4, h, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.1, 0.1, 0.1))
	for i: int in frames.size():
		strip.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(i * (w + 4), 0))
	return strip
