extends Node
## The work of tools/era_hud_shots.gd, run as a node so the autoloads exist.

const SCALE: int = 2
var out: String = "user://era_hud_shots"
## 0 = every era, else only this one.
var only: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Database.load_all()
	var em: Node = get_tree().root.get_node("/root/EraManager")
	em.set("unlocked_era", 5)
	Loc.set_language("en")
	GameState.battle_speed = 2
	GameState.tips_enabled = false
	for era: int in range(1, 6):
		if only > 0 and era != only:
			continue
		em.call("set_retro_filter", era)
		EraBattleHud.last_item = "tonic"
		await _state(era, "menu")
		await _state(era, "info")
		await _state(era, "status")
		await _state(era, "team")
		await _state(era, "level")
		await _state(era, "bond")
		await _state(era, "mine")
		await _state(era, "duel3")
		await _state(era, "aim")
		Loc.set_language("de")
		await _state(era, "menu_de")
		await _state(era, "status_de")
		Loc.set_language("en")
	get_tree().quit()

func _team(names: Array[String], level: int) -> Array[Spirling]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var team: Array[Spirling] = []
	for n: String in names:
		team.append(Spirling.new(Database.species(n), level, rng))
	return team

## A Wayfarer battle with a team on both sides, so the team rows show.
func _duel() -> BattleModel:
	var m := BattleModel.new(_team(["Kindlop", "Puddlet", "Mossling", "Zephlet"], 14), _team(["Smoldrake", "Shalebat", "Kelpup"], 14), false, 11, 1)
	m.trainer_name = "Hauler Tobin"
	m.inventory = {"tonic": 3, "remedy": 1}
	return m

func _state(era: int, tag: String) -> void:
	var inst: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	inst.backdrop = "field"
	var kind: String = tag.trim_suffix("_de")
	if kind == "duel3" or kind == "aim":
		inst.demo = "duel3"
	elif kind == "status" or kind == "team" or kind == "level":
		var m: BattleModel = _duel()
		m.set_meta("quick", true)
		inst.setup(m)
	else:
		var m: BattleModel = inst._demo_model()
		m.set_meta("quick", true)
		inst.setup(m)
	get_tree().root.add_child(inst)
	# Play on until the commands are up.
	for i: int in 900:
		await get_tree().process_frame
		if inst._menu._content.visible:
			break
	var me: Spirling = inst.model.active_spirling(BattleModel.Side.PLAYER)
	var foe: Spirling = inst.model.active_spirling(BattleModel.Side.FOE)
	match kind:
		"info":
			inst._menu.open_info(0)
		"status", "team", "level":
			me.hp = maxi(me.max_hp() / 5, 1)
			me.status = "scorch"
			me.stages = {"atk": 2, "spd": -1} as Dictionary[String, int]
			me.energy_tax = 2
			me.energy = 6
			me.xp = Spirling.xp_for_level(me.level) + (Spirling.xp_for_level(me.level + 1) - Spirling.xp_for_level(me.level)) * 2 / 3
			foe.hp = foe.max_hp() / 2
			foe.status = "jolt"
			foe.stages = {"def": -2} as Dictionary[String, int]
			foe.gleam = true
			GameState.spirlog[foe.data.species_name] = {"seen": true, "bonded": true}
			var mine: Array = inst.model.party(BattleModel.Side.PLAYER)
			(mine[1] as Spirling).hp = 0
			(mine[2] as Spirling).status = "chill"
			(inst.model.party(BattleModel.Side.FOE)[1] as Spirling).hp = 1
			inst._player_strip.set_spirling(me)
			inst._foe_strip.set_spirling(foe)
			inst._hud.refresh_teams()
			inst._menu.refresh(inst.model, 0)
			if kind == "team":
				inst._pick_party("Swap to?", true, 0)
			elif kind == "level":
				inst._menu.set_enabled(false)
				inst._hud.show_level(BattleEvent.new(BattleEvent.Type.LEVEL_UP, {"index": 0, "level": me.level}))
				inst._text.show_prompt("%s grew ring %d!" % [me.display_name(), me.level])
		"bond", "mine":
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			inst._bond_game.rng = rng
			inst._bond_game.target = inst._foe_sprite.texture()
			inst._bond_game.target_name = foe.display_name()
			if kind == "mine":
				inst._bond_game.run_mine(BondEcho.make_plan(rng, foe.data, ""))
				for i: int in 7:
					inst._bond_game.mine_tap()
			else:
				inst._bond_game.run(BondEcho.make_plan(rng, foe.data, ""))
		"aim":
			inst._pick_target("Aim at?")
	for i: int in (70 if kind == "level" or kind == "bond" else 24):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png("%s/era%d_%s.png" % [out, era, tag])
	print("saved era%d %s" % [era, tag])
	inst.queue_free()
	await get_tree().process_frame
