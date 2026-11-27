extends Node
## The work of tools/puzzle_shots.gd, run as a node so the autoloads exist. Each shot loads the
## overworld on the stone's map with the Wayfarer beside it, then opens what the stone shows.

const SCALE: int = 3
## [spot id, what to show, moves or taps played before the picture]
const SHOTS: Array = [
	["vey_keeper_1", "intro", []],
	["vey_keeper_1", "pick", []],
	["cor_rain", "type", []],
	["vey_keeper_3", "board", [[0, 0]]],
	["cor_quay", "board", [[1, 2], [1, 1]]],
	["ash_glass_1", "board", ["right", "down"]],
	["vey_tracks", "board", ["right", "right", "down"]],
	["vey_keeper_2", "board", []],
]

var out: String = "user://puzzle_shots"
var langs: PackedStringArray = ["de"]
var era: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://puzzle_shots_settings.json"
	Database.load_all()
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.weather = false
	GameState.tips_enabled = false
	EraManager.unlocked_era = maxi(era, 1)
	EraManager.set_retro_filter(era)
	for lang: String in langs:
		GameState.language = lang
		Loc.set_language(lang)
		var n: int = 0
		for s: Array in SHOTS:
			n += 1
			await _shot("%s_%02d_%s_%s" % [lang, n, s[0], s[1]], PuzzleSpots.by_id(str(s[0])), str(s[1]), s[2])
	get_tree().quit()

## A walkable cell beside the stone for the Wayfarer to stand on.
func _beside(m: MapData, cell: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if m.is_walkable(cell + d):
			return cell + d
	return cell

func _shot(file: String, spot: Dictionary, what: String, play: Array) -> void:
	var m: MapData = MapData.load_map(str(spot.map))
	GameState.current_map = str(spot.map)
	GameState.player_cell = _beside(m, PuzzleSpots.cell_of(spot))
	var ow: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	for i: int in 120:
		await get_tree().process_frame
	var ui: CanvasLayer = ow.get("_ui")
	# The weekend and event notes of a fresh map load would cover the stone's text.
	var toast: Object = ow.get("toast")
	if toast != null:
		toast.set("visible", false)
	VirtualPad.set_wanted(false)
	var menu := MenuHost.new()
	ui.add_child(menu)
	var board: PuzzleBoard = null
	match what:
		"intro":
			menu.info(Loc.t(str(spot.title)) + "\n\n" + Loc.t(str(spot.text)))
		"pick":
			PuzzleSpots.add_try(str(spot.id))
			PuzzleSpots.add_try(str(spot.id))
			menu.pick_strings(Loc.t("Your answer:"), PuzzleBoard.shown_options(spot))
		"type":
			TextPrompt.ask(ui, Loc.t("Your answer:"), false, 24)
		"board":
			board = PuzzleBoard.new()
			board.setup(spot)
			ui.add_child(board)
			await get_tree().process_frame
			for p: Variant in play:
				if p is Array:
					board.tap_cell(Vector2i(int(p[0]), int(p[1])))
				else:
					board.move(PuzzleSpots.SLIDE_DIRS[str(p)])
			if board.kind == "listen":
				board.play_tune()
	for i: int in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, file])
	print("saved ", file)
	ow.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
