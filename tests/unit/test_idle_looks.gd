extends GutTest
## Idle glances and the turn pause when talked to (plan area 6, items 2307, 2308, 2310).

func _npc(def: Dictionary) -> NPC:
	var n := NPC.new()
	n.setup(def.merged({"id": "fisher", "x": 2, "y": 2, "facing": "down"}))
	add_child_autofree(n)
	return n

func test_player_looks_around_after_eight_seconds() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2i(1, 1), "up")
	p._idle(Player.IDLE_LOOK_AFTER - 0.1, false)
	assert_eq(p.look, "", "not yet")
	p._idle(0.2, false)
	assert_eq(p.look, "left")
	p._idle(Player.IDLE_LOOK_EVERY, false)
	assert_eq(p.look, "right")
	assert_eq(p.facing, "up", "only the drawing turns")
	assert_eq(p.facing_cell(), Vector2i(1, 0), "interaction still uses facing")
	p._idle(0.0, true)
	assert_eq(p.look, "")
	assert_eq(p.idle_time, 0.0)

func test_step_and_face_clear_the_glance() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.look = "left"
	p.face("down")
	assert_eq(p.shown_facing(), "down")
	p.look = "right"
	p.step("up")
	assert_eq(p.look, "")

func test_standing_villager_glances_but_keeps_facing() -> void:
	var n: NPC = _npc({})
	assert_true(n.may_glance())
	for i: int in 6:
		var before: String = n.shown_facing()
		n.glance()
		assert_ne(n.shown_facing(), before)
	assert_eq(n.facing, "down")
	n._glance_in = 0.01
	n.look = ""
	n._process(0.05)
	assert_ne(n.look, "", "glances on its own timer")
	assert_between(n._glance_in, NPC.GLANCE_MIN, NPC.GLANCE_MAX)

func test_wayfarers_walkers_and_still_ones_never_glance() -> void:
	assert_false(_npc({"trainer": "Wanderer Lio"}).may_glance())
	assert_false(_npc({"still": true}).may_glance())
	assert_false(_npc({"walk_cells": [Vector2i(2, 2), Vector2i(3, 2)]}).may_glance())

func test_turns_after_a_short_pause() -> void:
	var n: NPC = _npc({})
	n.look = "left"
	var done: Array[bool] = [false]
	var run := func() -> void:
		await n.turn_toward(Vector2i(2, 1))
		done[0] = true
	run.call()
	assert_eq(n.facing, "down", "still looking away at first")
	await wait_seconds(NPC.TURN_PAUSE + 0.05)
	assert_true(done[0])
	assert_eq(n.facing, "up")
	assert_eq(n.look, "")
	assert_gte(n._glance_in, NPC.GLANCE_AFTER_TALK - 0.2, "keeps facing the player for a while")
