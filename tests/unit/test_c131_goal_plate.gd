extends GutTest
## Update 1.3.1 (iPhone Duo): the battle's "Turn N" stands on a light plate as wide as its
## words, so dark hills behind a short field never hide it, and a long goal still stops at
## its place in the HUD (the label clips there).

func before_all() -> void:
	Database.load_all()

var _settings: Dictionary

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.reduce_motion = true

func after_each() -> void:
	GameState.settings_from_dict(_settings)

func _settled_scene() -> BattleScene:
	var m: BattleModel = load("res://tools/era_battle_shots_runner.gd").formation_model([1, 1])
	var host := Control.new()
	host.size = Vector2(192, 256)
	add_child_autofree(host)
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	host.add_child(scene)
	await wait_process_frames(3)
	for i: int in 1800:
		if scene._menu != null and scene._menu._content != null and scene._menu._content.visible:
			break
		scene._text.advance_now()
		await wait_process_frames(1)
	return scene

func test_turn_count_has_a_plate_as_wide_as_its_words() -> void:
	var scene: BattleScene = await _settled_scene()
	var l: Label = scene._goal_label
	assert_true(l.visible, "a trainer battle shows the turn count")
	assert_true(l.has_theme_stylebox_override("normal"), "the turn count stands on a plate")
	var f: Font = l.get_theme_font("font")
	var text_w: float = f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	assert_lte(l.size.x, ceilf(text_w) + 2.0, "plate %s no wider than the words %s" % [l.size.x, text_w])
	assert_gte(l.size.x, text_w, "the whole turn count shows")

func test_a_long_goal_stays_inside_its_place() -> void:
	var scene: BattleScene = await _settled_scene()
	var l: Label = scene._goal_label
	l.text = "Win before the third turn with a Volt reaction and keep everyone standing"
	scene.fit_goal_label()
	assert_gt(scene._hud.goal_w, 0.0, "the layout gave the goal a place")
	assert_lte(l.size.x, scene._hud.goal_w, "a long goal clips at its place")
