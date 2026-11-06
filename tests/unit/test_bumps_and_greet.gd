extends GutTest
## Plan area 6: 1 px wall jolt of the figure (item 2263) and the hop of a newly bonded
## Spirling (item 2344).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.settings_to_dict()
	GameState.reduce_motion = false
	GameState.battle_speed = 0
	get_tree().paused = false
	Engine.time_scale = 1.0

func after_each() -> void:
	GameState.settings_from_dict(_saved)

func test_wall_jolts_the_drawing_once() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2i(3, 3), "left")
	p.frozen = true # no held keys here; letting go would reset the bumped wall
	var pos: Vector2 = p.position
	p.bump("left")
	assert_eq(p.jolt, Vector2(-1, 0))
	assert_eq(p.position, pos, "the node (and the camera) stays")
	await wait_seconds(Player.BUMP_TIME + 0.1)
	assert_eq(p.jolt, Vector2.ZERO)
	p.bump("left")
	assert_eq(p.jolt, Vector2.ZERO, "holding against the same wall jolts only once")
	p.bump("up")
	assert_eq(p.jolt, Vector2(0, -1), "a new wall jolts again")

func test_no_jolt_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var p := Player.new()
	add_child_autofree(p)
	p.place(Vector2i(3, 3), "left")
	p.bump("left")
	assert_eq(p.jolt, Vector2.ZERO)

func test_greet_hop_rises_and_lands() -> void:
	var sp := SpirlingSprite.new()
	sp.size = Vector2(32, 32)
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	sp.greet_hop()
	var tw: Variant = Juice._running.get("%d:position" % sp.get_instance_id())
	assert_true(tw is Tween)
	if tw is Tween:
		(tw as Tween).custom_step(SpirlingSprite.GREET_HOP_TIME * 0.45)
		assert_eq(sp.position, Vector2(40, 20 - SpirlingSprite.GREET_HOP_PX))
	await wait_seconds(0.4)
	assert_eq(sp.position, Vector2(40, 20))

func test_greet_hop_skipped_under_reduced_motion() -> void:
	GameState.reduce_motion = true
	var sp := SpirlingSprite.new()
	sp.position = Vector2(40, 20)
	add_child_autofree(sp)
	await sp.greet_hop()
	assert_eq(sp.position, Vector2(40, 20))
