extends GutTest
## Plan area 6: idle bob, low-strength sag (item 2335) and the dodge on a miss (item 2337).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.battle_speed = 0
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func _mon(share: float) -> Spirling:
	var s := Spirling.new(Database.species("Mossling"), 20)
	s.hp = int(round(s.max_hp() * share))
	return s

func test_healthy_bobs_once_a_second() -> void:
	var s := _mon(1.0)
	assert_eq(SpirlingSprite.idle_offset(s, 0.1, false), Vector2.ZERO)
	assert_eq(SpirlingSprite.idle_offset(s, 0.6, false), Vector2(0, -1))
	assert_eq(SpirlingSprite.idle_offset(s, 1.1, false), Vector2.ZERO)

func test_weak_sags_and_bobs_slower() -> void:
	var s := _mon(0.2)
	assert_true(SpirlingSprite.is_weak(s))
	assert_eq(SpirlingSprite.idle_offset(s, 0.6, false), Vector2(0, 1), "still down at 0.6 s")
	assert_eq(SpirlingSprite.idle_offset(s, 1.1, false), Vector2.ZERO, "up 1 px from its sagged spot")
	assert_eq(SpirlingSprite.idle_offset(s, 1.1, true), Vector2(0, 1), "reduced motion keeps only the sag")

func test_fainted_does_not_bob() -> void:
	var s := _mon(0.0)
	assert_false(SpirlingSprite.is_weak(s))
	assert_eq(SpirlingSprite.idle_offset(s, 0.6, false), Vector2.ZERO)

func test_bob_redraws_without_moving_the_node() -> void:
	var sp := SpirlingSprite.new()
	sp.size = Vector2(32, 32)
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	sp.setup(_mon(1.0), "front")
	sp._process(0.6)
	assert_eq(sp.draw_offset, Vector2(0, -1))
	assert_eq(sp.position, Vector2(40, 20))

func test_dodge_spot_is_4px_aside() -> void:
	assert_eq(SpirlingSprite.dodge_spot(Vector2(40, 20), 1.0), Vector2(44, 20))
	assert_eq(SpirlingSprite.dodge_spot(Vector2(40, 20), -1.0), Vector2(36, 20))
	assert_almost_eq(SpirlingSprite.DODGE_TIME, 0.2, 0.001)

func test_dodge_moves_and_comes_back() -> void:
	var sp := SpirlingSprite.new()
	sp.size = Vector2(32, 32)
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	sp.setup(_mon(1.0), "front")
	sp.dodge(BattleScene.dodge_dir(BattleModel.Side.FOE))
	var tw: Variant = Juice._running.get("%d:position" % sp.get_instance_id())
	assert_true(tw is Tween, "a position tween runs")
	if tw is Tween:
		(tw as Tween).custom_step(0.06)
		assert_gt(sp.position.x, 40.0, "foe steps right")
	await wait_seconds(0.4)
	assert_eq(sp.position, Vector2(40, 20))

func test_dodge_skipped_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var sp := SpirlingSprite.new()
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	await sp.dodge(1.0)
	assert_eq(sp.position, Vector2(40, 20))

func test_dodge_dirs_point_outward() -> void:
	assert_eq(BattleScene.dodge_dir(BattleModel.Side.FOE), 1.0)
	assert_eq(BattleScene.dodge_dir(BattleModel.Side.PLAYER), -1.0)
