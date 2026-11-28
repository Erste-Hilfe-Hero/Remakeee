extends Node
## The work of tools/bond_video.gd, run as a node so the autoloads exist. Everything on screen is
## the game itself (Overworld, BattleScene, BondMinigame, PauseMenu, ShopScreen); this script only
## plays the player: it taps text on, picks the first art, holds out the Kin Charm, taps "Mine!"
## fast, then opens the Team list and the shop.
## Which roll of the battle's seeded RNG the video gets is chosen before the first order: seeds are
## tried in a dry run of the same model (BattleReplay) until the scripted orders bond, and the live
## model takes that seed and its RNG state. Damage, the bond chance (BondCalc) and the foe's turns are still
## the game's own; nothing is forced.

const FPS: int = 30
const MAP: String = "fernstair"
const STARTER: String = "Kindlop"
const WILD: String = "Zephlet"
const WILD_RING: int = 3
## The player's orders, one per turn.
const ORDERS: Array[String] = ["art", "bond"]
const CHARM: String = "kin_charm"
## Seconds a text page stays up before the script taps it on (a quick but readable player).
const READ_TIME: float = 0.75
## Seconds before a menu choice is tapped.
const THINK_TIME: float = 0.45
## Frames between two "Mine!" taps (10 taps a second at 30 fps).
const TAP_FRAMES: int = 3
## [era, map, weather, hour, seconds]: the world after the bond.
const WORLD: Array = [[3, "ledgerholm", "storm", 19.0, 2.6], [5, "mossgate", "rain", 12.0, 2.6]]
## Looks only: cosmetic jackets, no bundles or badges in a store preview.
const SHOP_TABS: Array[String] = ["looks"]
const SHOP_TAB_TIME: float = 2.8

var _ow: Overworld
var _wait_t: Dictionary = {}
var _taps: int = 0
var _order: int = 0
var _seeded: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _wait(seconds: float) -> void:
	for i: int in int(seconds * FPS):
		await get_tree().process_frame

func _run() -> void:
	SaveManager.settings_path = "user://bond_video_settings.json"
	SaveManager.slot_path = "user://bond_video_save.json"
	Database.load_all()
	GameState.language = "en"
	Loc.set_language("en")
	GameState.new_game(1, "Rowan", 0, STARTER)
	GameState.set_flag("got_starter")
	for id: String in Tips.TOPICS:
		GameState.set_flag(Tips.flag(id))
	GameState.tips_enabled = false
	GameState.reduce_motion = false
	GameState.day_night = true
	GameState.weather = true
	GameState.bond_style = "mine"
	GameState.battle_speed = 2
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(1)
	EraLight.debug_weather = "rain"
	EraLight.debug_hour = 12.0
	var m: MapData = MapData.load_map(MAP)
	GameState.current_map = m.id
	GameState.player_cell = _spot(m)
	_ow = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(_ow)
	get_tree().current_scene = _ow
	_quiet()
	await get_tree().process_frame
	_check_size()
	await _wait(0.3)
	_quiet()
	await _walk()
	await _wait(0.4)
	print("bond_video: battle at %.2f s" % _now())
	var wild := Spirling.new(Database.species(WILD), WILD_RING, _rng(3))
	var outcome: Array = [-1]
	var battle := func() -> void:
		outcome[0] = await _ow.start_battle([wild] as Array[Spirling], true)
	battle.call()
	while int(outcome[0]) < 0:
		await get_tree().process_frame
		_play_battle()
	print("bond_video: outcome %d, team %s at %.2f s" % [int(outcome[0]), _names(), _now()])
	if int(outcome[0]) != BattleModel.Outcome.BONDED:
		printerr("bond_video: the bond did not land")
		get_tree().quit(1)
		return
	await _wait(0.4)
	await _team_screen()
	for w: Array in WORLD:
		await _world(w)
	await _shop()
	print("bond_video: end at %.2f s, %d frames" % [_now(), Engine.get_frames_drawn()])
	get_tree().quit()

## Movie Maker writes frames at the project's base size; the view must match it or every frame
## is squeezed (run with the override.cfg from tools/bond_video.gd).
func _check_size() -> void:
	var movie := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var view := Vector2i(get_viewport().get_visible_rect().size)
	print("bond_video: view %s, movie %s, window %s" % [view, movie, get_window().size])
	if view != movie:
		printerr("bond_video: view %s differs from the movie size %s; set it in override.cfg" % [view, movie])

func _now() -> float:
	return Engine.get_frames_drawn() / float(FPS)

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _names() -> String:
	var n: PackedStringArray = []
	for s: Spirling in GameState.party:
		n.append(s.data.species_name)
	return ", ".join(n)

## Start-up notes (daily gift, weekend) are not what the video is about.
func _quiet() -> void:
	GameState.notices.clear()
	var ticker: Node = get_node_or_null("/root/Ticker")
	if ticker != null:
		(ticker.get("_queue") as Array).clear()
		(ticker.get("_bar") as CanvasItem).visible = false
	if _ow != null and _ow.toast != null:
		_ow.toast.visible = false

## A path cell near the middle of [param m] with two more path cells to its right.
func _spot(m: MapData) -> Vector2i:
	var mid := Vector2(m.width, m.height) / 2.0
	var best := Vector2i(1, 1)
	var best_d: float = INF
	for y: int in m.height:
		for x: int in m.rows[y].length():
			var c := Vector2i(x, y)
			var d: float = Vector2(c).distance_to(mid)
			if d < best_d and _path(m, c) and _path(m, c + Vector2i(1, 0)) and _path(m, c + Vector2i(2, 0)):
				best = c
				best_d = d
	return best

func _path(m: MapData, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.y < m.height and c.x < m.rows[c.y].length() and m.is_walkable(c) \
		and m.warp_at(c).is_empty() and m.kind_at(c) == TilesetFactory.Kind.PATH

## Two steps along the path, as a held direction key does.
func _walk() -> void:
	Input.action_press("ui_right")
	await _wait(0.55)
	Input.action_release("ui_right")
	await _wait(0.3)

## Gives [param model] (started, no order yet) the RNG state of the first seed under which ORDERS
## bond in a dry run of the same battle.
func _seed_for_bond(model: BattleModel) -> void:
	var snap: Dictionary = BattleReplay.snapshot(model, "", "")
	for s: int in range(1, 5000):
		snap["seed"] = s
		var m: BattleModel = BattleReplay.build_model(snap)
		# The replay snapshot leaves out the fog of a wild battle (sight_mult).
		m.sight_mult = model.sight_mult
		m.start()
		var state: int = m.rng.state
		var trace: PackedStringArray = []
		for o: String in ORDERS:
			if m.is_finished():
				break
			m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0) if o == "art"
				else BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0, CHARM))
			trace.append(_hp(m))
		if m.outcome == BattleModel.Outcome.BONDED:
			# The foe AI breaks ties by the battle seed, so the seed goes over with the RNG state.
			model.battle_seed = s
			model.rng.state = state
			print("bond_video: seed %d, dry run %s" % [s, " | ".join(trace)])
			return
	printerr("bond_video: no seed bonds")

func _hp(m: BattleModel) -> String:
	var p: Spirling = m.active_spirling(BattleModel.Side.PLAYER, 0)
	var f: Spirling = m.active_spirling(BattleModel.Side.FOE, 0)
	return "turn %d %s %d/%d vs %s %d/%d outcome %d" % [m.turn, p.data.species_name, p.hp, p.max_hp(), f.data.species_name, f.hp, f.max_hp(), m.outcome]

## One frame of the player in battle: read, tap on, choose.
func _play_battle() -> void:
	_tap_text()
	var scene: BattleScene = null
	for c: Node in _ow._battle_layer.get_children():
		if c is BattleScene:
			scene = c
	if scene == null:
		return
	# Seeded at the first orders: by then the battle has started and its field (fog, rain) is set.
	if not _seeded and scene._waiting_orders:
		_seeded = true
		_seed_for_bond(scene.model)
	if scene._bond_game.visible and scene._bond_game._phase == BondMinigame.Phase.MINE:
		_taps += 1
		if _taps % TAP_FRAMES == 0:
			scene._bond_game.mine_tap()
		return
	if scene._picker.visible:
		if _ready_after("picker"):
			_answer(scene._picker, "Yes")
			_wait_t.erase("picker")
		return
	if scene._waiting_orders and scene._menu.visible and scene._menu._content.visible:
		if not _ready_after("orders"):
			return
		_wait_t.erase("orders")
		print("bond_video: live order %d, turn %d, %s, state %d" % [_order, scene.model.turn, _hp(scene.model), scene.model.rng.state])
		var art: Button = scene._menu.first_art_button()
		if ORDERS[mini(_order, ORDERS.size() - 1)] == "art" and art != null and not art.disabled:
			art.pressed.emit()
		else:
			scene._menu._bond.pressed.emit()
		_order += 1
	else:
		_wait_t.erase("orders")

## True once [param key] has been waited on for THINK_TIME.
func _ready_after(key: String, seconds: float = THINK_TIME) -> bool:
	_wait_t[key] = int(_wait_t.get(key, 0)) + 1
	return _wait_t[key] >= int(seconds * FPS)

## Every text box that waits for a tap gets one after READ_TIME.
func _tap_text() -> void:
	for tb: Node in get_tree().root.find_children("*", "TextBox", true, false):
		var box := tb as TextBox
		var id: String = str(box.get_instance_id())
		if not box.is_visible_in_tree() or not box._waiting:
			_wait_t.erase(id)
			continue
		if _ready_after(id, READ_TIME):
			box._waiting = false
			box.advanced.emit()
			_wait_t.erase(id)

## Taps the row of [param picker] whose text starts with [param label].
func _answer(picker: ListPicker, label: String) -> bool:
	for i: int in picker._buttons.size():
		if picker._buttons[i].text.begins_with(Loc.t(label)):
			picker.picked.emit(i)
			return true
	printerr("bond_video: no row %s" % label)
	return false

## Waits until [param picker] shows its rows, then taps [param label].
func _choose(picker: ListPicker, label: String) -> void:
	for i: int in 10 * FPS:
		await get_tree().process_frame
		_tap_text()
		if picker.visible and picker._buttons.size() > 0:
			break
	await _wait(THINK_TIME)
	_answer(picker, label)

func _menu() -> PauseMenu:
	for c: Node in _ow._ui.get_children():
		if c is PauseMenu:
			return c
	return null

## The pause menu's Team list with the new Spirling in it.
func _team_screen() -> void:
	_ow.open_menu.call_deferred()
	for i: int in 3:
		await get_tree().process_frame
	await _choose(_menu().picker, "Team")
	await _wait(2.4)

## The world after the bond: another era, another sky.
func _world(w: Array) -> void:
	EraManager.unlocked_era = maxi(EraManager.unlocked_era, int(w[0]))
	EraManager.set_retro_filter(int(w[0]))
	EraLight.debug_weather = str(w[2])
	EraLight.debug_hour = float(w[3])
	var m: MapData = MapData.load_map(str(w[1]))
	GameState.current_map = m.id
	GameState.player_cell = _spot(m)
	_ow.queue_free()
	await get_tree().process_frame
	_ow = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(_ow)
	get_tree().current_scene = _ow
	_quiet()
	await _wait(0.2)
	_quiet()
	await _walk()
	await _wait(float(w[4]) - 1.05)

## The shop from the pause menu, as an adult account sees it (a kids account never does).
func _shop() -> void:
	Billing.state = {"balance": 0, "band": 18, "open": true, "bought": {}, "unlocks": {}}
	_ow.open_menu.call_deferred()
	await _wait(0.4)
	var menu: PauseMenu = _menu()
	var shop := func() -> void:
		await ShopScreen.open(menu)
	shop.call()
	await get_tree().process_frame
	var screen: ShopScreen = get_tree().root.find_children("*", "ShopScreen", true, false)[0]
	for t: String in SHOP_TABS:
		screen.select_tab(t)
		await _wait(SHOP_TAB_TIME)
