extends GutTest
## Plan area 6: the Rift opening shakes the camera offset (item 2262), photos never carry a
## shake (item 2269), and the Wayfarer's small hop after a battle (item 2292).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.screen_shake = 2
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	Juice.set_shake_root(null)
	GameState.settings_from_dict(_saved)

func test_camera_root_shakes_offset_not_position() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(100, 50)
	add_child_autofree(cam)
	Juice.set_shake_root(cam, "offset")
	var moved: bool = false
	# The noise phase decides when the pixel peaks fall; try a few starts.
	for start: int in 10:
		Juice._shake_time = start * 0.7
		Juice.add_trauma(Overworld.RIFT_TRAUMA)
		assert_almost_eq(Juice.trauma, Overworld.RIFT_TRAUMA, 0.001)
		for i: int in 30:
			Juice._process(1.0 / 60.0)
			if cam.offset != Vector2.ZERO:
				moved = true
		assert_eq(cam.offset, Vector2.ZERO, "back to rest when the trauma is gone")
	assert_eq(cam.position, Vector2(100, 50), "the camera keeps following")
	assert_true(moved, "the offset shakes")

func test_calm_stops_the_shake_at_once() -> void:
	var cam := Camera2D.new()
	add_child_autofree(cam)
	Juice.set_shake_root(cam, "offset")
	Juice.add_trauma(1.0)
	for i: int in 5:
		Juice._process(1.0 / 60.0)
	Juice.calm()
	assert_eq(Juice.trauma, 0.0)
	assert_eq(cam.offset, Vector2.ZERO)

func test_rumble_sound_exists_with_caption() -> void:
	assert_true(ResourceLoader.exists(Sound.SFX_DIR % "rumble"))
	assert_true(Sound.CAPTIONS.has("rumble"))

func test_greet_hop_is_drawn_only() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2i(2, 2), "down")
	p.frozen = true
	var pos: Vector2 = p.position
	p.greet()
	assert_eq(p.jolt, Vector2(0, -1))
	assert_eq(p.position, pos)
	await wait_seconds(GridWalker.GREET_TIME + 0.1)
	assert_eq(p.jolt, Vector2.ZERO)

func test_no_greet_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var p := Player.new()
	add_child_autofree(p)
	p.greet()
	assert_eq(p.jolt, Vector2.ZERO)

func test_small_trauma_still_shows_a_pixel() -> void:
	var widest: float = 0.0
	for i: int in 200:
		var o: Vector2 = Juice.shake_offset(Overworld.RIFT_TRAUMA, i * 0.013)
		widest = maxf(widest, maxf(absf(o.x), absf(o.y)))
	assert_eq(widest, 1.0, "a Rift shakes by one pixel")
	assert_eq(Juice._whole_px(0.12), 0.0, "a normal hit alone stays still")
	assert_eq(Juice._whole_px(-0.3), -1.0)
	assert_eq(Juice._whole_px(2.9), 3.0)
	assert_eq(Juice._whole_px(1.4), 1.0, "past one pixel it rounds")
