extends GutTest
## Juice nudge, stagger, safe blink, wobble, element shake and helper cost (plan area 6,
## items 2235, 2237 to 2239, 2246, 2260, 2261).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.screen_shake = 2
	GameState.battle_speed = 0
	Juice.in_battle = false
	Juice.trauma = 0.0
	Juice.shake_element = -1
	get_tree().paused = false

func after_each() -> void:
	Juice.set_shake_root(null)
	Juice.shake_element = -1
	GameState.settings_from_dict(_saved)

func _ctrl() -> Control:
	var n := Control.new()
	n.size = Vector2(16, 16)
	n.position = Vector2(10, 20)
	add_child_autofree(n)
	return n

func test_nudge_pushes_and_springs_back() -> void:
	var n: Control = _ctrl()
	var peak: Array[float] = [0.0]
	var done: Array[bool] = [false]
	var run := func() -> void:
		await Juice.nudge(n, Vector2.RIGHT, 9)
		done[0] = true
	run.call()
	var t: float = 0.0
	while not done[0] and t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		peak[0] = maxf(peak[0], n.position.x - 10.0)
	assert_true(done[0])
	assert_lte(peak[0], 3.0, "never more than 3 px")
	assert_gt(peak[0], 0.0, "moved at all")
	assert_eq(n.position, Vector2(10, 20), "back home")
	assert_lt(t, 0.25, "about 0.1 s in all")
	GameState.reduce_motion = true
	await Juice.nudge(n, Vector2.UP, 2)
	assert_eq(n.position, Vector2(10, 20))

func test_stagger_fades_in_one_after_another() -> void:
	var nodes: Array = [_ctrl(), _ctrl(), _ctrl(), _ctrl()]
	var run := Juice.stagger.bind(nodes)
	run.call()
	await get_tree().process_frame
	assert_gt(nodes[0].modulate.a, nodes[3].modulate.a - 0.001)
	assert_eq(nodes[3].modulate.a, 0.0, "last still hidden")
	await wait_seconds(Juice.STAGGER_GAP * 3 + Juice.STAGGER_FADE + 0.1)
	for n: Control in nodes:
		assert_almost_eq(n.modulate.a, 1.0, 0.001)
	GameState.reduce_motion = true
	nodes[1].modulate.a = 0.0
	await Juice.stagger(nodes)
	assert_eq(nodes[1].modulate.a, 1.0, "reduced: all at once")

func test_blink_safe_never_too_fast_or_dark() -> void:
	var n: Control = _ctrl()
	var tw: Tween = Juice.blink_safe(n, 0.05)
	assert_true(tw.is_valid())
	var lowest: float = 1.0
	var dips: int = 0
	var was_low: bool = false
	var t: float = 0.0
	while t < 1.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		lowest = minf(lowest, n.modulate.r)
		var low: bool = n.modulate.r < 0.8
		if low and not was_low:
			dips += 1
		was_low = low
	assert_gte(lowest, Juice.BLINK_LOW - 0.01, "never darker than 60 %")
	assert_lte(dips, 3, "at most 3 times a second")
	assert_gte(dips, 1)
	Juice.stop_blink(n)
	assert_false(tw.is_valid())
	assert_eq(n.modulate, Color.WHITE)

func test_wobble_stays_within_four_degrees_and_rests() -> void:
	var n: Control = _ctrl()
	var widest: Array[float] = [0.0]
	var done: Array[bool] = [false]
	var run := func() -> void:
		await Juice.wobble(n, 30.0, 0.2)
		done[0] = true
	run.call()
	while not done[0]:
		await get_tree().process_frame
		widest[0] = maxf(widest[0], absf(rad_to_deg(n.rotation)))
	assert_lte(widest[0], 4.01)
	assert_gt(widest[0], 1.0)
	assert_eq(n.rotation, 0.0)
	assert_eq(n.pivot_offset, Vector2(8, 8))

func test_element_shake_directions() -> void:
	var E := Elements.E
	assert_eq(Juice.shake_shape(E.STONE), Vector3(0, 1, 1))
	assert_eq(Juice.shake_shape(E.GALE), Vector3(1, 0, 1))
	assert_eq(Juice.shake_shape(E.VOLT), Vector3(0.5, 0.5, 2))
	assert_eq(Juice.shake_shape(E.EMBER), Vector3(1, 1, 1))
	Juice.add_trauma(0.5, E.STONE)
	assert_eq(Juice.shake_element, E.STONE)
	var moved_y: bool = false
	for i: int in 100:
		var o: Vector2 = Juice.shake_offset(1.0, i * 0.017)
		assert_eq(o.x, 0.0, "stone never shakes sideways")
		moved_y = moved_y or o.y != 0.0
	assert_true(moved_y)
	Juice.shake_element = E.GALE
	for i: int in 100:
		assert_eq(Juice.shake_offset(1.0, i * 0.017).y, 0.0, "gale never shakes up and down")

func test_shake_rolls_instead_of_flickering() -> void:
	# Read once per frame at 60 fps, smooth noise changes by at most a pixel between frames,
	# where per-frame random numbers jump across the whole range. Both axes, normal speed
	# (an earlier battle may have left Volt's double speed set).
	Juice.shake_element = -1
	# Juice seeds its noise at random; a fixed seed keeps the count the same on every run
	# (over 200 seeds it lies between 5 and 22, per-frame random gives about 80).
	var seed_was: int = Juice._noise.seed
	Juice._noise.seed = 2261
	var jumps: int = 0
	var prev: Vector2 = Juice.shake_offset(1.0, 0.0)
	for i: int in range(1, 240):
		var o: Vector2 = Juice.shake_offset(1.0, i / 60.0)
		if absf(o.x - prev.x) > 2.0:
			jumps += 1
		prev = o
	Juice._noise.seed = seed_was
	assert_lt(jumps, 20, "few full swings from frame to frame (per-frame random gives about 80)")
	# At most 30 different offsets a second.
	var changes: int = 0
	prev = Juice.shake_offset(1.0, 0.0)
	for i: int in range(1, 60):
		var o: Vector2 = Juice.shake_offset(1.0, i / 60.0)
		if o != prev:
			changes += 1
		prev = o
	assert_lte(changes, 30)

func test_shake_clears_element_when_done() -> void:
	var root := Control.new()
	add_child_autofree(root)
	Juice.set_shake_root(root)
	Juice.add_trauma(0.2, Elements.E.GALE)
	while Juice.trauma > 0.0:
		await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Juice.shake_element, -1)
	assert_eq(root.position, Vector2.ZERO)

## 50 tweens running at once cost under 0.3 ms per frame (item 2246). The tweens are stepped
## by hand so only the helper work is timed.
func test_fifty_tweens_stay_cheap() -> void:
	var tweens: Array[Tween] = []
	for i: int in 50:
		var n: Control = _ctrl()
		var tw: Tween = Juice.tween(n, "position", Vector2(100 + i, 40), "move", 1.0)
		tw.pause()
		tweens.append(tw)
	var frames: int = 30
	var start: int = Time.get_ticks_usec()
	for f: int in frames:
		for tw: Tween in tweens:
			tw.custom_step(1.0 / 60.0)
	var per_frame_ms: float = (Time.get_ticks_usec() - start) / 1000.0 / frames
	gut.p("50 Juice tweens: %.3f ms per frame" % per_frame_ms)
	assert_lt(per_frame_ms, 0.3)
