extends GutTest
## "Mine!" shows the wild Spirling above the bar (owner, 28 Nov): the battle sprite, never over
## the bar, the hint or the button; a small pull toward the player, a hard stop when full, and a
## still sprite under reduced motion.

const PHONE := Vector2(144, 256)
const TALL := Vector2(144, 312)
const IPAD := Vector2(192, 256)
const PLAN: Dictionary = {"phases": [[0, 1, 2, 0]], "state": "none"}

var _keep: Array[int] = []
var _settings: Dictionary

func before_each() -> void:
	_keep = [EraManager.unlocked_era, EraManager.retro_filter]
	_settings = GameState.settings_to_dict()
	GameState.reduce_motion = false

func after_each() -> void:
	EraManager.unlocked_era = _keep[0]
	EraManager.retro_filter = _keep[1]
	GameState.settings_from_dict(_settings)

func _wild(gleam: bool = false) -> Spirling:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := Spirling.new(Database.species("Zephlet"), 5, rng)
	s.gleam = gleam
	return s

func _game(era: int, at: Vector2, wild: Spirling) -> BondMinigame:
	EraManager.unlocked_era = EraManager.NEWEST
	EraManager.retro_filter = era
	var g := BondMinigame.new()
	g.rng = RandomNumberGenerator.new()
	g.rng.seed = 7
	add_child_autofree(g)
	g.size = at
	g.run_mine(PLAN, wild)
	return g

func _sprite_box(g: BondMinigame) -> Rect2:
	return Rect2(g._mine_sprite.position, g._mine_sprite.size)

func test_sprite_drawn_above_the_bar_in_every_era_and_screen() -> void:
	for era: int in range(1, 6):
		for at: Vector2 in [PHONE, TALL, IPAD]:
			var g: BondMinigame = _game(era, at, _wild())
			await wait_process_frames(2)
			var tag: String = "era %d %s" % [era, at]
			assert_true(g._mine_sprite.is_visible_in_tree(), "sprite shown, " + tag)
			assert_not_null(g._mine_sprite.texture(), "the battle art, " + tag)
			var box: Rect2 = g.mine_sprite_rect()
			var bar: Rect2 = g.mine_bar_rect()
			assert_gt(box.size.x, 20.0, "big enough to read, " + tag)
			assert_lte(box.end.y + BondMinigame.MINE_PULL_PX, bar.position.y, "above the bar even when pulled, " + tag)
			assert_almost_eq(box.get_center().x, bar.get_center().x, 1.0, "centred over the bar, " + tag)
			assert_gte(box.position.y - BondMinigame.MINE_HOP_PX, g.hint_bottom(), "under the hint, " + tag)
			assert_false(box.grow_individual(0, BondMinigame.MINE_HOP_PX, 0, BondMinigame.MINE_PULL_PX).intersects(g.mine_button_rect()), "clear of the button, " + tag)
			g.queue_free()

func test_gleam_uses_the_field_palette() -> void:
	var g: BondMinigame = _game(2, PHONE, _wild(true))
	assert_not_null(g._mine_sprite.material, "Gleam palette like on the field")
	assert_true(g._mine_sprite.mirrored, "faces the player like on the field")

func test_pulled_toward_the_player_and_stops_hard_when_full() -> void:
	var g: BondMinigame = _game(1, PHONE, _wild())
	var home: Rect2 = g.mine_sprite_rect()
	g.mine_tap()
	g._process(0.01)
	assert_lt(g._mine_sprite.position.y, home.position.y + 1.0, "a tap hops it up")
	g._process(BondMinigame.MINE_HOP_TIME)
	for i: int in 17:
		g.mine_tap()
	assert_eq(g._phase, BondMinigame.Phase.RESULT)
	assert_eq(g._mine_sprite.position.y, home.position.y + BondMinigame.MINE_PULL_PX, "full pull, no hop")
	assert_false(g._mine_sprite.is_processing(), "stops dead when the bar is full")
	g._process(0.05)
	assert_eq(g._mine_sprite.position.y, home.position.y + BondMinigame.MINE_PULL_PX, "and stays")

func test_reduced_motion_keeps_it_still() -> void:
	GameState.reduce_motion = true
	var g: BondMinigame = _game(4, PHONE, _wild())
	var home: Vector2 = g.mine_sprite_rect().position
	for i: int in 9:
		g.mine_tap()
		g._process(0.01)
		assert_eq(g._mine_sprite.position, home, "no hop, no pull")
	for i: int in 9:
		g.mine_tap()
	assert_eq(g._mine_sprite.position, home)

func test_echo_call_and_old_callers_have_no_sprite() -> void:
	var g: BondMinigame = _game(1, PHONE, _wild())
	g.run(PLAN)
	assert_false(g._mine_sprite.visible, "the Echo call keeps its own picture")
	var plain := BondMinigame.new()
	add_child_autofree(plain)
	plain.run_mine(PLAN)
	assert_null(plain._mine_sprite, "no Spirling given, no sprite")
