extends Node
## Renders each menu screen and compares it with tests/golden/<name>_<lang>.png (item 2044).

const GOLDEN_DIR: String = "res://tests/golden"
const OUT_DIR: String = "user://golden_out"
## Share of pixels that may differ before a screen counts as changed (driver noise).
const MAX_DIFF: float = 0.002

var mode: String = "compare"
var _failed: PackedStringArray = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

## Each screen: a name and the rows of the list it shows.
func _screens() -> Array[Array]:
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	var out: Array[Array] = [
		["settings", MenuHost.SETTINGS_TITLE, MenuHost._rows_to_entries(MenuHost.SETTINGS_GROUPS)],
		["settings_game", "Game", MenuHost._rows_to_entries(MenuHost.settings_rows("game"))],
		["settings_sound", "Sound", MenuHost._rows_to_entries(MenuHost.settings_rows("sound"))],
		["settings_controls", "Controls", MenuHost._rows_to_entries(MenuHost.controls_rows())],
		["settings_display", "Display and access", MenuHost._rows_to_entries(MenuHost.display_rows())],
	]
	var labels: Array[Dictionary] = []
	for l: String in PauseMenu.menu_labels(true, true, false, false, true):
		labels.append({"text": l})
	out.append(["pause", "Rowan", labels])
	out.append(["goals", "Goals", PauseMenu.goal_rows({"aldo_gift": true}, "Today: a rare visitor stirs in Fernstair.")])
	# Rows are built; out of a journey the "connection lost" mark stays away (no server here).
	GameState.in_game = false
	return out

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))
	Database.load_all()
	GameState.settings_from_dict({})
	GameState.apply_display()
	for lang: String in ["en", "de"]:
		GameState.language = lang
		Loc.set_language(lang)
		for s: Array in _screens():
			await _shot(str(s[0]) + "_" + lang, str(s[1]), s[2])
	GameState.language = ""
	if _failed.is_empty():
		print("UI golden: all screens match (%s)" % mode)
		get_tree().quit(0)
	else:
		printerr("UI golden: changed screens: %s. Shots and diffs in %s" % [", ".join(_failed), ProjectSettings.globalize_path(OUT_DIR)])
		get_tree().quit(1)

func _shot(name: String, title: String, rows: Array) -> void:
	var host := MenuHost.new()
	add_child(host)
	await get_tree().process_frame
	var entries: Array[Dictionary] = []
	entries.assign(rows)
	host.pick(title, entries, true, 0, 0)
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	host.picker.picked.emit(-1)
	host.queue_free()
	await get_tree().process_frame
	var golden_path: String = "%s/%s.png" % [GOLDEN_DIR, name]
	if mode == "update":
		img.save_png(ProjectSettings.globalize_path(golden_path))
		print("UI golden: wrote ", name)
		return
	img.save_png("%s/%s.png" % [ProjectSettings.globalize_path(OUT_DIR), name])
	if not FileAccess.file_exists(golden_path):
		_failed.append(name + " (no golden)")
		return
	var golden := Image.load_from_file(ProjectSettings.globalize_path(golden_path))
	golden.convert(Image.FORMAT_RGB8)
	var share: float = diff_share(img, golden)
	if share > MAX_DIFF:
		_failed.append("%s (%.1f%%)" % [name, share * 100.0])
		_diff_image(img, golden).save_png("%s/%s_diff.png" % [ProjectSettings.globalize_path(OUT_DIR), name])

## Share of pixels that differ (1.0 when the sizes differ).
static func diff_share(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return float(n) / float(a.get_width() * a.get_height())

## The new shot with changed pixels in red.
static func _diff_image(a: Image, b: Image) -> Image:
	var d: Image = a.duplicate()
	if a.get_size() != b.get_size():
		return d
	for y: int in a.get_height():
		for x: int in a.get_width():
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				d.set_pixel(x, y, Color(1, 0, 0))
	return d
