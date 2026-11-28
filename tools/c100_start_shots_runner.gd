extends Node
## The work of tools/c100_start_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 2
const WAIT_FRAMES: int = 600

var out: String = "user://c100_start_shots"
var lang: String = "en"
var tag: String = "916"
var _boxes: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	EraBoot.shown = true
	GameState.reduce_motion = true
	Online.backend = LocalBackend.new("user://c100_shots_server.json")
	Online.privacy_seen = false
	GameState.terms_version = ""
	GameState.language = ""
	await _title()
	await _prologue()
	await _bond()
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

## Waits until [param cond] holds (or WAIT_FRAMES pass). Returns whether it held.
func _until(cond: Callable) -> bool:
	for i: int in WAIT_FRAMES:
		if cond.call():
			return true
		await get_tree().process_frame
	push_warning("c100 shots: timed out")
	return false

func _menu_open(menu: MenuHost, title: String) -> bool:
	return await _until(func() -> bool: return menu.picker.visible and menu.last_title == title and menu.picker._buttons.size() > 0)

func _title() -> void:
	var title: TitleScreen = load("res://scenes/ui/Title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	var menu: MenuHost = title._menu
	await _menu_open(menu, "Language / Sprache")
	menu.picker.picked.emit(Loc.LANGUAGES.find(lang))
	# The terms step carries the short privacy note (c100-terms).
	await _menu_open(menu, TitleScreen.TERMS_TITLE)
	await _shot("01_terms")
	menu.picker.picked.emit(TitleScreen.TermsRow.ACCEPT)
	await _frames(4)
	await _menu_open(menu, TitleScreen.TERMS_TITLE)
	await _shot("02_terms_ticked")
	menu.picker.picked.emit(TitleScreen.TermsRow.GO)
	await _menu_open(menu, "")
	await _shot("03_title")
	menu.picker.picked.emit(0)
	# No difficulty step since 2026-11-27 (one mode): the look screen comes next.
	await _menu_open(menu, TitleScreen.LOOK_TITLE)
	await _shot("05_look")
	menu.picker.last_dir = 1
	menu.picker.picked.emit(TitleScreen.LOOK_BODY)
	await _frames(2)
	menu.picker.picked.emit(TitleScreen.LOOK_RANDOM)
	await _frames(4)
	await _menu_open(menu, TitleScreen.LOOK_TITLE)
	await _shot("06_look_random")
	menu.picker.picked.emit(TitleScreen.LOOK_DONE)
	await _until(func() -> bool: return title._name_box.visible)
	await _shot("07_name")
	title.queue_free()
	await _frames(2)

func _prologue() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Liora", 1, "", 1, 2, 4)
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(ow)
	get_tree().current_scene = ow
	var box: TextBox = ow.text_box()
	var shots: Dictionary[int, String] = {1: "08_prologue_text", 3: "10_wake_up"}
	var card_shot: bool = false
	var partner_shot: bool = false
	for i: int in 4000:
		if GameState.has_flag(Overworld.FIRST_WALK_FLAG) and not ow.busy:
			break
		if not card_shot and ow.scene_running and ow.fade_rect().color.a > 0.99 and _card_label(ow) != null:
			card_shot = true
			await _shot("09_card")
		for c: Node in ow._ui.get_children():
			if c is MenuHost and (c as MenuHost)._info_panel.visible:
				print("info: ", (c as MenuHost)._info_label.text.replace("\n", " "))
				(c as MenuHost)._close_info()
		var menu: MenuHost = _open_menu(ow)
		if menu != null:
			if menu.last_title == Overworld.STARTER_TITLE:
				if not partner_shot:
					partner_shot = true
					await _shot("11_partner")
				menu.picker.picked.emit(1)
			else:
				await _shot("12_partner_confirm")
				menu.picker.picked.emit(0)
			await _frames(4)
			continue
		if box._waiting:
			_boxes += 1
			if shots.has(_boxes):
				await _shot(shots[_boxes])
			print("box %d: %s" % [_boxes, box._label.text.replace("\n", " ")])
			box.advance_now()
			await _frames(2)
			continue
		await get_tree().process_frame
	print("boxes before control: %d" % _boxes)
	await _frames(10)
	await _shot("13_first_walk")
	ow.queue_free()
	await _frames(2)

func _card_label(ow: Overworld) -> Label:
	for c: Node in ow.ui_root().get_children():
		if c is Label and (c as Label).text.contains(Loc.t("Prologue: The Storm Night")):
			return c
	return null

func _open_menu(ow: Overworld) -> MenuHost:
	for c: Node in ow._ui.get_children():
		if c is MenuHost and (c as MenuHost).picker.visible and (c as MenuHost).picker._buttons.size() > 0:
			return c
	return null

func _bond() -> void:
	var g: BondMinigame = load("res://scenes/battle/BondMinigame.tscn").instantiate()
	g.theme = UITheme.get_theme()
	g.target = load("res://art/era1/spirlings/zippit_front.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	g.rng = rng
	get_tree().root.add_child(g)
	get_tree().current_scene = g
	g.run()
	await _frames(20)
	await _shot("14_bond_call")
	g.queue_free()
