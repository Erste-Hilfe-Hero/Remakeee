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

# --- 141 ---

func test_weekend_doubles_growth_by_config() -> void:
	assert_eq(GrowthRules.num("weekend_mult", 1.0), 2.0, "data/growth_rules.json")
	assert_eq(GrowthRules.weekend_mult(6), 2.0, "Saturday")
	assert_eq(GrowthRules.weekend_mult(0), 2.0, "Sunday")
	for wd: int in [1, 2, 3, 4, 5]:
		assert_eq(GrowthRules.weekend_mult(wd), 1.0, "weekday %d" % wd)

func test_weekend_note_on_friday_and_the_weekend_only() -> void:
	assert_string_contains(GrowthRules.weekend_line(5), "Saturday and Sunday")
	assert_string_contains(GrowthRules.weekend_line(6), "today")
	assert_string_contains(GrowthRules.weekend_line(0), "today")
	for wd: int in [1, 2, 3, 4]:
		assert_eq(GrowthRules.weekend_line(wd), "")

func test_weekend_off_when_config_is_one() -> void:
	var keep: Variant = GrowthRules.data().get("weekend_mult")
	GrowthRules._data["weekend_mult"] = 1.0
	assert_eq(GrowthRules.weekend_mult(6), 1.0)
	assert_eq(GrowthRules.weekend_line(5), "")
	GrowthRules._data["weekend_mult"] = keep

func test_weekend_is_applied_to_battle_growth() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	assert_string_contains(src, "model.xp_mult *= GrowthRules.weekend_mult(GrowthRules.local_weekday())")

# --- 147 ---

func test_birthday_gift_after_one_year_once() -> void:
	GameState.start_day = 1000
	GameState.birthdays_paid = 0
	assert_eq(SaveBirthday.pending(1364), 0)
	assert_eq(SaveBirthday.claim(1364).size(), 0)
	assert_eq(SaveBirthday.pending(1365), 1)
	var money: int = GameState.money
	var charms: int = GameState.item_count(SaveBirthday.GIFT_ITEM)
	var lines: Array[String] = SaveBirthday.claim(1365)
	assert_eq(lines.size(), 1)
	assert_eq(GameState.money, money + SaveBirthday.GIFT_COINS)
	assert_eq(GameState.item_count(SaveBirthday.GIFT_ITEM), charms + SaveBirthday.GIFT_COUNT)
	assert_eq(SaveBirthday.pending(1500), 0, "paid once")
	assert_eq(SaveBirthday.pending(1730), 1, "second birthday")
	assert_string_contains(SaveBirthday.claim(1730)[0], "2 years")
	GameState.add_item(SaveBirthday.GIFT_ITEM, -2 * SaveBirthday.GIFT_COUNT)

func test_birthday_waits_in_goals() -> void:
	GameState.start_day = GameState.today() - SaveBirthday.YEAR_DAYS
	GameState.birthdays_paid = 0
	var before: int = Goals.pending()
	assert_gt(before, 0)
	assert_true(Goals.collect_all().size() > 0)
	assert_eq(GameState.birthdays_paid, 1)
	assert_eq(SaveBirthday.pending(), 0)
	GameState.add_item(SaveBirthday.GIFT_ITEM, -SaveBirthday.GIFT_COUNT)

func test_start_day_round_trip_and_old_saves() -> void:
	GameState.start_day = 4321
	GameState.birthdays_paid = 2
	var d: Dictionary = GameState.to_dict()
	GameState.start_day = 0
	GameState.birthdays_paid = 0
	GameState.from_dict(d)
	assert_eq(GameState.start_day, 4321)
	assert_eq(GameState.birthdays_paid, 2)
	d.erase("start_day")
	GameState.from_dict(d)
	assert_gt(GameState.start_day, 0, "older saves get a start day")
	assert_lte(GameState.start_day, GameState.today())

func test_no_birthday_without_start_day() -> void:
	GameState.start_day = 0
	assert_eq(SaveBirthday.pending(99999), 0)

# --- 180 ---

func test_starter_pack_once_and_first_seven_days() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_starter")
	assert_eq(int(o.limit.n), 1, "once per account")
	assert_eq(ShopCatalog.save_days(o), 7)
	assert_eq(int(o.eur_cents), 299, "price unchanged")
	assert_eq(str(o.product_id), "de.chimora.game.consumable.starter")
	GameState.start_day = 500
	assert_true(ShopCatalog.in_save_window(o, 500))
	assert_true(ShopCatalog.in_save_window(o, 506))
	assert_false(ShopCatalog.in_save_window(o, 507))
	assert_true(ShopCatalog.in_save_window(ShopCatalog.offer("rg_coins_5000"), 9999), "other offers stay")

func test_starter_pack_leaves_the_tab_and_cannot_be_bought_late() -> void:
	var o: Dictionary = ShopCatalog.offer("rg_starter")
	GameState.start_day = GameState.today() - 30
	assert_false(ShopCatalog.in_tab(str(o.tab)).has(o))
	var keep: Dictionary = Billing.state
	Billing.state = {"open": true, "band": 18, "bought": {}, "rifts": 3}
	assert_eq(Billing.block_reason(o, false), "not_available")
	GameState.start_day = GameState.today()
	assert_true(ShopCatalog.in_tab(str(o.tab)).has(o))
	assert_ne(Billing.block_reason(o, false), "not_available")
	Billing.state = keep
