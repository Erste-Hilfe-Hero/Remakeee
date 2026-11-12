extends GutTest
## Era V: animated battle sprite strips and the battle camera.

func _base() -> Image:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(2, 2, 4, 4), Color("6a4256"))
	return img

func test_gated_to_era_five() -> void:
	for e: int in [1, 2, 3, 4]:
		assert_false(BattleAnim.enabled_for(e))
	assert_true(BattleAnim.enabled_for(5))

func test_strip_has_one_frame_per_step() -> void:
	for k: String in BattleAnim.KINDS:
		var s: Image = BattleAnim.build_strip(_base(), k)
		assert_eq(s.get_width(), 8 * BattleAnim.frame_count(k), k)
		assert_eq(s.get_height(), 8, k)
		assert_gt(BattleAnim.frame_count(k), 2, k)

func test_idle_bobs_up() -> void:
	var s: Image = BattleAnim.build_strip(_base(), "idle")
	assert_eq(s.get_pixel(2, 2).a, 1.0)
	# Frame 2 is lifted 2 px: its top row moves from y 2 to y 0.
	assert_eq(s.get_pixel(16 + 2, 0).a, 1.0)
	assert_eq(s.get_pixel(16 + 2, 5).a, 0.0)

func test_attack_lunges_toward_minus_x() -> void:
	var s: Image = BattleAnim.build_strip(_base(), "attack")
	var dx: Array = BattleAnim.strip_cfg("attack").dx
	var peak: int = -1
	for i: int in dx.size():
		if peak < 0 and int(dx[i]) > 0 and int(dx[i]) < 4:
			peak = i
	assert_gt(peak, -1)
	# Shifted left by dx: the right edge column (x 5) is empty, x 5 - dx is filled.
	assert_eq(s.get_pixel(peak * 8 + 5 - int(dx[peak]), 3).a, 1.0)
	assert_eq(s.get_pixel(peak * 8 + 5, 3).a, 0.0)

func test_hit_flash_frames_are_silhouettes() -> void:
	var s: Image = BattleAnim.build_strip(_base(), "hit")
	var flash := Color(str(BattleAnim.config().flash_color))
	assert_true(s.get_pixel(3, 3).is_equal_approx(flash))
	assert_true(s.get_pixel(8 + 3, 3).is_equal_approx(Color("6a4256")))
	assert_eq(s.get_pixel(0, 0).a, 0.0, "background stays clear")

func test_frame_at_loops_or_holds() -> void:
	var n: int = BattleAnim.frame_count("idle")
	assert_eq(BattleAnim.frame_at("idle", n / BattleAnim.fps("idle")), 0)
	assert_eq(BattleAnim.frame_at("attack", 99.0), BattleAnim.frame_count("attack") - 1)

func test_camera_zooms_in_and_keeps_pivot_inside() -> void:
	var f: Dictionary = BattleCamera.focus(Vector2(144, 120), Rect2(0, 80, 40, 40), Rect2(104, 0, 40, 40))
	assert_gt(f.scale.x, 1.0)
	assert_eq(f.pivot, Vector2(72, 60))
	var g: Dictionary = BattleCamera.focus(Vector2(144, 120), Rect2(100, 80, 40, 40), Rect2(104, 70, 40, 40))
	assert_gt(g.pivot.x, 72.0, "pans toward the action")
	assert_lte(g.pivot.x, 144.0)

func test_unlock_line_has_german() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/de/era5.json"))
	assert_true(((d as Dictionary).get("strings", {}) as Dictionary).has(BattleAnim.UNLOCK_LINE))
