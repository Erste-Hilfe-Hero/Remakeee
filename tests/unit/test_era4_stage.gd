extends GutTest
## Era IV render path (design plan 331-333): 2.5D stage maths and the EraManager hook.

var c: Dictionary
const SZ := Vector2(270, 330)

func before_each() -> void:
	c = EraManager.stage_config()

func test_config_loads() -> void:
	assert_false(c.is_empty())
	assert_eq((c["layers"] as Array).size(), 3, "3 parallax layers (item 332)")

func test_far_is_smaller_and_higher() -> void:
	assert_lt(Era4Stage.depth_scale(c, 0.2), Era4Stage.depth_scale(c, 0.9))
	assert_lt(Era4Stage.depth_y(c, 0.2, SZ.y), Era4Stage.depth_y(c, 0.9, SZ.y))

func test_floor_lines_meet_at_vanishing_point() -> void:
	var a: Vector2 = Era4Stage.project(c, -0.5, 0.0, SZ)
	var b: Vector2 = Era4Stage.project(c, 1.5, 0.0, SZ)
	assert_almost_eq(a.x, b.x, 0.01)

func test_slabs_are_flat_topped_trapezoids() -> void:
	for side: String in ["foe", "player"]:
		var q: PackedVector2Array = Era4Stage.slab_quad(c, side, SZ)
		assert_eq(q.size(), 4)
		assert_eq(q[0].y, q[1].y)
		assert_eq(q[2].y, q[3].y)
		assert_gt(q[2].x - q[3].x, q[1].x - q[0].x, "near edge wider")

func test_foe_sprite_far_and_smaller_than_player() -> void:
	var base: float = float(EraManager.BATTLE_SPRITE_SIZE[EraManager.Era.PANORAMA])
	var f: Rect2 = Era4Stage.sprite_rect(c, "foe", SZ, base)
	var p: Rect2 = Era4Stage.sprite_rect(c, "player", SZ, base)
	assert_lt(f.size.x, p.size.x)
	assert_lt(f.end.y, p.end.y)
	assert_eq(p.size.x, roundf(base * Era4Stage.depth_scale(c, 0.86)))

func test_stage_only_from_panorama() -> void:
	var keep: int = EraManager.retro_filter
	var unlocked: int = EraManager.unlocked_era
	EraManager.unlocked_era = EraManager.Era.PANORAMA
	EraManager.retro_filter = EraManager.Era.ETCHED
	assert_false(EraManager.uses_stage_25d())
	EraManager.retro_filter = EraManager.Era.PANORAMA
	assert_true(EraManager.uses_stage_25d())
	EraManager.retro_filter = keep
	EraManager.unlocked_era = unlocked
