extends Node
## The work of tools/c100_offline_shots.gd, run as a node so the autoloads exist.

var out: String = "user://c100_offline_shots"
var lang: String = "en"
var _n: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	Loc.set_language(lang)
	GameState.language = lang
	EraBoot.shown = true
	GameState.reduce_motion = true
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)
	var server := LocalBackend.new("user://c100_offline_server.json")
	server.offline = true
	Online.backend = server
	Online.state = Online.State.OFFLINE
	Online.revs = {}
	Online.dirty = {}
	Online.privacy_seen = true
	GameState.terms_version = LegalInfo.TERMS_VERSION
	# Title without a connection: no question, the list and one quiet line.
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await _until(func() -> bool: return title._at_root and title._menu.picker.visible)
	await _shot("title_offline")
	title.queue_free()
	await _frames(2)
	# A journey without a connection: the world plays, the small mark sits at the top.
	GameState.new_game(GameState.Difficulty.TAMER, "Rowan", 0, "Kindlop")
	SaveManager.start_fresh_slot()
	for f: String in ["got_starter", "aldo_gift", Overworld.FIRST_WALK_FLAG]:
		GameState.set_flag(f)
	GameState.current_map = "brindlewick"
	GameState.player_cell = Vector2i(5, 4)
	GameState.in_game = true
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	await _frames(600)
	await _shot("world_offline_mark")
	# The parts that need the server: one short line each.
	var menu := PauseMenu.new()
	(ow.get("_ui") as Node).add_child(menu)
	await _frames(2)
	ShopMenu.run(menu)
	await _until(func() -> bool: return _info_open(menu))
	await _shot("shop_needs_internet")
	_close(menu)
	await _frames(10)
	LeagueMenu.run(menu)
	await _until(func() -> bool: return _info_open(menu))
	await _shot("league_needs_internet")
	_close(menu)
	get_tree().quit()

func _live(m: MenuHost) -> MenuHost:
	var v: Node = m.get_node_or_null("shop_zoom")
	return v.get_child(0).get_child(0) as MenuHost if v != null else m

func _info_open(m: MenuHost) -> bool:
	return _live(m)._info_panel.visible

func _close(m: MenuHost) -> void:
	_live(m)._close_info()

func _until(cond: Callable, max_frames: int = 1200) -> void:
	for i: int in max_frames:
		if cond.call():
			break
		await get_tree().process_frame
	await _frames(20)

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	_n += 1
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	# The pixel view at the phone's size, as it shows on screen.
	if img.get_size() != size:
		img.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var path: String = "%s/%02d_%s_%s_%dx%d.png" % [out, _n, name, lang, size.x, size.y]
	img.save_png(path)
	print("saved ", path)
