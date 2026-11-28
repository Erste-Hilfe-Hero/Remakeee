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
## The 1.3.2 pictures (window 440x956, see tools/store/make_store_images.py):
##   n1_shop_featured     the shop's Featured page (Era V, ShopZoom) without store prices and with
##                        the euro hints taken out: no money prices in any store picture
##   n2_pass_track        the pass track (PassScreen) in step 5 without the pass
##   n3_gleam_battle      a wild Rime Gleam in an Era V battle, its opening line in the text box;
##   n3_gleam_menu        instead, where that line takes two pages: the command menu after it
##   n4_weather_rain      Era V Mossgate in the rain (WeatherCycle, data/weather.json)
##   n5_puzzle            a puzzle board (data/puzzle_spots.json, Tracks in the Mud), Era V

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
## The Gleam picture: an Era IV foe, so its art takes the kind's colours.
const GLEAM_FOE: String = "Lumothane"
const GLEAM_KIND: String = "rime"
## [name, era, map, weather, hour, month, extra] as tools/weather_shots_runner.gd SHOTS.
const WEATHER: Array = ["rain", 5, "mossgate", "rain", 12.0, 6, ""]
## [spot id, moves played] of the puzzle picture.
const PUZZLE: Array = ["vey_tracks", ["right", "right", "down"]]
var out: String = "user://store_shots"
var lang: String = "en"
## "all", or a comma list of: title, hero, battle, unfurl, eras, story, league, menus, and the
## 1.3.2 groups shop, pass, gleam, weather, puzzle ("all" leaves those out: they need the tall window).
var only: String = "all"

func _ready() -> void:
	_run.call_deferred()

const TALL: Array[String] = ["shop", "pass", "gleam", "weather", "puzzle"]

func _want(group: String) -> bool:
	if only == "all":
		return not group in TALL
	return group in only.split(",")

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
	# The weekend note depends on the day the pictures are made: never in a store picture.
	GrowthRules.data()["weekend_mult"] = 1.0
	_language()
	var em: Node = get_tree().root.get_node("/root/EraManager")
	# Title (Era I, the first thing a player sees).
	EraBoot.shown = true
	# The title with its menu, not the one-time terms step and privacy note in front of it.
	Online.privacy_seen = true
	GameState.terms_version = LegalInfo.TERMS_VERSION
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
	if _want("shop"):
		await _shop(em)
	if _want("pass"):
		await _pass(em)
	if _want("gleam"):
		await _gleam(em)
	if _want("weather"):
		await _weather(em)
	if _want("puzzle"):
		await _puzzle(em)
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

## Takes the euro hints "(≈ 18,81 €)" out of every label under [param n] (store pictures carry no
## money prices; the store's own prices are not loaded, so the buttons say "Show").
static func no_money(n: Node) -> void:
	if n is Label:
		var l := n as Label
		var t: String = RegEx.create_from_string("\\s*\\(≈[^)]*\\)").sub(l.text, "", true)
		if t != l.text:
			l.text = t
			l.visible = not t.strip_edges().is_empty()
	for c: Node in n.get_children():
		no_money(c)

func _menu_state(em: Node) -> void:
	var mn: Node = _helper("res://tools/era_menu_shots_runner.gd")
	mn.call("setup_state")
	_language()
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 0)
	# The shots set the shop state themselves; a server answer must not replace it.
	if Online.state_changed.is_connected(Billing._on_online_state):
		Online.state_changed.disconnect(Billing._on_online_state)
	await get_tree().process_frame

func _shop(em: Node) -> void:
	await _menu_state(em)
	var p2w: Node = _helper("res://tools/p2w_shop_shots_runner.gd")
	var m := PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	p2w.call("_state", 18)
	Billing.prices.clear()
	var h: MenuHost = ShopZoom.enter(m)
	var s := ShopScreen.new()
	s.menu = h
	h.add_child(s)
	s.select_tab("featured")
	for i: int in 12:
		await get_tree().process_frame
	no_money(get_tree().root)
	await _save_root("n1_shop_featured", 1)
	s.queue_free()
	ShopZoom.leave(h)
	m.queue_free()
	await get_tree().process_frame

func _pass(em: Node) -> void:
	await _menu_state(em)
	var p2w: Node = _helper("res://tools/p2w_shop_shots_runner.gd")
	await p2w.call("_server", 0)
	var be: LocalBackend = p2w.get("_backend")
	var row: Dictionary = LocalPassTrack.of(be).row(be.me())
	row.points = PassTrack.per_tier() * 5 + PassTrack.per_tier() / 2
	row.claimed_free = 3
	var m := PauseMenu.new()
	add_child(m)
	await get_tree().process_frame
	PassScreen.run(m)
	await p2w.call("_wait_dialog", m, 0, 0)
	for i: int in 12:
		await get_tree().process_frame
	await _save_root("n2_pass_track", 1)
	m.close_all = true
	m.queue_free()
	await get_tree().process_frame

## A wild Rime Gleam meets the player's lead. When the opening line, with the kind's own sentence
## and name, fits one page of the text box, the picture shows it (n3_gleam_battle); in languages
## where it takes two pages, the picture is the command menu after it, with the Gleam mark on the
## foe's strip (n3_gleam_menu).
func _gleam(em: Node) -> void:
	_language()
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 5)
	Era45Look.biome_override = "route"
	DirAccess.remove_absolute("%s/n3_gleam_battle.png" % out)
	DirAccess.remove_absolute("%s/n3_gleam_menu.png" % out)
	var inst: BattleScene = _gleam_battle(GLEAM_KIND)
	var name: String = Loc.t(str(GleamRules.kind(GLEAM_KIND).get("name", "")))
	var fits: bool = false
	for i: int in 1800:
		await get_tree().process_frame
		if inst._text != null and inst._text._waiting and not inst._text._label.text.is_empty():
			fits = name in inst._text._label.text.replace("\n", " ")
			break
	if not fits:
		for i: int in 1800:
			if inst._menu != null and inst._menu._content != null and inst._menu._content.visible:
				break
			inst._text.advance_now()
			await get_tree().process_frame
	for i: int in 40:
		await get_tree().process_frame
	await _save_root("n3_gleam_battle" if fits else "n3_gleam_menu", 1)
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame
	Era45Look.biome_override = ""

func _gleam_battle(kind: String) -> BattleScene:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var mine: Array[Spirling] = BattleScene._demo_team(rng, [TEAM_MINE[0]] as Array[String], 40)
	var theirs: Array[Spirling] = BattleScene._demo_team(rng, [GLEAM_FOE] as Array[String], 38)
	GleamRules.apply(theirs[0], kind)
	var model := BattleModel.new(mine, theirs, true, 4321, 0)
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	inst.setup(model)
	get_tree().root.add_child(inst)
	return inst

func _weather(em: Node) -> void:
	_language()
	em.set("unlocked_era", 5)
	GameState.weather = true
	GameState.day_night = true
	var w: Node = _helper("res://tools/weather_shots_runner.gd")
	w.set("prefix", "raw")
	# A first overworld takes the start-up notices and settles the window; it is not shot.
	var warm: Node = load("res://scenes/overworld/Overworld.tscn").instantiate()
	get_tree().root.add_child(warm)
	for i: int in 20:
		await get_tree().process_frame
	warm.queue_free()
	await get_tree().process_frame
	GameState.notices.clear()
	await w.call("_shot", WEATHER)
	DirAccess.rename_absolute("%s/raw_%s.png" % [out, WEATHER[0]], "%s/n4_weather_rain.png" % out)
	GameState.weather = false
	EraLight.debug_weather = ""

func _puzzle(em: Node) -> void:
	_language()
	em.set("unlocked_era", 5)
	em.call("set_retro_filter", 5)
	GameState.weather = false
	var pz: Node = _helper("res://tools/puzzle_shots_runner.gd")
	await pz.call("_shot", "n5_puzzle", PuzzleSpots.by_id(str(PUZZLE[0])), "board", PUZZLE[1])

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
