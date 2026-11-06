extends GutTest
## Plan area 6: the reconnect screen fades in and out in 0.2 s and dims the game only to
## 60 % (item 2291).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	get_tree().paused = false
	GameState.settings_from_dict(_saved)

## The tree is paused under the big screen, so step its fade by hand.
func _step(o: ReconnectOverlay, t: float) -> void:
	var tw: Variant = Juice._running.get("%d:modulate:a" % o._root.get_instance_id())
	if tw is Tween:
		(tw as Tween).custom_step(t)

func test_dims_to_sixty_percent() -> void:
	assert_almost_eq(ReconnectOverlay.DIM_ALPHA, 0.4, 0.001)
	var o := ReconnectOverlay.new()
	add_child_autofree(o)
	var dim: ColorRect = o._root.get_child(0)
	assert_almost_eq(dim.color.a, 0.4, 0.001)

func test_fades_in_and_out() -> void:
	var o := ReconnectOverlay.new()
	add_child_autofree(o)
	o.show_overlay()
	o.update_view(2, 3.0, ReconnectOverlay.SHORT_DROP)
	assert_true(o.is_big())
	assert_eq(o._root.modulate.a, 0.0, "starts clear")
	_step(o, ReconnectOverlay.FADE_TIME + 0.01)
	assert_almost_eq(o._root.modulate.a, 1.0, 0.01)
	o.hide_overlay()
	assert_false(get_tree().paused, "the game runs again at once")
	assert_true(o.visible, "still fading out")
	await wait_seconds(ReconnectOverlay.FADE_TIME + 0.15)
	assert_false(o.visible)

func test_lost_again_while_fading_out_stays() -> void:
	var o := ReconnectOverlay.new()
	add_child_autofree(o)
	o.show_overlay()
	o.update_view(2, 3.0, ReconnectOverlay.SHORT_DROP)
	_step(o, ReconnectOverlay.FADE_TIME + 0.01)
	o.hide_overlay()
	await wait_process_frames(2)
	o.show_overlay()
	o.update_view(3, 3.0, ReconnectOverlay.SHORT_DROP)
	_step(o, ReconnectOverlay.FADE_TIME + 0.01)
	get_tree().paused = false
	await wait_seconds(ReconnectOverlay.FADE_TIME + 0.15)
	assert_true(o.visible)
	assert_true(o.is_big())
	assert_almost_eq(o._root.modulate.a, 1.0, 0.01)
