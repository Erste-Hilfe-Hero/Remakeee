extends GutTest
## Plan area 6, second part: particles, walking, transitions, buttons, list cursor, toasts.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	# An earlier online test can leave the tree paused (reconnect overlay); tweens would stall.
	get_tree().paused = false

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_particles_cap_and_die() -> void:
	var p := PixelParticles.new()
	add_child_autofree(p)
	p.emit(Vector2(10, 10), 100, {"vel": Vector2(3.3, -7.1), "life": 0.3, "gravity": 20.0})
	assert_eq(p.particles.size(), PixelParticles.MAX_PARTICLES)
	p.step(0.1)
	for q: Dictionary in p.particles:
		assert_ne(q.pos, Vector2(10, 10))
	p.step(0.25)
	assert_eq(p.particles.size(), 0)

func test_dust_is_three_short_pixels() -> void:
	var p := PixelParticles.new()
	add_child_autofree(p)
	p.dust(Vector2(8, 15), Vector2(-1, 0))
	assert_eq(p.particles.size(), 3)
	for q: Dictionary in p.particles:
		assert_almost_eq(float(q.max_life), 0.3, 0.001)
		assert_lt((q.vel as Vector2).x, 0.0 + 6.0)

func test_walkers_announce_steps_and_player_bobs() -> void:
	var w := GridWalker.new()
	add_child_autofree(w)
	watch_signals(w)
	w.step("right", true)
	assert_signal_emitted_with_parameters(w, "step_started", ["right", true])
	assert_almost_eq(Player.TURN_GRACE, 0.08, 0.001)
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_true(src.contains("player.bob = true"))

func test_map_edges_and_doors() -> void:
	var o := Overworld.new()
	o.map = MapData.load_map("brindlewick")
	assert_not_null(o.map)
	for w: Dictionary in o.map.warps:
		var c := Vector2i(int(w.x), int(w.y))
		var on_edge: bool = c.x == 0 or c.y == 0 or c.y == o.map.height - 1 or c.x == o.map.rows[c.y].length() - 1
		assert_eq(o.is_edge_cell(c), on_edge, str(c))
	assert_false(o.is_edge_cell(Vector2i(3, 3)))
	assert_true(o.is_edge_cell(Vector2i(0, 3)))
	o.free()

func test_pressed_buttons_sink_one_pixel() -> void:
	var t: Theme = UITheme.get_theme()
	var normal: StyleBox = t.get_stylebox("normal", "Button")
	var pressed: StyleBox = t.get_stylebox("pressed", "Button")
	assert_eq(pressed.content_margin_top - normal.content_margin_top, 1.0)
	assert_eq(normal.content_margin_bottom - pressed.content_margin_bottom, 1.0)

func test_list_rows_pop_on_release() -> void:
	var lp := ListPicker.new()
	add_child_autofree(lp)
	var run := func() -> void: await lp.pick("T", [{"text": "A"}] as Array[Dictionary])
	run.call()
	await get_tree().process_frame
	assert_true(lp.buttons()[0].has_meta("juice_press"))
	lp.picked.emit(-1)

func test_toasts_queue_and_count_coins() -> void:
	Toast.shown.clear()
	Toast.show_text("Game saved.")
	Toast.coins(10, 40)
	assert_true(Toast.busy())
	var t: float = 0.0
	while Toast.busy() and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert_false(Toast.busy())
	assert_eq(Toast.shown.size(), 2)
	assert_eq(Toast.shown[1], "Coins: 40")
	var l := Label.new()
	add_child_autofree(l)
	await Juice.count_to(l, 0, 25, 0.1)
	assert_eq(l.text, "25")

func test_spotting_pops_the_alert() -> void:
	var n := NPC.new()
	add_child_autofree(n)
	n.alert = true
	assert_true(n._alert_pop)
	await get_tree().create_timer(0.1).timeout
	assert_false(n._alert_pop)
	GameState.reduce_motion = true
	n.alert = false
	n.alert = true
	assert_false(n._alert_pop)
