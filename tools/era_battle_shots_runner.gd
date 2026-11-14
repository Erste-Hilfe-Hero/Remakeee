extends Node
## The work of tools/era_battle_shots.gd, run as a node so the autoloads exist.
## Every "settled" shot waits until the opening is over: the text is advanced until the command
## menu is open, so all Spirlings have stepped out before the picture is taken.

const SCALE: int = 2
## Frames to wait for the command menu at most, and to let landings and dust finish after it.
const READY_FRAMES: int = 1800
const SETTLE_FRAMES: int = 40
## Stage scenes shown per Era IV/V: [terrain, biome, label].
const SCENES: Array = [["field", "route", "meadow"], ["field", "cave", "cave"], ["lake", "route", "water"],
	["field", "town", "town"], ["ridge", "route", "snow"], ["ember", "route", "ember"], ["voice", "route", "voice"]]
## Teams with Era III art: [mine, theirs].
const NATIVE: Array = [["Blotkin", "Burrin", "Canalurk"], ["Cindrel", "Cindrik", "Blotgrimm"]]
## Formation sizes shown per era: label -> [player front, foe front].
const FORMATIONS: Dictionary = {"1v1": [1, 1], "2v2": [2, 2], "3v3": [3, 3]}
var out: String = "user://era_shots"
## "all", or a comma list of groups: terrain, sky, formation, fx, scenes, reduced.
var only: String = "all"

func _ready() -> void:
	_run.call_deferred()

func _want(group: String) -> bool:
	return only == "all" or group in only.split(",")

func _run() -> void:
	Database.load_all()
	# The saved settings of this machine may have reduced motion on; the pictures need it off.
	GameState.reduce_motion = false
	# The demo battles stand on a route, so the Era IV/V stage shows its field scene like the
	# older eras (the "scenes" group shows the others).
	Era45Look.biome_override = "route"
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.set("unlocked_era", 5)
	for era: int in range(1, 6):
		em.call("set_retro_filter", era)
		if _want("terrain"):
			for terrain: String in (["field", "lake", "ember"] if era > 1 else ["field"]):
				await _shot(era, terrain, "intro", {"frames": 12})
				await _shot(era, terrain, "settled")
		if _want("sky"):
			await _shot(era, "field", "rain", {"sky": "rain"})
			await _shot(era, "ridge", "storm", {"sky": "storm"})
			await _shot(era, "field", "wind", {"sky": "wind"})
		if _want("formation"):
			for f: String in FORMATIONS:
				await _shot(era, "field", f, {"front": FORMATIONS[f]})
		if _want("fx"):
			for fx: String in EraMoveFx.KINDS:
				await _shot(era, "field", "fx_" + fx, {"fx": fx})
		if _want("scenes") and era >= 4:
			# Era IV/V stage scenes (data/era45_stage.json): the demo team and Era III art (64 px),
			# which the stage draws at a whole multiple.
			for sc: Array in SCENES:
				Era45Look.biome_override = str(sc[1])
				await _shot(era, str(sc[0]), "scene_" + str(sc[2]))
				await _shot(era, str(sc[0]), "scene_" + str(sc[2]) + "_e3", {"team": NATIVE})
			Era45Look.biome_override = "route"
		if _want("fields"):
			# Rift field badge and tint (KAMPF_PLAN_1000 items 322, 331): a place field, and a
			# Resonance field with turns left in a 3v3.
			await _shot(era, "field", "field_place", {"field": "pollen_drift"})
			await _shot(era, "field", "field_3v3", {"front": FORMATIONS["3v3"], "resonance": "gale_eye"})
		if _want("reduced"):
			GameState.reduce_motion = true
			await _shot(era, "field", "wind_reduced", {"sky": "wind"})
			await _shot(era, "field", "3v3_reduced", {"front": FORMATIONS["3v3"]})
			GameState.reduce_motion = false
	get_tree().quit()

## The same matchup in every era and every formation size, so only the era differs.
static func formation_model(front: Array, team: Array = []) -> BattleModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = BattleScene.DEMO_SEED
	var a: Array[String] = ["Kindlop", "Puddlet", "Mossling"]
	var b: Array[String] = ["Zippit", "Shalebat", "Kelpup"]
	if team.size() == 2:
		a.assign(team[0])
		b.assign(team[1])
	var mine: Array[Spirling] = BattleScene._demo_team(rng, a, 14)
	var theirs: Array[Spirling] = BattleScene._demo_team(rng, b, 14)
	var m := BattleModel.new(mine, theirs, false, BattleScene.DEMO_SEED, 1)
	m.front_size = [int(front[0]), int(front[1])]
	m.trainer_name = "Rift Mystic Ilka"
	return m

## True once the opening is over and the player is asked for orders.
static func settled(inst: BattleScene) -> bool:
	return inst._menu != null and inst._menu._content != null and inst._menu._content.visible

func _shot(era: int, terrain: String, tag: String, opt: Dictionary = {}) -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = terrain
	var m: BattleModel = formation_model(opt.get("front", [1, 1]), opt.get("team", []))
	var sky: String = str(opt.get("sky", ""))
	if sky == "wind":
		m.set_meta(BattleWeather.SKY_META, sky)
	elif not sky.is_empty():
		var f: Dictionary = WeatherCycle.battle_field(sky)
		m.field = str(f.field)
		m.field_intro = str(f.intro)
	if opt.has("field"):
		m.field = str(opt.field)
	inst.setup(m)
	get_tree().root.add_child(inst)
	if opt.has("frames"):
		for i: int in int(opt.frames):
			await get_tree().process_frame
	else:
		# The menu is only closed once the battle starts running, so let it start first.
		for i: int in 3:
			await get_tree().process_frame
		var left: int = READY_FRAMES
		while not settled(inst) and left > 0:
			inst._text.advance_now()
			await get_tree().process_frame
			left -= 1
		if left <= 0:
			push_error("era%d %s %s: the command menu never opened" % [era, terrain, tag])
		for i: int in SETTLE_FRAMES:
			await get_tree().process_frame
	if opt.has("resonance"):
		inst.model.set_field(str(opt.resonance), BattleRules.RESONANCE_TURNS)
		inst._field_badge.sync(inst.model)
		inst._place_field_badge()
		for i: int in 3:
			await get_tree().process_frame
	if opt.has("fx"):
		var sp: SpirlingSprite = inst._sprite(BattleModel.Side.FOE, 0)
		var fx: EraMoveFx = EraMoveFx.spawn(inst._shake_root, str(opt.fx), era, Rect2(sp.position, sp.size))
		if fx != null:
			fx.hold(0.5)
		for i: int in 3:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/era%d_%s_%s.png" % [out, era, terrain, tag])
	print("saved era%d %s %s %s" % [era, terrain, tag, _rects(inst)])
	inst.queue_free()
	Juice.calm()
	await get_tree().process_frame

## Sprite rects of both ranks, for the log next to the picture.
func _rects(inst: BattleScene) -> String:
	if not inst._multi:
		return ""
	var parts: PackedStringArray = []
	for side: int in 2:
		for sp: SpirlingSprite in inst._slot_sprites[side]:
			parts.append("%d:%s" % [side, Rect2(sp.position, sp.size)])
	return " ".join(parts)
