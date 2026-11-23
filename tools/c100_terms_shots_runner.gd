extends Node
## The work of tools/c100_terms_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 2
const WAIT_FRAMES: int = 900

var out: String = "user://c100_terms_shots"
var lang: String = "en"
var tag: String = "916"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	EraBoot.shown = true
	GameState.reduce_motion = true
	MenuHost.open_url = func(_url: String) -> void: pass
	Online.backend = LocalBackend.new("user://c100_terms_server.json")
	for n: int in range(1, SaveManager.SLOTS + 1):
		SaveManager.set_slot(n)
		SaveManager.delete_save()
	SaveManager.set_slot(1)
	Online.privacy_seen = false
	GameState.terms_version = ""
	GameState.language = lang
	Loc.set_language(lang)
	await _title("new", true)
	# A player with a save from before the step: asked once on the next start.
	GameState.new_game(GameState.Difficulty.TAMER, "Liora", 1, "")
	SaveManager.set_slot(1)
	SaveManager.save_game()
	Online.privacy_seen = true
	GameState.terms_version = ""
	await _title("save", false)
	get_tree().quit()

func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s_%s_%s.png" % [out, tag, lang, name])
	print("saved ", name)

func _until(cond: Callable) -> bool:
	for i: int in WAIT_FRAMES:
		if cond.call():
			return true
		await get_tree().process_frame
	push_warning("c100 terms shots: timed out")
	return false

func _menu_open(menu: MenuHost, title: String) -> bool:
	return await _until(func() -> bool: return menu.picker.visible and menu.last_title == title and menu.picker._buttons.size() > 0)

func _title(name: String, links: bool) -> void:
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	var menu: MenuHost = title._menu
	await _menu_open(menu, TitleScreen.TERMS_TITLE)
	await _shot(name + "_1_terms")
	if links:
		menu.picker.picked.emit(TitleScreen.TermsRow.TERMS)
		await _frames(6)
		await _menu_open(menu, TitleScreen.TERMS_TITLE)
		await _shot(name + "_2_link")
		await _until(func() -> bool: return menu.toast_text().is_empty())
	else:
		menu.picker.show_why(TitleScreen.TermsRow.GO)
		await _shot(name + "_2_why")
	menu.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _frames(4)
	await _menu_open(menu, TitleScreen.TERMS_TITLE)
	await _shot(name + "_3_ticked")
	menu.picker.picked.emit(TitleScreen.TermsRow.GO)
	await _until(func() -> bool: return menu.picker.visible and menu.last_title != TitleScreen.TERMS_TITLE and menu.picker._buttons.size() > 0)
	await _frames(30)
	await _shot(name + "_4_after")
	title.queue_free()
	await _frames(2)
