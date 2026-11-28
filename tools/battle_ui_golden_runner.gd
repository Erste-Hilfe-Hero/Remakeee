extends Node
## The work of tools/battle_ui_golden.gd, run as a node so the autoloads exist.

const Golden: GDScript = preload("res://tools/ui_golden_runner.gd")
const Shots: GDScript = preload("res://tools/era_battle_shots_runner.gd")
const GOLDEN_DIR: String = "res://tests/golden/battle_ui"
const OUT_DIR: String = "user://golden_out"
const MAX_DIFF: float = 0.002
const ERAS: Array[int] = [1, 5]
const FRONTS: Array[int] = [1, 2]
## Frames to wait for the command menu at most, and to let it settle after it opened.
const READY_FRAMES: int = 1800
const SETTLE_FRAMES: int = 20

var mode: String = "compare"
var _failed: PackedStringArray = []
var _count: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	GameState.settings_from_dict({})
	GameState.apply_display()
	# Still pictures: no idle bob, no breathing marks, no slide-ins.
	GameState.reduce_motion = true
	Era45Look.biome_override = "route"
	EraManager.unlocked_era = EraManager.NEWEST
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))
	for era: int in ERAS:
		EraManager.set_retro_filter(era)
		for lang: String in ["en", "de"]:
			GameState.language = lang
			Loc.set_language(lang)
			for front: int in FRONTS:
				await _shot(era, lang, front)
	GameState.language = ""
	EraManager.set_retro_filter(0)
	if _failed.is_empty():
		print("Battle UI golden: all %d screens match (%s)" % [_count, mode])
		get_tree().quit(0)
	else:
		printerr("Battle UI golden: changed screens: %s. Shots and diffs in %s" % [", ".join(_failed), ProjectSettings.globalize_path(OUT_DIR)])
		get_tree().quit(1)

func _shot(era: int, lang: String, front: int) -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	inst.setup(Shots.formation_model([front, front]))
	add_child(inst)
	for i: int in 3:
		await get_tree().process_frame
	var left: int = READY_FRAMES
	while not Shots.settled(inst) and left > 0:
		inst._text.advance_now()
		await get_tree().process_frame
		left -= 1
	var tag: String = "e%d_%s_%dv%d" % [era, lang, front, front]
	if left <= 0:
		_failed.append(tag + " (the command menu never opened)")
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	await _compare("menu_" + tag)
	inst._menu.toggle_info(0)
	for i: int in 4:
		await get_tree().process_frame
	await _compare("info_" + tag)
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame

func _compare(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	_count += 1
	var golden_path: String = "%s/%s.png" % [GOLDEN_DIR, name]
	if mode == "update":
		img.save_png(ProjectSettings.globalize_path(golden_path))
		print("Battle UI golden: wrote ", name)
		return
	img.save_png("%s/battle_%s.png" % [ProjectSettings.globalize_path(OUT_DIR), name])
	if not FileAccess.file_exists(golden_path):
		_failed.append(name + " (no golden)")
		return
	var golden := Image.load_from_file(ProjectSettings.globalize_path(golden_path))
	golden.convert(Image.FORMAT_RGB8)
	var share: float = Golden.diff_share(img, golden)
	if share > MAX_DIFF:
		_failed.append("%s (%.1f%%)" % [name, share * 100.0])
		Golden._diff_image(img, golden).save_png("%s/battle_%s_diff.png" % [ProjectSettings.globalize_path(OUT_DIR), name])
