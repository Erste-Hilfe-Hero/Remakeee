extends Node
## The work of tools/era_text_shots.gd, run as a node so the autoloads exist.

const Golden: GDScript = preload("res://tools/ui_golden_runner.gd")
const GOLDEN_DIR: String = "res://tests/golden/era_text"
const OUT_DIR: String = "user://golden_out"
const MAX_DIFF: float = 0.002
const SCALE: int = 2
## One talk per era: a place of the era's region on the banner and a line of someone with a
## portrait (texts from data/dialogue/clans.json, so the German comes from the game's table).
const TALKS: Dictionary[int, Array] = {
	1: ["Fernstair", "Vash: Warden Ilo Vash, Clan Duels Office. Complaints are taken at noon."],
	2: ["Cindergate Quay", "Vash: Warden Ilo Vash, Clan Duels Office. Complaints are taken at noon."],
	3: ["Burin Landing", "Ottilie: Lavender? Thank you, dear. I wear it to funerals. I go to a great many."],
	4: ["Brightledge", "Mother Grell: Don't flinch, little map. I don't hate children. I just invoice their families."],
	5: ["Mossgate", "Ottilie: Ottilie Kael. The orphans call me Aunt. The Wardens call me Ma'am."],
}
const GROUND: Array[Color] = [Color("7fae6a"), Color("76a562")]
const TILE: int = 16

var mode: String = "compare"
var shots_dir: String = "user://era_text_shots"
var _failed: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	GameState.settings_from_dict({})
	GameState.apply_display()
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	GameState.in_game = false
	# Still pictures: no blink, no slide.
	GameState.reduce_motion = true
	EraManager.unlocked_era = EraManager.NEWEST
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))
	for era: int in range(1 if mode == "shots" else 2, EraManager.NEWEST + 1):
		EraManager.set_retro_filter(era)
		for lang: String in ["en", "de"]:
			GameState.language = lang
			Loc.set_language(lang)
			await _shot(era, lang, false)
		if mode == "shots" and EraText.warp(era, "door") == "spiral":
			await _shot(era, "de", true)
	GameState.language = ""
	EraManager.set_retro_filter(0)
	if mode == "shots":
		print("Era text shots: written to ", shots_dir)
		get_tree().quit(0)
	elif _failed.is_empty():
		print("Era text golden: all screens match (%s)" % mode)
		get_tree().quit(0)
	else:
		printerr("Era text golden: changed screens: %s. Shots and diffs in %s" % [", ".join(_failed), ProjectSettings.globalize_path(OUT_DIR)])
		get_tree().quit(1)

## A patch of meadow, the place banner on top and the dialogue box below, the way the map
## lays them out (Overworld._ready).
func _scene(era: int) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	var img := Image.create(TILE * 2, TILE * 2, false, Image.FORMAT_RGBA8)
	for y: int in TILE * 2:
		for x: int in TILE * 2:
			img.set_pixel(x, y, GROUND[(x / TILE + y / TILE) % 2])
	var ground := TextureRect.new()
	ground.texture = ImageTexture.create_from_image(img)
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ground)
	var talk: Array = TALKS[era]
	var banner := Label.new()
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = TownPopup.TOP
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.text = " %s " % Loc.t(str(talk[0]))
	TownPopup.dress(banner, str(EraManager.feel("town_popup")))
	root.add_child(banner)
	var box := TextBox.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -Overworld.TEXT_BOX_HEIGHT
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(box)
	return root

func _shot(era: int, lang: String, spiral: bool) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for i: int in 2:
		await get_tree().process_frame
	var scene: Control = _scene(era)
	layer.add_child(scene)
	await get_tree().process_frame
	(scene.get_node("Box") as TextBox).show_prompt(str(TALKS[era][1]))
	if spiral:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var rect: ColorRect = EraWarp.spiral_rect(layer, (vp / 2.0).floor(), UITheme.INK)
		(rect.material as ShaderMaterial).set_shader_parameter("progress", 0.5)
	for i: int in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	layer.queue_free()
	await get_tree().process_frame
	var name: String = "text_e%d_%s%s" % [era, lang, "_spiral" if spiral else ""]
	if mode == "shots":
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%s.png" % [shots_dir, name])
		print("Era text shots: wrote ", name)
		return
	var golden_path: String = "%s/%s.png" % [GOLDEN_DIR, name]
	if mode == "update":
		img.save_png(ProjectSettings.globalize_path(golden_path))
		print("Era text golden: wrote ", name)
		return
	img.save_png("%s/era_%s.png" % [ProjectSettings.globalize_path(OUT_DIR), name])
	if not FileAccess.file_exists(golden_path):
		_failed.append(name + " (no golden)")
		return
	var golden := Image.load_from_file(ProjectSettings.globalize_path(golden_path))
	golden.convert(Image.FORMAT_RGB8)
	var share: float = Golden.diff_share(img, golden)
	if share > MAX_DIFF:
		_failed.append("%s (%.1f%%)" % [name, share * 100.0])
		Golden._diff_image(img, golden).save_png("%s/era_%s_diff.png" % [ProjectSettings.globalize_path(OUT_DIR), name])
