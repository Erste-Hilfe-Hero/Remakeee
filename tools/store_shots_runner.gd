extends Node
## The work of tools/store_shots.gd, run as a node so the autoloads exist. Reuses the shot code of
## the era design-review tools (overworld, battle, menus) without running their full lists.

const SCALE: int = 3
## [file, era, map, cell, hour]
const OVERWORLD: Array = [
	["o1_era1_brindlewick", 1, "brindlewick", Vector2i(5, 8), 12],
	["o2_era2_brindlewick", 2, "brindlewick", Vector2i(5, 8), 12],
	["o3_era3_ledgerholm", 3, "ledgerholm", Vector2i(5, 9), 12],
	["o4_era4_starwell", 4, "starwell", Vector2i(5, 9), 12],
	["o5_era5_driftwick", 5, "driftwick", Vector2i(5, 9), 17],
]
var out: String = "user://store_shots"
var lang: String = "en"

func _ready() -> void:
	_run.call_deferred()

## A node running one of the era tools' scripts with its own full run switched off.
func _helper(path: String) -> Node:
	var s := GDScript.new()
	s.source_code = "extends \"%s\"\nfunc _run() -> void:\n\tpass\n" % path
	s.reload()
	var n := Node.new()
	n.set_script(s)
	n.set("out", out)
	add_child(n)
	return n

func _language() -> void:
	GameState.language = lang
	Loc.set_language(lang)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	SaveManager.settings_path = "user://store_shots_settings.json"
	Database.load_all()
	_language()
	var em: Node = get_tree().root.get_node("/root/EraManager")
	# Title (Era I, the first thing a player sees).
	EraBoot.shown = true
	# The title with its menu, not the one-time privacy note in front of it.
	Online.privacy_seen = true
	em.set("unlocked_era", 1)
	em.call("set_retro_filter", 1)
	await _scene("res://scenes/ui/Title.tscn", "t01_title", 300)
	# Overworld in each era.
	var ow: Node = _helper("res://tools/era45_overworld_shots_runner.gd")
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.weather = false
	GameState.tips_enabled = false
	GameState.reduce_motion = false
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 1)
	await ow.call("_shot", "warmup")
	DirAccess.remove_absolute("%s/warmup.png" % out)
	for s: Array in OVERWORLD:
		em.call("set_retro_filter", int(s[1]))
		var m: MapData = MapData.load_map(str(s[2]))
		var cell: Vector2i = s[3]
		if not m.is_walkable(cell):
			cell = ow.call("_free_cell", m, cell)
		GameState.current_map = str(s[2])
		GameState.player_cell = cell
		GameState.records["clock_shift"] = posmod(int(s[4]) - int(Time.get_time_dict_from_system().hour), 24)
		await ow.call("_shot", str(s[0]))
	# 3v3 battles: the same matchup in three eras.
	var bt: Node = _helper("res://tools/era_battle_shots_runner.gd")
	Era45Look.biome_override = "route"
	for era: int in [2, 4, 5]:
		em.call("set_retro_filter", era)
		await bt.call("_shot", era, "field", "3v3", {"front": [3, 3]})
	Era45Look.biome_override = ""
	# Spirlog page and an offer's contents in the shop, in the Era IV menus.
	var mn: Node = _helper("res://tools/era_menu_shots_runner.gd")
	mn.call("setup_state")
	_language()
	for o: Dictionary in ShopCatalog.offers():
		if bool(o.get("ready", false)) and o.has("eur_cents"):
			var eur: float = int(o.eur_cents) / 100.0
			Billing.prices[str(o.product_id)] = ("%.2f €" % eur).replace(".", ",") if lang in ["de", "fr", "es", "it", "pt_BR", "nl", "pl", "tr", "ru"] else "€%.2f" % eur
	em.set("unlocked_era", 4)
	em.call("set_retro_filter", 0)
	await get_tree().process_frame
	var pm: PauseMenu = mn.call("_menu")
	await get_tree().process_frame
	var kinds: Array[SpirlingData] = mn.call("_seen_kinds")
	await mn.call("_shoot", pm, "m1_spirlog", func() -> void: await SpirlogPage.show_pages(pm, kinds, 1), [])
	# "_summary" in the name keeps the info box open for the picture (era menu runner).
	await mn.call("_shoot", pm, "m2_shop_summary", func() -> void: await pm.info(ShopMenu.detail_text(ShopCatalog.offer("rg_bond_lure_1"))), [])
	pm.queue_free()
	get_tree().quit()

func _scene(path: String, name: String, frames: int) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	if inst is Control:
		(inst as Control).theme = UITheme.get_theme()
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	inst.queue_free()
	await get_tree().process_frame
