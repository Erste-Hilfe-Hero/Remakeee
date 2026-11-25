extends GutTest
## Chimora 200 list: settings reset per section (126), night mode (127), weekend boost (141),
## journey birthday gift (147) and the Starter Pack's first-days window (180).

var _settings: Dictionary
var _keep: Dictionary

func before_each() -> void:
	_settings = GameState.settings_to_dict()
	_keep = {"start": GameState.get("start_day"), "paid": GameState.get("birthdays_paid"), "money": GameState.money,
		"retro": EraManager.retro_filter}

func after_each() -> void:
	GameState.settings_from_dict(_settings)
	GameState.set("start_day", _keep.start)
	GameState.set("birthdays_paid", _keep.paid)
	GameState.money = int(_keep.money)
	EraManager.set_retro_filter(int(_keep.retro))

# --- 126 ---

func test_reset_sets_one_section_back_and_keeps_the_others() -> void:
	GameState.text_speed = GameState.TextSpeed.FAST
	GameState.tips_enabled = false
	GameState.volume = 0.3
	GameState.left_handed = true
	assert_true(SettingsReset.reset("game"))
	assert_eq(GameState.text_speed, GameState.TextSpeed.NORMAL)
	assert_true(GameState.tips_enabled)
	assert_almost_eq(GameState.volume, 0.3, 0.001, "sound untouched")
	assert_true(GameState.left_handed, "controls untouched")
	assert_true(SettingsReset.reset("sound"))
	assert_almost_eq(GameState.volume, 0.8, 0.001)
	assert_true(SettingsReset.reset("controls"))
	assert_false(GameState.left_handed)
	assert_false(SettingsReset.reset("nope"))

func test_display_reset_keeps_the_language() -> void:
	GameState.language = "de"
	GameState.high_contrast = true
	SettingsReset.reset("display")
	assert_false(GameState.high_contrast)
	assert_eq(GameState.language, "de")

func test_every_section_has_a_reset_row() -> void:
	for rows: Array in [MenuHost.settings_rows("game"), MenuHost.settings_rows("sound"), MenuHost.controls_rows(), MenuHost.display_rows()]:
		var last: Array = rows[rows.size() - 1]
		assert_true(str(last[0]).begins_with("reset_"), str(last[0]))
		assert_eq(str(last[1]), SettingsReset.ROW_TEXT)
		assert_true(MenuHost.SETTING_HINTS.has(str(last[0])))
		assert_true(SettingsReset.GROUP_KEYS.has(str(last[0]).trim_prefix("reset_")))

func test_reset_keys_are_real_settings() -> void:
	var d: Dictionary = GameState.settings_to_dict()
	for g: String in SettingsReset.GROUP_KEYS:
		for k: Variant in SettingsReset.GROUP_KEYS[g]:
			assert_true(d.has(k), "%s in %s" % [k, g])

# --- 127 ---

func test_night_mode_is_saved_and_shows_a_tint_over_everything() -> void:
	GameState.night_mode = 1
	var d: Dictionary = GameState.settings_to_dict()
	GameState.night_mode = 0
	GameState.settings_from_dict(d)
	assert_eq(GameState.night_mode, 1)
	var layer: CanvasLayer = GameState._night_layer
	assert_not_null(layer)
	assert_true(layer.visible)
	assert_eq(layer.layer, GameState.NIGHT_LAYER)
	var rect: ColorRect = layer.get_child(0)
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "taps go through")
	assert_eq(rect.color, GameState.NIGHT_TINTS[1])
	GameState.night_mode = 0
	GameState.apply_display()
	assert_false(layer.visible)

func test_night_mode_row_and_bad_value() -> void:
	var keys: Array = MenuHost.display_rows().map(func(r: Array) -> String: return str(r[0]))
	assert_has(keys, "night_mode")
	GameState.settings_from_dict({"night_mode": 9})
	assert_eq(GameState.night_mode, GameState.NIGHT_MODE_NAMES.size() - 1)

func test_display_reset_turns_night_mode_off() -> void:
	GameState.night_mode = 2
	SettingsReset.reset("display")
	assert_eq(GameState.night_mode, 0)
