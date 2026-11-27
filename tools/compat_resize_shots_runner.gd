extends Node
## The work of tools/compat_resize_shots.gd, run as a node so the autoloads exist.

const SHAPES: Array = [
	["phone_1080x2340", Vector2i(360, 780)],
	["fold_open_2208x1840", Vector2i(736, 613)],
	["flip_cover_720x748", Vector2i(360, 374)],
	["phone_again", Vector2i(360, 780)],
	["fold_open_again", Vector2i(736, 613)],
]
var out: String = "user://compat_shots"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language("en")
	GameState.language = "en"
	GameState.terms_version = LegalInfo.TERMS_VERSION
	EraBoot.shown = true
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 8)
	var w: Window = get_window()
	w.size = SHAPES[0][1]
	await _frames(3)
	get_tree().change_scene_to_file("res://scenes/overworld/Overworld.tscn")
	await _frames(40)
	for s: Array in SHAPES:
		w.size = s[1]
		await _frames(12)
		await RenderingServer.frame_post_draw
		var img: Image = w.get_viewport().get_texture().get_image()
		img.save_png("%s/compat_%s.png" % [out, s[0]])
		print("%s window=%s content=%s visible=%s" % [s[0], w.size, w.content_scale_size, w.get_visible_rect().size])
	get_tree().quit()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
