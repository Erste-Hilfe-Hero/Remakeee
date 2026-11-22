extends Node
## The work of tools/store_shots.gd, run as a node so the autoloads exist. Reuses the shot code of
## the era design-review tools (overworld, battle, menus) without running their full lists.
## The store set (plan Chimora 100, items 86, 87, 97), all from the running game:
##   t01_title            title (feature graphic art)
##   hero_<kind>[_gleam]  Era IV Spirling sprites drawn by SpirlingSprite on a clear background,
##                        a Gleam one through its Gleam palette; glint.png is the Gleam glint
##   b1_era5_3v3          3v3 battle in Era V with Era IV kinds
##   u1_before, u3_after the unfurl moment (UnfurlSequence) in Era V: old form, new form
##   o1..o4_brindlewick   one town (Brindlewick) in Eras I to IV (V draws it like IV)
##   s1_story             Era V Brindlewick, Wren's line in the text box
##   l2_league            the Fair league screen (LeagueMenu on the local server): tier, rank, season.
##                        Live duels are off on the live server, so the store set shows the league
##                        instead; start_duel() stays for tools/store_video_runner.gd
##   m1_spirlog           a Spirlog page (Era V menus)
##   m2_shop_looks        the shop's Looks list (Era V menus): Riftglass prices, no money prices

const SCALE: int = 3
const OVERWORLD_CELL: Vector2i = Vector2i(5, 8)
## [file, era, hour]
const OVERWORLD: Array = [
	["o1_era1_brindlewick", 1, 12], ["o2_era2_brindlewick", 2, 12], ["o3_era3_brindlewick", 3, 12],
	["o4_era4_brindlewick", 4, 12],
]
## Era IV kinds for the hero picture, the battle and the duel (no franchise look, own art).
const HERO: Array[String] = ["Noonregent", "Glintheron", "Gildaurus", "Eaveprowl", "Dewstag", "Orremarch", "Lumothane"]
const HERO_GLEAM: Array[String] = ["Orremarch"]
const TEAM_MINE: Array[String] = ["Noonregent", "Glintheron", "Dewstag"]
const TEAM_FOE: Array[String] = ["Eaveprowl", "Gildaurus", "Orremarch"]
const UNFURL: Array[String] = ["Glintwader", "Glintheron"]
## Act I line (data/dialogue/clans.json, Wren at the Crooked Kettle): trust and dark humour, no spoiler flag.
const STORY_LINE: String = "Wren: My advice? Trust nobody who pays on time. That's a joke. Mostly."
const FRIEND: String = "Mara"
var out: String = "user://store_shots"
var lang: String = "en"
## "all", or a comma list of: title, hero, battle, unfurl, eras, story, league, menus.
var only: String = "all"

func _ready() -> void:
	_run.call_deferred()

func _want(group: String) -> bool:
	return only == "all" or group in only.split(",")

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
	if _want("title"):
		await _scene("res://scenes/ui/Title.tscn", "t01_title", 300)
	GameState.new_game(1, "Rowan", 0, "Kindlop")
	GameState.set_flag("got_starter")
	GameState.weather = false
	GameState.tips_enabled = false
	GameState.reduce_motion = false
	em.set("unlocked_era", 5)
	if _want("hero"):
		await _hero()
	if _want("battle"):
		em.call("set_retro_filter", 5)
		var bt: Node = _helper("res://tools/era_battle_shots_runner.gd")
		Era45Look.biome_override = "route"
		await bt.call("_shot", 5, "field", "store_3v3", {"front": [3, 3], "team": [TEAM_MINE, TEAM_FOE]})
		Era45Look.biome_override = ""
		DirAccess.rename_absolute("%s/era5_field_store_3v3.png" % out, "%s/b1_era5_3v3.png" % out)
	if _want("unfurl"):
		em.call("set_retro_filter", 5)
		await _unfurl()
	var ow: Node = _helper("res://tools/era45_overworld_shots_runner.gd")
	if _want("eras") or _want("story"):
		em.call("set_retro_filter", 1)
		await ow.call("_shot", "warmup")
		DirAccess.remove_absolute("%s/warmup.png" % out)
	if _want("eras"):
		for s: Array in OVERWORLD:
			em.call("set_retro_filter", int(s[1]))
			_place("brindlewick", int(s[2]), ow)
			await ow.call("_shot", str(s[0]))
	if _want("story"):
		em.call("set_retro_filter", 5)
		_place("brindlewick", 12, ow)
		await _story()
	if _want("league"):
		await _league(em)
	if _want("menus"):
		await _menus(em)
	get_tree().quit()

func _place(map: String, hour: int, ow: Node) -> void:
	var m: MapData = MapData.load_map(map)
	var cell: Vector2i = OVERWORLD_CELL
	if not m.is_walkable(cell):
		cell = ow.call("_free_cell", m, cell)
	GameState.current_map = map
	GameState.player_cell = cell
	GameState.records["clock_shift"] = posmod(hour - int(Time.get_time_dict_from_system().hour), 24)

## Each hero kind once as the game draws it in battle (SpirlingSprite, rest pose), on a clear
## background at 1:1, and the Gleam glint, so the store tool can lay them out large.
func _hero() -> void:
	var keep: bool = GameState.reduce_motion
	GameState.reduce_motion = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for kind: String in HERO:
		await _sprite_png(Spirling.new(Database.species(kind), 40, rng), "hero_" + kind.to_lower())
	for kind: String in HERO_GLEAM:
		var s := Spirling.new(Database.species(kind), 40, rng)
		s.gleam = true
		await _sprite_png(s, "hero_%s_gleam" % kind.to_lower())
	var glint: Texture2D = ElementFx.shape("glint", 0)
	if glint != null:
		glint.get_image().save_png("%s/glint.png" % out)
	GameState.reduce_motion = keep

func _sprite_png(s: Spirling, file: String) -> void:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(96, 96)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var sp := SpirlingSprite.new()
	sp.size = Vector2(vp.size)
	vp.add_child(sp)
	sp.setup(s, "front")
	for i: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("%s/%s.png" % [out, file])
	print("saved ", file)
	vp.queue_free()
	await get_tree().process_frame

## The unfurl moment in the era's look: the old form before the swap of silhouettes, the new form after it.
func _unfurl() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var u := UnfurlSequence.new()
	layer.add_child(u)
	u._old = UnfurlSequence._tex(Database.species(UNFURL[0]))
	u._new = UnfurlSequence._tex(Database.species(UNFURL[1]))
	u.set_process(false)
	u._time = 1.3
	# [file, new form shown, as silhouette]
	for st: Array in [["u1_before", false, false], ["u3_after", true, false]]:
		u._show_new = bool(st[1])
		u._silhouette = bool(st[2])
		u.queue_redraw()
		u._sprite.queue_redraw()
		for i: int in 4:
			await get_tree().process_frame
		await _save_root(str(st[0]), 1)
	layer.queue_free()
	await get_tree().process_frame

func _story() -> void:
	var inst: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(inst)
	for i: int in 150:
		await get_tree().process_frame
	var box: TextBox = inst.call("text_box")
	box.visible = true
	box.show_prompt(STORY_LINE)
	for i: int in 30:
		await get_tree().process_frame
	await _save_root("s1_story", 1)
	inst.queue_free()
	await get_tree().process_frame

## A live duel with a friend on the local stand-in of the server (the same flow as
## tests/unit/test_live_referee.gd): both teams picked, the duel running. Online talks to that
## stand-in until [method end_duel]. Returns [stage, server, duel id, old backend, old state];
## the caller adds the stage to the tree. Also used by tools/store_video_runner.gd.
static func start_duel(mine: Array[String], theirs: Array[String], friend: String) -> Array:
	var keep: Array = [Online.backend, Online.state]
	var s := LocalBackend.new()
	s.rng.seed = 1
	var codes: Dictionary = {}
	for who: String in ["me", "friend"]:
		var team: Array = []
		for k: String in (mine if who == "me" else theirs):
			team.append({"species": k, "level": 40, "moves": []})
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": Online.CLIENT_VERSION}).data.profile.code
		s.call_fn("team_set", {"p_team": team})
	s.db.flags["live_duel"] = {"enabled": true, "min_version": 1}
	s.switch_user("me")
	s.call_fn("friend_request", {"p_code": codes.friend})
	s.switch_user("friend")
	s.call_fn("friend_respond", {"p_code": codes.me, "p_accept": true})
	s.switch_user("me")
	var id: int = int(s.call_fn("live_invite", {"p_code": codes.friend}).data.id)
	s.switch_user("friend")
	s.call_fn("live_answer", {"p_id": id, "p_accept": true})
	s.call_fn("live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	s.switch_user("me")
	s.call_fn("live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	Online.backend = s
	Online.state = Online.State.ONLINE
	var stage := LiveDuelStage.new()
	stage.setup({"id": id, "name": friend})
	return [stage, s, id] + keep

## The friend waves and the player picks the first art, so the bar with both names, the round
## and its clock shows. Waits until the stage offers the choice first.
static func wave_and_pick(tree: SceneTree, duel: Array) -> void:
	var stage: LiveDuelStage = duel[0]
	var s: LocalBackend = duel[1]
	for i: int in 1800:
		await tree.process_frame
		if stage.scene != null and stage._choosing and stage._panel != null:
			break
	s.switch_user("friend")
	s.call_fn("live_emote", {"p_id": int(duel[2]), "p_emote": 1})
	s.switch_user("me")
	if stage._panel != null:
		stage._panel.emit_signal("picked", 0)

static func end_duel(duel: Array) -> void:
	var stage: LiveDuelStage = duel[0]
	stage._leave = true
	if stage.is_inside_tree():
		stage.queue_free()
	else:
		stage.free()
	Online.backend = duel[3]
	Online.state = duel[4]

## The Fair league screen as Menu > Leagues shows it, on the local stand-in of the server with the
## league flags it ships with (league_fair is on live). The player has joined with the store team
## and played part of a season. Online is given back after the shot.
static func start_league(mine: Array[String]) -> Array:
	var keep: Array = [Online.backend, Online.state, Online.flags.duplicate()]
	var s := LocalBackend.new()
	s.rng.seed = 1
	s.switch_user("me")
	var hello: Dictionary = s.call_fn("hello", {"p_version": Online.CLIENT_VERSION}).data
	var team: Array = []
	var pick: Array = []
	for k: String in mine:
		team.append({"species": k, "level": 40, "moves": []})
		pick.append({"species": k, "moves": []})
	s.call_fn("team_set", {"p_team": team})
	s.call_fn("league_join", {"p_league": LeagueRules.FAIR, "p_pick": pick})
	var entry: Dictionary = s.league_entry(LeagueRules.FAIR, int(s.league_season().id), s.me())
	entry.rating = 1500.0
	entry.games = 14
	entry.wins = 9
	Online.backend = s
	Online.state = Online.State.ONLINE
	Online.flags.assign(hello.flags)
	return [s] + keep

static func end_league(league: Array) -> void:
	Online.backend = league[1]
	Online.state = league[2]
	Online.flags.assign(league[3])

func _league(em: Node) -> void:
	var mn: Node = _helper("res://tools/era_menu_shots_runner.gd")
	mn.call("setup_state")
	_language()
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 0)
	var league: Array = start_league(TEAM_MINE)
	await get_tree().process_frame
	var pm: PauseMenu = mn.call("_menu")
	await get_tree().process_frame
	# The league's status (rule, Ring, tier, rank, battles) is longer than a list title, so the
	# game shows it in full first; that is the screen in the picture.
	var open := func() -> void: await LeagueMenu.run_league(pm, LeagueRules.FAIR)
	open.call()
	for i: int in 600:
		await get_tree().process_frame
		if pm._info_wait:
			break
	for i: int in 30:
		await get_tree().process_frame
	await _save_root("l2_league", 1)
	pm.queue_free()
	end_league(league)
	await get_tree().process_frame

func _menus(em: Node) -> void:
	var mn: Node = _helper("res://tools/era_menu_shots_runner.gd")
	mn.call("setup_state")
	_language()
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 0)
	await get_tree().process_frame
	var pm: PauseMenu = mn.call("_menu")
	await get_tree().process_frame
	var kinds: Array[SpirlingData] = mn.call("_seen_kinds")
	await mn.call("_shoot", pm, "m1_spirlog", func() -> void: await SpirlogPage.show_pages(pm, kinds, 1), [])
	# The Looks list as the shop draws it; the tab title without the balance line, whose money
	# hint is in euros (no euro prices in the store pictures of other currencies).
	var looks: Array[Dictionary] = []
	for o: Dictionary in ShopCatalog.in_tab("looks"):
		looks.append(ShopMenu.offer_row(o, EraMenus.layout(EraManager.active_era(), "shop")))
	await mn.call("_shoot", pm, "m2_shop_looks", func() -> void:
		await pm.pick_screen("shop", Loc.t(ShopCatalog.TAB_NAMES["looks"]), looks, {}), [])
	pm.queue_free()

func _save_root(name: String, scale: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)

func _scene(path: String, name: String, frames: int) -> void:
	var inst: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	if inst is Control:
		(inst as Control).theme = UITheme.get_theme()
	for i: int in frames:
		await get_tree().process_frame
	await _save_root(name, SCALE)
	inst.queue_free()
	await get_tree().process_frame
