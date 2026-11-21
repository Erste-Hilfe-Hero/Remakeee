extends GutTest
## Battle era feel, slice 4 (docs/ERA_FEEL_BATTLE.md): formation ranks that never collide, wind
## over the field, and the per-era move effects (send-out, hit mark, lunge, stat arrows, motes).

const SIDES: Array[int] = [BattleModel.Side.PLAYER, BattleModel.Side.FOE]
## Tag heights as MiniStrip gives them: foes without numbers, the player's side with them.
const FOE_TAG: float = 6.0
const PLAYER_TAG: float = 14.0
## Field heights while the command menu is open (measured in tools/era_battle_shots.gd).
const MENU_FIELD: Dictionary = {1: Vector2(144, 110), 2: Vector2(144, 110), 3: Vector2(180, 174), 4: Vector2(270, 316), 5: Vector2(270, 316)}

var _keep: Array[int] = []
var _settings: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)
	Juice.in_battle = false

func _era(e: int) -> void:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = e

## A small wild battle; the hidden Spark values come from a fixed seed, so two calls build the
## same Spirlings.
func _model() -> BattleModel:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return BattleModel.new([Spirling.new(Database.species("Kindlop"), 5, rng)] as Array[Spirling], [Spirling.new(Database.species("Zippit"), 5, rng)] as Array[Spirling], true, 1)

## The battle scene inside a host of the era's screen size (the stage needs a real size to draw).
func _scene(m: BattleModel) -> BattleScene:
	var host := Control.new()
	host.size = Vector2(270, 480)
	add_child_autofree(host)
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	host.add_child(scene)
	return scene

## A slot with its tag under it (the tag is MiniStrip.WIDTH wide and starts 1 px left).
func _with_tag(r: Rect2, tag_h: float) -> Array[Rect2]:
	return [r, Rect2(r.position + Vector2(-1, r.size.y + 2), Vector2(MiniStrip.WIDTH, tag_h))]

# --- Formation ranks ------------------------------------------------------------------

func test_ranks_never_collide_with_the_menu_open() -> void:
	for e: int in range(1, 6):
		var field: Vector2 = MENU_FIELD[e]
		for nf: int in range(1, 5):
			for np: int in range(1, 5):
				var foes: Array[Rect2] = BattleScene.formation_slots(e, BattleModel.Side.FOE, nf, field, FOE_TAG, np, PLAYER_TAG)
				var mine: Array[Rect2] = BattleScene.formation_slots(e, BattleModel.Side.PLAYER, np, field, PLAYER_TAG, nf, FOE_TAG)
				var what: String = "era %d %dv%d" % [e, np, nf]
				var boxes: Array[Rect2] = []
				for r: Rect2 in foes:
					boxes.append_array(_with_tag(r, FOE_TAG))
				var own: Array[Rect2] = []
				for r: Rect2 in mine:
					own.append_array(_with_tag(r, PLAYER_TAG))
				for a: Rect2 in boxes:
					assert_gte(a.position.x, 0.0, what + " foe inside")
					assert_lte(a.end.x, field.x, what + " foe inside")
					for b: Rect2 in own:
						assert_false(a.intersects(b), "%s: %s meets %s" % [what, a, b])
				for b: Rect2 in own:
					assert_gte(b.position.x, 0.0, what + " own inside")
					assert_lte(b.end.y, field.y, what + " own inside")
				assert_eq(foes[0].size, mine[0].size, what + ": both ranks the same size")
				assert_gte(foes[0].size.x, float(BattleScene.SLOT_MIN), what)

func test_tags_of_one_rank_never_overlap() -> void:
	for e: int in range(1, 6):
		for n: int in range(2, 5):
			var r: Array[Rect2] = BattleScene.formation_slots(e, BattleModel.Side.FOE, n, MENU_FIELD[e], FOE_TAG, 3, PLAYER_TAG)
			for i: int in range(1, n):
				assert_gte(r[i].position.x - r[i - 1].position.x, float(MiniStrip.WIDTH), "era %d n %d" % [e, n])

func test_era_sizes_stay_where_there_is_room() -> void:
	# The sizes of slice 3 (28/28/32/40/44) hold whenever the field has the room.
	for e: int in range(3, 6):
		var fit: Dictionary = BattleScene.formation_fit(e, 3, 3, MENU_FIELD[e], FOE_TAG, PLAYER_TAG)
		assert_eq(float(fit.px), EraBattleFeel.num(e, "formation_slot"), "era %d" % e)
		assert_eq(float(fit.foe_top), float(BattleScene.MARGIN + BattleScene.FOE_RANK_TOP))
	for e: int in [1, 2]:
		# A double battle stands side by side at full size even on the short field.
		assert_eq(float(BattleScene.formation_fit(e, 2, 2, MENU_FIELD[e], FOE_TAG, PLAYER_TAG).px), 28.0)
		# Six Spirlings do not fit at 28 px there: they shrink and the foe rank moves up.
		var tight: Dictionary = BattleScene.formation_fit(e, 3, 3, MENU_FIELD[e], FOE_TAG, PLAYER_TAG)
		assert_lt(float(tight.px), 28.0)
		assert_lt(float(tight.foe_top), float(BattleScene.MARGIN + BattleScene.FOE_RANK_TOP))
		# With the menu closed the field is tall enough again.
		assert_eq(float(BattleScene.formation_fit(e, 3, 3, Vector2(144, 200), FOE_TAG, PLAYER_TAG).px), 28.0)
	# Without the other side the old call still answers as before.
	var old: Array[Rect2] = BattleScene.formation_slots(1, BattleModel.Side.FOE, 3, Vector2(144, 110), 14.0)
	assert_eq(old[0].size.x, 28.0)
	assert_eq(old[0].position.y, float(BattleScene.MARGIN + BattleScene.FOE_RANK_TOP))

func test_stage_foes_stand_on_the_floor() -> void:
	for e: int in [4, 5]:
		var field: Vector2 = MENU_FIELD[e]
		var cfg: Dictionary = EraManager.stage_config()
		var horizon: float = Era4Stage.depth_y(cfg, 0.0, field.y)
		var foes: Array[Rect2] = BattleScene.formation_slots(e, BattleModel.Side.FOE, 3, field, FOE_TAG, 3, PLAYER_TAG)
		var mine: Array[Rect2] = BattleScene.formation_slots(e, BattleModel.Side.PLAYER, 3, field, PLAYER_TAG, 3, FOE_TAG)
		assert_lt(foes[0].end.y, horizon, "era %d: without the drop the foes hang over the horizon" % e)
		var feet: float = Era4Stage.sprite_rect(cfg, "foe", field, foes[0].size.x).end.y
		var top: float = mine[1].position.y
		var down: Array[Rect2] = BattleScene.drop_to_floor(foes, feet, top - FOE_TAG - 6)
		assert_eq(down.size(), 3)
		for i: int in 3:
			assert_gt(down[i].end.y, horizon, "era %d: feet on the floor" % e)
			assert_lt(down[i].end.y + 2 + FOE_TAG, top, "era %d: clear of the own rank" % e)
			assert_eq(down[i].position.x, foes[i].position.x)
		assert_eq(down[0].position.y - down[1].position.y, foes[0].position.y - foes[1].position.y, "the stagger stays")
	# Never upward, and never into the own rank.
	var one: Array[Rect2] = [Rect2(10, 100, 40, 40)]
	assert_eq(BattleScene.drop_to_floor(one, 90.0, 300.0)[0].position.y, 100.0)
	assert_eq(BattleScene.drop_to_floor(one, 400.0, 180.0)[0].end.y, 180.0)

func test_formation_scene_lays_out_on_the_stage() -> void:
	_era(5)
	GameState.battle_speed = 0
	var m := BattleModel.new(BattleScene._demo_team(RandomNumberGenerator.new(), ["Kindlop", "Puddlet", "Mossling"], 9), BattleScene._demo_team(RandomNumberGenerator.new(), ["Zippit", "Shalebat", "Kelpup"], 9), false, 3, 1)
	m.front_size = [3, 3]
	m.set_meta("quick", true)
	var scene: BattleScene = _scene(m)
	await wait_physics_frames(4)
	assert_true(scene._multi)
	assert_eq(scene._slot_sprites[BattleModel.Side.FOE].size(), 3)
	var horizon: float = Era4Stage.depth_y(EraManager.stage_config(), 0.0, scene._field.size.y)
	for sp: SpirlingSprite in scene._slot_sprites[BattleModel.Side.FOE]:
		assert_gt(sp.position.y + sp.size.y, horizon, "foes stand on the stage floor")
		for own: SpirlingSprite in scene._slot_sprites[BattleModel.Side.PLAYER]:
			assert_false(Rect2(sp.position, sp.size).intersects(Rect2(own.position, own.size)))

# --- Wind -----------------------------------------------------------------------------

func test_wind_is_a_look_and_lays_no_field() -> void:
	var m: BattleModel = _model()
	assert_eq(BattleWeather.weather_of(m), "")
	m.set_meta(BattleWeather.SKY_META, "wind")
	assert_eq(BattleWeather.weather_of(m), "wind")
	assert_eq(m.field, "", "wind lays no field")
	assert_eq(m.field_intro, "", "and adds no line")
	assert_true(WeatherCycle.battle_field("wind").is_empty(), "the rule of #465 stands")
	m.field = "high_tide"
	assert_eq(BattleWeather.weather_of(m), "", "a Rift field shows nothing extra")
	m.field_intro = str(WeatherCycle.battle_field("rain").intro)
	assert_eq(BattleWeather.weather_of(m), "rain", "a sky field wins over the wind mark")
	assert_eq(BattleWeather.weather_of(null), "")

func test_wind_changes_no_battle_result() -> void:
	var logs: Array[String] = []
	for windy: bool in [false, true]:
		var m: BattleModel = _model()
		if windy:
			m.set_meta(BattleWeather.SKY_META, "wind")
		var lines: PackedStringArray = []
		for ev: BattleEvent in m.start():
			lines.append(ev.describe())
		for turn: int in 4:
			if m.is_finished():
				break
			for ev: BattleEvent in m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0)):
				lines.append("%d %s %s" % [ev.type, ev.describe(), ev.data.get("hp", "")])
		logs.append("\n".join(lines))
	assert_eq(logs[0], logs[1], "the same seed plays the same battle with and without wind")

func test_wind_grows_with_the_era() -> void:
	assert_gt(BattleWeather.wind_lines(1), 0, "even the ink screen shows wind")
	assert_eq(BattleWeather.wind_leaves(1), 0, "but no leaves yet")
	for e: int in range(2, 6):
		assert_gt(BattleWeather.wind_lines(e), BattleWeather.wind_lines(e - 1))
		assert_gt(BattleWeather.wind_leaves(e), BattleWeather.wind_leaves(e - 1))
		assert_gt(EraBattleFeel.num(e, "wind_len"), EraBattleFeel.num(e - 1, "wind_len"))
		assert_gt(EraBattleFeel.num(e, "wind_speed"), EraBattleFeel.num(e - 1, "wind_speed"))
		for k: String in ["wind_wave", "wind_dust", "wind_gust"]:
			assert_true(EraBattleFeel.flag(e, k) or not EraBattleFeel.flag(e - 1, k), "%s era %d" % [k, e])
	assert_false(EraBattleFeel.flag(4, "wind_gust"))
	assert_true(EraBattleFeel.flag(5, "wind_gust"), "gusts are Era V's")
	assert_eq(BattleWeather.drop_count("wind", 5), 0, "wind is not rain")
	assert_eq(BattleWeather.flash_every("wind", 5), 0.0, "and never flashes")

func test_wind_parts_stay_on_the_field_and_blow_one_way() -> void:
	for e: int in range(1, 6):
		var field: Vector2 = MENU_FIELD[e]
		for part: String in ["line", "leaf", "dust"]:
			for i: int in 24:
				for t: float in [0.0, 0.7, 3.1, 9.9, 61.0]:
					var p: Vector2 = BattleWeather.wind_pos(part, i, e, t, field)
					assert_between(p.x, 0.0, field.x, "era %d %s" % [e, part])
					assert_between(p.y, 0.0, field.y - 1.0, "era %d %s" % [e, part])
					assert_eq(p, p.round(), "whole pixels")
		var last: float = -1.0
		for k: int in 80:
			var go: float = BattleWeather.wind_travel(e, k * 0.1)
			assert_gt(go, last, "era %d: the wind never turns back" % e)
			last = go
	assert_eq(int(BattleWeather.wind_pos("line", 3, 1, 1.3, MENU_FIELD[1]).x) % 2, 0, "Era I moves in 2 px steps")

func test_wind_shows_and_stands_still_under_reduced_motion() -> void:
	GameState.battle_speed = 0
	for e: int in range(1, 6):
		var host := Control.new()
		host.size = MENU_FIELD[e]
		add_child_autofree(host)
		var wx := BattleWeather.new()
		host.add_child(wx)
		wx.setup("wind", e)
		assert_true(wx.visible, "era %d shows wind" % e)
		wx._process(2.0)
		assert_eq(wx._time, 2.0)
		GameState.reduce_motion = true
		wx._process(1.0)
		assert_eq(wx._time, 2.0, "still under reduced motion")
		assert_true(wx.visible, "but still shown")
		assert_eq(wx._flash, 0.0)
		GameState.reduce_motion = false

func test_overworld_marks_a_windy_sky() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_true(src.contains("model.set_meta(BattleWeather.SKY_META, \"wind\")"), "the overworld hands the windy sky to the battle")

# --- Move effects per era -------------------------------------------------------------

func test_move_fx_config_is_complete() -> void:
	var c: Dictionary = EraBattleFeel.cfg()
	for e: int in range(1, 6):
		assert_has(c.sendout_styles, EraBattleFeel.text(e, "sendout"), "era %d" % e)
		assert_has(c.hit_mark_styles, EraBattleFeel.text(e, "hit_mark"), "era %d" % e)
		assert_has(c.lunge_styles, EraBattleFeel.lunge_style(e), "era %d" % e)
		for k: String in ["stat_arrows", "faint_motes", "fx_steps", "lunge_stretch"]:
			assert_true(EraBattleFeel.for_era(e).has(k), "era %d %s" % [e, k])
	for s: String in c.sendout_styles:
		assert_gt(int(c.move_fx.sendout_parts[s]), 0, s)
	for s: String in c.hit_mark_styles:
		assert_gt(int(c.move_fx.hit_mark_parts[s]), 0, s)
	for k: String in EraMoveFx.KINDS:
		assert_gt(float(c.move_fx[("stat" if k.begins_with("stat_") else k) + "_time"]), 0.0, k)
		assert_lte(float(c.move_fx[("stat" if k.begins_with("stat_") else k) + "_time"]), 0.8, k + " stays short")

func test_move_fx_grow_with_the_era() -> void:
	for e: int in range(2, 6):
		for pair: Array in [["sendout", "sendout_styles"], ["hit_mark", "hit_mark_styles"], ["lunge", "lunge_styles"]]:
			assert_gte(EraBattleFeel.rank(pair[1], EraBattleFeel.text(e, pair[0])), EraBattleFeel.rank(pair[1], EraBattleFeel.text(e - 1, pair[0])), "%s era %d" % [pair[0], e])
		for k: String in ["stat_arrows", "faint_motes", "lunge_stretch"]:
			assert_gte(EraBattleFeel.num(e, k), EraBattleFeel.num(e - 1, k), "%s era %d" % [k, e])
		for kind: String in ["sendout", "hitmark"]:
			assert_gte(int(EraMoveFx.spec(kind, e).count), int(EraMoveFx.spec(kind, e - 1).count), "%s era %d" % [kind, e])
	# Each of the five eras has its own send-out and its own hit mark.
	for key: String in ["sendout", "hit_mark"]:
		var seen: Dictionary = {}
		for e: int in range(1, 6):
			seen[EraBattleFeel.text(e, key)] = true
		assert_eq(seen.size(), 5, key)
	# Era I: a stat change is text only, a faint leaves nothing behind.
	assert_true(EraMoveFx.spec("stat_up", 1).is_empty())
	assert_true(EraMoveFx.spec("faint_motes", 1).is_empty())
	assert_true(EraMoveFx.spec("faint_motes", 2).is_empty())
	assert_false(EraMoveFx.spec("faint_motes", 3).is_empty())
	assert_true(EraMoveFx.spec("nonsense", 5).is_empty())

func test_old_eras_play_in_hard_steps() -> void:
	assert_eq(int(EraMoveFx.spec("sendout", 1).steps), 3)
	assert_eq(int(EraMoveFx.spec("sendout", 2).steps), 4)
	for e: int in range(3, 6):
		assert_eq(int(EraMoveFx.spec("sendout", e).steps), 0, "era %d moves smoothly" % e)
	assert_eq(EraMoveFx.quant(0.0, 3), 1.0 / 3.0, "the first step shows at once")
	assert_eq(EraMoveFx.quant(0.34, 3), 2.0 / 3.0)
	assert_eq(EraMoveFx.quant(0.99, 3), 1.0)
	assert_eq(EraMoveFx.quant(1.0, 3), 1.0)
	assert_eq(EraMoveFx.quant(0.37, 0), 0.37)
	assert_eq(EraMoveFx.quant(7.0, 0), 1.0)

func test_lunge_per_era() -> void:
	assert_eq(EraBattleFeel.lunge_style(1), "step")
	assert_eq(EraBattleFeel.lunge_style(2), "step")
	assert_eq(EraBattleFeel.lunge_style(3), "tween")
	assert_eq(EraBattleFeel.lunge_style(4), "stretch")
	for e: int in [1, 2, 3]:
		assert_eq(EraBattleFeel.lunge_scale(e), Vector2.ONE, "era %d does not stretch" % e)
	for e: int in [4, 5]:
		var s: Vector2 = EraBattleFeel.lunge_scale(e)
		assert_gt(s.x, 1.0)
		assert_lt(s.y, 1.0)
		assert_lte(s.x, 1.2, "a stretch, not a smear")

func test_lunge_returns_home_in_every_era() -> void:
	GameState.battle_speed = 0
	for e: int in range(1, 6):
		_era(e)
		var sp := SpirlingSprite.new()
		sp.position = Vector2(40, 40)
		sp.size = Vector2(28, 28)
		add_child_autofree(sp)
		sp.setup(Spirling.new(Database.species("Kindlop"), 5), "back")
		await sp.lunge(Vector2(-8, -4))
		assert_eq(sp.position, Vector2(40, 40), "era %d" % e)
		assert_eq(sp.draw_scale, Vector2.ONE, "era %d" % e)
	GameState.reduce_motion = true
	_era(1)
	var still := SpirlingSprite.new()
	still.position = Vector2(40, 40)
	add_child_autofree(still)
	still.setup(Spirling.new(Database.species("Kindlop"), 5), "back")
	await still.lunge(Vector2(-8, -4))
	assert_eq(still.position, Vector2(40, 40))

func test_move_fx_parts_stay_near_the_spirling() -> void:
	for e: int in range(1, 6):
		var px: float = EraBattleFeel.num(e, "formation_slot")
		var size := Vector2(px, px)
		for kind: String in EraMoveFx.KINDS:
			var s: Dictionary = EraMoveFx.spec(kind, e)
			if s.is_empty():
				continue
			var box: Rect2 = Rect2(Vector2.ZERO, size).grow(EraMoveFx.reach(kind, size) * 2.0 + 2.0)
			for q: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var pts: PackedVector2Array = EraMoveFx.points(kind, int(s.count), q, size)
				assert_eq(pts.size(), int(s.count))
				for p: Vector2 in pts:
					assert_true(box.has_point(p), "era %d %s at %.2f: %s outside %s" % [e, kind, q, p, box])
					assert_eq(p, p.round())
	# Arrows of a raised stat climb, those of a lowered stat sink.
	var up0: Vector2 = EraMoveFx.points("stat_up", 2, 0.1, Vector2(40, 40))[0]
	var up1: Vector2 = EraMoveFx.points("stat_up", 2, 0.4, Vector2(40, 40))[0]
	assert_lt(up1.y, up0.y)
	var dn0: Vector2 = EraMoveFx.points("stat_down", 2, 0.1, Vector2(40, 40))[0]
	var dn1: Vector2 = EraMoveFx.points("stat_down", 2, 0.4, Vector2(40, 40))[0]
	assert_gt(dn1.y, dn0.y)

func test_move_fx_under_reduced_motion() -> void:
	for e: int in range(1, 6):
		for kind: String in ["sendout", "hitmark", "faint_motes"]:
			assert_true(EraMoveFx.spec(kind, e, true).is_empty(), "era %d %s is off" % [e, kind])
	# A stat change is information: its arrows stay, standing still.
	var s: Dictionary = EraMoveFx.spec("stat_down", 4, true)
	assert_false(s.is_empty())
	assert_true(bool(s.still))
	assert_true(EraMoveFx.spec("stat_down", 1, true).is_empty(), "Era I stays text only")
	GameState.reduce_motion = true
	var host := Control.new()
	add_child_autofree(host)
	assert_null(EraMoveFx.spawn(host, "sendout", 5, Rect2(10, 10, 44, 44)))
	assert_null(EraMoveFx.spawn(host, "hitmark", 3, Rect2(10, 10, 44, 44)))
	var arrows: EraMoveFx = EraMoveFx.spawn(host, "stat_up", 5, Rect2(10, 10, 44, 44))
	assert_not_null(arrows)
	assert_true(bool(arrows.info.still))

func test_move_fx_spawns_draws_and_frees_itself() -> void:
	GameState.battle_speed = 0
	for e: int in range(1, 6):
		var host := Control.new()
		host.size = MENU_FIELD[e]
		add_child_autofree(host)
		for kind: String in EraMoveFx.KINDS:
			var fx: EraMoveFx = EraMoveFx.spawn(host, kind, e, Rect2(20, 20, 40, 40))
			if EraMoveFx.spec(kind, e).is_empty():
				assert_null(fx, "era %d %s" % [e, kind])
				continue
			assert_not_null(fx, "era %d %s" % [e, kind])
			assert_eq(fx.position, Vector2(20, 20))
			assert_eq(fx.mouse_filter, Control.MOUSE_FILTER_IGNORE, "never eats a tap")
			fx._process(0.05)
			assert_false(fx.is_queued_for_deletion())
			fx._process(5.0)
			assert_true(fx.is_queued_for_deletion(), "era %d %s ends by itself" % [e, kind])
	assert_null(EraMoveFx.spawn(null, "sendout", 5, Rect2()))

func test_battle_scene_plays_the_era_effects() -> void:
	_era(4)
	GameState.battle_speed = 0
	var m: BattleModel = _model()
	m.is_wild = false
	m.set_meta("quick", true)
	var scene: BattleScene = _scene(m)
	await wait_physics_frames(3)
	var before: int = _fx_count(scene)
	scene._era_fx("hitmark", BattleModel.Side.FOE, 0)
	scene._era_fx("stat_up", BattleModel.Side.PLAYER, 0)
	assert_eq(_fx_count(scene), before + 2)
	# The effects sit over the Spirling they belong to.
	var sp: SpirlingSprite = scene._sprite(BattleModel.Side.FOE, 0)
	for n: Node in scene._shake_root.get_children():
		if n is EraMoveFx and (n as EraMoveFx).kind == "hitmark":
			assert_eq((n as EraMoveFx).position, sp.position)
	_era(1)
	var ink: int = _fx_count(scene)
	scene._era_fx("stat_up", BattleModel.Side.PLAYER, 0)
	assert_eq(_fx_count(scene), ink, "Era I: a stat change stays text only")

func _fx_count(scene: BattleScene) -> int:
	var n: int = 0
	for c: Node in scene._shake_root.get_children():
		if c is EraMoveFx and not c.is_queued_for_deletion():
			n += 1
	return n
