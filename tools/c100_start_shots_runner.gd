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
	await _opening()
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
	# New Game goes straight into the ferns since 1.3.2 (Opening): no look or name screen here.
	menu.picker.picked.emit(0)
	await _until(func() -> bool: return get_tree().current_scene is Overworld)
	await _frames(2)

## The opening (1.3.2): walking at once, the storm Spirlings, Mine!, Aldo; then the village.
func _opening() -> void:
	var ow: Overworld = get_tree().current_scene as Overworld
	if ow == null:
		GameState.new_game(GameState.Difficulty.TAMER, "", 0, "")
		ow = load("res://scenes/overworld/Overworld.tscn").instantiate()
		get_tree().root.add_child(ow)
		get_tree().current_scene = ow
	await _frames(20)
	await _shot("04_first_walk")
	ow.player.cell = Opening.CELL + Vector2i.DOWN
	ow._on_player_stepped(ow.player.cell)
	await _play(ow, func() -> bool: return GameState.has_flag("aldo_gift") and not ow.busy)
	print("boxes until the walk to the village: %d" % _boxes)
	ow.load_map(Opening.VILLAGE_MAP, Vector2i(5, 1), "down")
	await _play(ow, func() -> bool: return GameState.has_flag(Opening.VILLAGE_FLAG) and not ow.busy)
	print("boxes until the first goal: %d" % _boxes)
	await _frames(10)
	await _shot("14_village_goal")
	ow.queue_free()
	await _frames(2)

## Plays on until [param done], taking one picture of each new screen.
func _play(ow: Overworld, done: Callable) -> void:
	var box: TextBox = ow.text_box()
	var seen: Dictionary = {}
	for i: int in 6000:
		if done.call():
			return
		var menu: MenuHost = _open_menu(ow)
		if menu != null:
			if not seen.has(menu.last_title):
				seen[menu.last_title] = true
				await _shot("07_partner" if menu.last_title == Overworld.STARTER_TITLE else "11_look")
			menu.picker.picked.emit(TitleScreen.LOOK_DONE if menu.last_title == TitleScreen.LOOK_TITLE else 1)
			await _frames(4)
			continue
		var game: BondMinigame = _find(ow, BondMinigame) as BondMinigame
		if game != null and game.visible:
			if not seen.has("mine"):
				seen["mine"] = true
				for t: int in 6:
					game.mine_tap()
				await _shot("08_mine")
			game.mine_tap()
			await _frames(3)
			continue
		var name_box: NameBox = _find(ow._ui, NameBox) as NameBox
		if name_box != null:
			await _shot("12_name")
			name_box._done.emit("Liora")
			await _frames(4)
			continue
		if not seen.has("card") and _card_label(ow) != null:
			seen["card"] = true
			await _shot("10_storm_card")
		if box._waiting:
			_boxes += 1
			var line: String = box._label.text.replace("\n", " ")
			if _boxes == 1:
				await _shot("06_meet")
			elif line.contains("Aldo") and not seen.has("aldo"):
				seen["aldo"] = true
				await _shot("09_aldo")
			print("box %d: %s" % [_boxes, line])
			box.advance_now()
			await _frames(2)
			continue
		await get_tree().process_frame

func _find(root: Node, type: Variant) -> Node:
	for c: Node in root.get_children():
		if is_instance_of(c, type):
			return c
		var deep: Node = _find(c, type)
		if deep != null:
			return deep
	return null

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
