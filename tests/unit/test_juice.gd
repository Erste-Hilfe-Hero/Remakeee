extends GutTest
## Juice (curves, pop, shake, hit-stop) and Haptics, plan area 6.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.screen_shake = 2
	GameState.vibration = 2
	GameState.battle_speed = 0
	Juice.in_battle = false
	Juice.trauma = 0.0
	# An earlier online test can leave the tree paused (reconnect overlay); tweens would stall.
	get_tree().paused = false

func after_each() -> void:
	Juice.set_shake_root(null)
	Juice.in_battle = false
	Engine.time_scale = 1.0
	GameState.settings_from_dict(_saved)

func test_curves_exist_with_sane_durations() -> void:
	for c: String in ["open", "close", "move", "impact", "settle"]:
		assert_true(Juice.CURVES.has(c), c)
		var t: float = Juice.duration(c)
		assert_between(t, 0.05, 0.6, c)
	assert_almost_eq(Juice.duration("open"), 0.18, 0.001)
	assert_eq(int(Juice.CURVES["settle"].trans), Tween.TRANS_ELASTIC)

func test_reduced_motion_caps_every_tween() -> void:
	GameState.reduce_motion = true
	assert_true(Juice.reduced())
	for c: String in Juice.CURVES:
		assert_lte(Juice.duration(c), Juice.REDUCED_MAX_TIME, c)
	var n := Control.new()
	add_child_autofree(n)
	var tw: Tween = Juice.tween(n, "position", Vector2(10, 0), "settle", 0.5)
	assert_true(tw.is_valid())
	await tw.finished
	assert_eq(n.position, Vector2(10, 0))

func test_battle_speed_divides_durations_only_in_battle() -> void:
	GameState.battle_speed = 2
	assert_almost_eq(Juice.duration("move"), 0.22, 0.001)
	Juice.in_battle = true
	assert_almost_eq(Juice.speed(), 4.0, 0.001)
	assert_almost_eq(Juice.duration("move"), 0.055, 0.001)

func test_position_tweens_land_on_whole_pixels() -> void:
	var n := Control.new()
	add_child_autofree(n)
	var tw: Tween = Juice.tween(n, "position", Vector2(7, 3), "move")
	var seen_fraction: bool = false
	while tw.is_running():
		await get_tree().process_frame
		if n.position != n.position.round():
			seen_fraction = true
	assert_false(seen_fraction, "position stayed on whole pixels")
	assert_eq(n.position, Vector2(7, 3))

func test_new_tween_replaces_old_on_same_property() -> void:
	var n := Control.new()
	add_child_autofree(n)
	var first: Tween = Juice.tween(n, "position", Vector2(20, 0), "move")
	var second: Tween = Juice.tween(n, "position", Vector2(0, 5), "move")
	assert_false(first.is_valid(), "old tween killed")
	await second.finished
	assert_eq(n.position, Vector2(0, 5))

func test_pop_returns_to_scale_one() -> void:
	var n := Control.new()
	n.size = Vector2(10, 10)
	add_child_autofree(n)
	await Juice.pop(n)
	assert_almost_eq(n.scale.x, 1.0, 0.001)
	assert_eq(n.pivot_offset, Vector2(5, 5))

func test_shake_offset_is_whole_and_within_limits() -> void:
	for i: int in 200:
		var o: Vector2 = Juice.shake_offset(1.0)
		assert_eq(o, o.round())
		assert_lte(absf(o.x), 3.0)
		assert_lte(absf(o.y), 2.0)
	assert_eq(Juice.shake_offset(0.0), Vector2.ZERO)
	GameState.screen_shake = 1
	for i: int in 50:
		assert_lte(absf(Juice.shake_offset(1.0).x), 2.0)

func test_shake_root_returns_exactly_home() -> void:
	var root := Control.new()
	root.position = Vector2(4, 6)
	add_child_autofree(root)
	Juice.set_shake_root(root)
	Juice.add_trauma(Juice.TRAUMA_WARDEN)
	assert_almost_eq(Juice.trauma, 0.55, 0.001)
	var t: float = 0.0
	while Juice.trauma > 0.0 and t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_eq(Juice.trauma, 0.0)
	assert_eq(root.position, Vector2(4, 6))

func test_trauma_is_capped_and_off_when_disabled() -> void:
	for i: int in 10:
		Juice.add_trauma(Juice.TRAUMA_HIT_STRONG)
	assert_eq(Juice.trauma, 1.0)
	Juice.trauma = 0.0
	GameState.screen_shake = 0
	Juice.add_trauma(0.5)
	assert_eq(Juice.trauma, 0.0)
	GameState.screen_shake = 2
	GameState.reduce_motion = true
	Juice.add_trauma(0.5)
	assert_eq(Juice.trauma, 0.0)

func test_hitstop_times() -> void:
	assert_almost_eq(Juice.hitstop_time(0.0), 0.04, 0.001)
	assert_almost_eq(Juice.hitstop_time(0.5), 0.07, 0.001)
	assert_almost_eq(Juice.hitstop_time(1.0), 0.10, 0.001)
	assert_almost_eq(Juice.hitstop_time(3.0), 0.10, 0.001)
	Juice.in_battle = true
	GameState.battle_speed = 2
	assert_lte(Juice.hitstop_time(1.0), 0.04)

func test_hitstop_restores_time_scale() -> void:
	var p: Signal = _run_hitstop()
	await get_tree().process_frame
	assert_almost_eq(Engine.time_scale, Juice.HITSTOP_TIME_SCALE, 0.001)
	await p
	assert_eq(Engine.time_scale, 1.0)
	GameState.reduce_motion = true
	await Juice.hitstop(1.0)
	assert_eq(Engine.time_scale, 1.0)

signal _done
func _run_hitstop() -> Signal:
	(func() -> void:
		await Juice.hitstop(1.0)
		_done.emit()).call_deferred()
	return _done

func test_settings_round_trip_and_legacy_rumble() -> void:
	GameState.screen_shake = 1
	GameState.vibration = 0
	var d: Dictionary = GameState.settings_to_dict()
	GameState.screen_shake = 2
	GameState.vibration = 2
	GameState.settings_from_dict(d)
	assert_eq(GameState.screen_shake, 1)
	assert_eq(GameState.vibration, 0)
	GameState.settings_from_dict({"rumble": false})
	assert_eq(GameState.vibration, 0)
	GameState.settings_from_dict({"rumble": true})
	assert_eq(GameState.vibration, 2)
	assert_eq(GameState.screen_shake, 2)

func test_haptic_patterns() -> void:
	for p: String in ["tap", "confirm", "hit", "heavy", "error"]:
		assert_true(Haptics.PATTERNS.has(p), p)
	Haptics.sent.clear()
	Haptics.play("hit")
	assert_eq(Haptics.sent.back(), [25, 0.7])
	GameState.vibration = 1
	Haptics.play("heavy")
	assert_eq(Haptics.sent.back(), [45, 0.5])
	await Haptics.play("error")
	assert_eq(Haptics.sent.size(), 4)
	Haptics.sent.clear()
	GameState.vibration = 0
	Haptics.play("heavy")
	GameState.vibration = 2
	GameState.reduce_motion = true
	Haptics.play("heavy")
	assert_true(Haptics.sent.is_empty())

func test_android_exports_ask_for_vibrate() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var android: int = 0
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options") or str(cfg.get_value(sec, "platform", "")) != "Android":
			continue
		android += 1
		assert_true(bool(cfg.get_value(sec + ".options", "permissions/vibrate", false)), sec)
	assert_eq(android, 2)

func test_no_direct_reduce_motion_reads_outside_juice() -> void:
	for path: String in ["res://scripts/battle/presenter/SpirlingSprite.gd", "res://scripts/overworld/Overworld.gd", "res://scripts/core/EraManager.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("GameState.reduce_motion"), path)

func test_battle_sprites_sit_in_shake_root() -> void:
	var b := BattleScene.new()
	b._build()
	var root: Node = b.find_child("shake_root", true, false)
	assert_not_null(root)
	var sprites: int = 0
	for c: Node in root.get_children():
		if c is SpirlingSprite:
			sprites += 1
		assert_false(c is InfoStrip, "strips stay still")
	assert_eq(sprites, 2)
	# The menu's hold timer only joins the tree in _ready.
	b._menu._hold.free()
	b.free()
	assert_eq(BattleScene.knockback_dir(BattleModel.Side.PLAYER, false), Vector2(2, 1))
	assert_eq(BattleScene.knockback_dir(BattleModel.Side.FOE, true), Vector2(0, -1))
