extends GutTest
## Plan area 6: ring rise around a Spirling on level up (item 2333).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.battle_speed = 0
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_ring_pixels_sit_on_the_rim() -> void:
	for d: float in [8.0, 24.0, 40.0]:
		var px: Array[Vector2i] = LevelRing.ring_pixels(d)
		assert_gt(px.size(), 8)
		for p: Vector2i in px:
			assert_almost_eq(Vector2(p).length(), d / 2.0, 0.75, "d=%s" % d)

func test_ring_grows_and_fades_then_frees() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var ring: LevelRing = LevelRing.spawn(root, Vector2(50.4, 30.6))
	assert_not_null(ring)
	assert_eq(ring.position, Vector2(50, 31))
	assert_eq(ring.diameter, LevelRing.FROM_SIZE)
	var tw: Tween = ring.tween
	tw.custom_step(LevelRing.TIME / 2.0)
	assert_between(ring.diameter, LevelRing.FROM_SIZE + 1.0, LevelRing.TO_SIZE - 1.0)
	assert_lt(ring.modulate.a, 1.0)
	tw.custom_step(LevelRing.TIME)
	assert_almost_eq(ring.diameter, LevelRing.TO_SIZE, 0.01)
	await wait_process_frames(2)
	assert_false(is_instance_valid(ring), "frees itself")

func test_no_ring_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var root := Node2D.new()
	add_child_autofree(root)
	assert_null(LevelRing.spawn(root, Vector2.ZERO))
	assert_eq(root.get_child_count(), 0)
