extends GutTest
## Plan area 6 (item 2291), as of docs/OFFLINE.md: the offline mark fades in and out in 0.2 s.
## It never dims or pauses the game, in a battle or outside one.

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	get_tree().paused = false
	Online.in_battle = false
	GameState.settings_from_dict(_saved)

func test_never_dims_the_game() -> void:
	var o := OfflineMark.new()
	add_child_autofree(o)
	o.update_view(OfflineMark.SHOW_AFTER + 60.0)
	for c: Node in o.get_children():
		assert_false(c is ColorRect, "no dimming layer")
	assert_lte(o.mark.size.x * o.mark.size.y, 16.0 * 12.0, "only the small mark")
	assert_false(get_tree().paused)

func test_fades_in_and_out() -> void:
	var o := OfflineMark.new()
	add_child_autofree(o)
	o.update_view(OfflineMark.SHOW_AFTER)
	assert_true(o.is_shown())
	assert_eq(o.mark.modulate.a, 0.0, "starts clear")
	await wait_seconds(OfflineMark.FADE_TIME + 0.15)
	assert_almost_eq(o.mark.modulate.a, OfflineMark.MARK_ALPHA, 0.01)
	o.hide_mark()
	assert_true(o.visible, "still fading out")
	await wait_seconds(OfflineMark.FADE_TIME + 0.15)
	assert_false(o.visible)

func test_lost_again_while_fading_out_stays() -> void:
	var o := OfflineMark.new()
	add_child_autofree(o)
	o.update_view(OfflineMark.SHOW_AFTER)
	await wait_seconds(OfflineMark.FADE_TIME + 0.1)
	o.hide_mark()
	await wait_process_frames(2)
	o.update_view(OfflineMark.SHOW_AFTER)
	await wait_seconds(OfflineMark.FADE_TIME + 0.15)
	assert_true(o.visible)
	assert_true(o.is_shown())
	assert_almost_eq(o.mark.modulate.a, OfflineMark.MARK_ALPHA, 0.01)

func test_a_running_battle_and_the_world_both_go_on() -> void:
	# KAMPF_PLAN_1000 (Online-Kämpfe) and docs/OFFLINE.md: a lost connection stops nothing.
	var o := OfflineMark.new()
	add_child_autofree(o)
	Online.in_battle = true
	o.update_view(OfflineMark.SHOW_AFTER + 10.0)
	assert_false(get_tree().paused, "the battle keeps running")
	Online.in_battle = false
	o.update_view(OfflineMark.SHOW_AFTER + 600.0)
	assert_false(get_tree().paused, "after the battle the world keeps running too")
	assert_true(o.is_shown())
