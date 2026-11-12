extends Node
## The work of tools/screenshot.gd. It runs as a node in the tree, because autoload classes
## (GameState, VirtualPad, ...) are only known once the tree runs; compiled from the -s script
## itself, scenes and classes that use them fail to compile and the screens stay empty.

const SCALE: int = 3

var out: String = "user://shots"
var lang: String = "en"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var db: Object = get_tree().root.get_node("/root/GameState")
	Database.load_all()
	Loc.set_language(lang)
	db.language = lang
	await _shot_scene("res://scenes/ui/Title.tscn", "01_title", 40)
	db.new_game(1, "Rowan", 0, "Kindlop")
	for entry: Array in [["lighthouse", Vector2i(4, 4)], ["brindlewick", Vector2i(5, 8)], ["fernstair", Vector2i(8, 6)], ["crowcrest", Vector2i(8, 11)], ["saltmarsh", Vector2i(7, 10)], ["thornridge", Vector2i(6, 9)], ["cinder_rift", Vector2i(6, 10)]]:
		db.current_map = entry[0]
		db.player_cell = entry[1]
		await _shot_scene("res://scenes/overworld/Overworld.tscn", "02_ow_%s" % entry[0], 30)
	await _shot_scene("res://scenes/battle/Battle.tscn", "03_battle", 420, "", 40)
	await _shot_scene("res://scenes/battle/BondMinigame.tscn", "04_bond", 70, "run")
	# Story battles with several Spirlings per side (formation layout).
	for d: String in ["boss", "duel3", "tag", "horde"]:
		await _shot_scene("res://scenes/battle/Battle.tscn", "05_battle_%s" % d, 600, "", 40, {"demo": d})
	await _shot_shop()
	await _shot_v110(db)
	get_tree().quit()

## Chimora 1.1.0: the three new Rifts, their Wardens, Legal with Discord, seals and crystals,
## the team's Power and Era II.
func _shot_v110(db: Object) -> void:
	var rifts: Array = [["mist_rift", "warden_brisa"], ["root_rift", "warden_darrow"], ["shade_rift", "warden_odalys"]]
	for r: Array in rifts:
		db.current_map = r[0]
		db.player_cell = Vector2i(6, 10)
		await _shot_scene("res://scenes/overworld/Overworld.tscn", "07_ow_%s" % r[0], 30)
	for r: Array in rifts:
		var m: MapData = MapData.load_map(r[0])
		for n: Dictionary in m.npcs:
			if str(n.get("id", "")) == r[1]:
				await _shot_scene("res://scenes/battle/Battle.tscn", "08_battle_%s" % r[1], 420, "", 40, {"model": _warden_model(n, m), "backdrop": m.backdrop})
	Billing.state = {"balance": 2400, "band": 18, "open": true, "unlocks": {"power_seal": 3, "guard_seal": 2, "speed_seal": 1}}
	var ids: Array[String] = []
	for o: Dictionary in ShopCatalog.in_tab("advantages"):
		var id: String = str(o.get("id", ""))
		if "seal" in id or "crystal" in id:
			ids.append(id)
	await _shot_menu("09_shop_seals", func(h: MenuHost) -> void:
		var entries: Array[Dictionary] = []
		for id: String in ids:
			entries.append({"text": ShopMenu.row_text(ShopCatalog.offer(id))})
		h.pick(Loc.t("Advantages") + "  " + ShopCatalog.rg_text(Billing.balance()), entries, true, 0, 0))
	await _shot_menu("10_legal_discord", func(h: MenuHost) -> void: h.run_legal())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	GameState.party.append(Spirling.new(Database.species("Puddlet"), 12, rng))
	GameState.party[0].crystal = {"atk": 5, "spd": 3}
	Tips.take("team_order")
	await _shot_menu("11_team_power", func(h: MenuHost) -> void: (h as PauseMenu).run_team(), true)
	EraManager.unlocked_era = 2
	EraManager.retro_filter = 2
	EraManager._apply()
	for entry: Array in [["brindlewick", Vector2i(5, 8)], ["lighthouse", Vector2i(4, 4)]]:
		db.current_map = entry[0]
		db.player_cell = entry[1]
		await _shot_scene("res://scenes/overworld/Overworld.tscn", "12_era2_%s" % entry[0], 30)

func _warden_model(def: Dictionary, m: MapData) -> BattleModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var foes: Array[Spirling] = TrainerData.build_team(def, "", rng, 0, Spirling.STORY_RING)
	var top: int = 1
	for f: Spirling in foes:
		top = maxi(top, f.level)
	var mine: Array[Spirling] = []
	for sp: String in ["Kindlop", "Puddlet", "Zephlet", "Mossling"]:
		mine.append(Spirling.new(Database.species(sp), top, rng))
	var info: Dictionary = TrainerData.battle_info(def, foes, 1, 0)
	var model := BattleModel.new(mine, foes, false, 11, int(info.ai))
	model.trainer_name = str(def.get("name", ""))
	model.field = str(def.get("field", m.field))
	model.foe_rule = str(info.rule)
	var front: Array = def.get("front", [1, 1])
	model.front_size = [int(front[0]), int(front[1])]
	model.foe_boss = str(info.boss)
	model.inventory = {"tonic": 3}
	return model

## Opens a menu on a fresh MenuHost (or PauseMenu) without awaiting it and saves what it shows.
func _shot_menu(name: String, open: Callable, pause: bool = false) -> void:
	db_reduce_motion()
	var host: MenuHost = PauseMenu.new() if pause else MenuHost.new()
	get_tree().root.add_child(host)
	host.theme = UITheme.get_theme()
	await get_tree().process_frame
	open.call(host)
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	host.queue_free()
	await get_tree().process_frame

## [param tap_every] > 0 presses ui_accept every that many frames (advances battle text).
func _shot_scene(path: String, name: String, frames: int, start_method: String = "", tap_every: int = 0, props: Dictionary = {}) -> void:
	var packed: PackedScene = load(path)
	var inst: Node = packed.instantiate()
	for k: String in props:
		inst.set(k, props[k])
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	if inst is Control:
		(inst as Control).theme = UITheme.get_theme()
	if inst.has_method("run") and "target" in inst:
		inst.set("target", load("res://art/era1/spirlings/zippit_front.png"))
	if not start_method.is_empty():
		inst.call(start_method)
	for i: int in frames:
		if tap_every > 0 and i % tap_every == tap_every - 1:
			var ev := InputEventAction.new()
			ev.action = "ui_accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := InputEventAction.new()
			up.action = "ui_accept"
			Input.parse_input_event(up)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	inst.queue_free()
	await get_tree().process_frame

## The shop's Riftglass tab with euro prices, for App Review (each in-app purchase needs a picture
## of where it is sold: tools/store/make_store_images.py turns it into store/ios/iap_review.png).
func _shot_shop() -> void:
	db_reduce_motion()
	for o: Dictionary in ShopCatalog.offers():
		if bool(o.get("ready", false)) and o.has("eur_cents"):
			var eur: float = int(o.eur_cents) / 100.0
			Billing.prices[str(o.product_id)] = ("%.2f €" % eur).replace(".", ",") if lang == "de" else "€%.2f" % eur
	Billing.state = {"balance": 120, "band": 18, "open": true}
	var host := MenuHost.new()
	get_tree().root.add_child(host)
	host.theme = UITheme.get_theme()
	await get_tree().process_frame
	var entries: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.in_tab("riftglass"):
		entries.append({"text": ShopMenu.row_text(o)})
	host.pick(Loc.t("Riftglass") + "  " + ShopCatalog.rg_text(Billing.balance()), entries, true, 0, 0)
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, "06_shop"])
	print("saved 06_shop")
	host.queue_free()
	await get_tree().process_frame

func db_reduce_motion() -> void:
	GameState.reduce_motion = true
	GameState.in_game = false
