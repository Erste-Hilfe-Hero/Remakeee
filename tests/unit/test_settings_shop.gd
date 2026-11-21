extends GutTest
## Settings sold in the shop (Ali, 7 Nov): Damage Preview, Minimap, Retro Filter,
## Sky Control (weather, day and night) and Bench Lessons.

var _state: Dictionary

func before_all() -> void:
	Database.load_all()

var _flags: Dictionary

func before_each() -> void:
	_state = Billing.state
	Billing.state = {"unlocks": {}}
	# After Act I: during Act I the Minimap is free (plan Chimora 100, item 39, test_c100_goal.gd).
	_flags = GameState.flags
	GameState.flags = {"mirela_lamp": true}

func after_each() -> void:
	Billing.state = _state
	GameState.flags = _flags

func test_every_sold_setting_has_a_ready_offer() -> void:
	for key: String in ShopEffects.SETTING_UNLOCKS:
		var unlock: String = ShopEffects.SETTING_UNLOCKS[key]
		var o: Dictionary = ShopCatalog.offer("rg_" + unlock)
		assert_false(o.is_empty(), key)
		assert_true(bool(o.get("ready", false)), key)
		assert_eq(str(o.grants[0].t), "unlock", key)
		assert_eq(str(o.grants[0].id), unlock, key)
		assert_false(ShopEffects.setting_offer_name(key).is_empty(), key)

func test_locked_until_bought() -> void:
	for key: String in ShopEffects.SETTING_UNLOCKS:
		assert_false(ShopEffects.owns_setting(key), key)
		assert_eq(MenuHost.shop_or(key, "On"), MenuHost.SHOP_MARK, key)
	assert_true(ShopEffects.owns_setting("tips"), "other settings stay free")
	assert_true(ShopEffects.owns_setting("large_text"), "access settings stay free")
	Billing.state = {"unlocks": {"sky_control": 1, "damage_preview": 1}}
	assert_true(ShopEffects.owns_setting("weather"))
	assert_true(ShopEffects.owns_setting("day_night"))
	assert_eq(MenuHost.shop_or("damage_preview", "On"), "On")
	assert_false(ShopEffects.owns_setting("minimap"))

## Chimora 100 item 34 (owner wish): fast text is free and its offer is no longer sold.
func test_fast_text_is_free() -> void:
	assert_true(ShopEffects.owns_setting("fast_text"))
	assert_eq(MenuHost.next_text_speed(GameState.TextSpeed.NORMAL), GameState.TextSpeed.FAST)
	assert_eq(MenuHost.next_text_speed(GameState.TextSpeed.FAST), GameState.TextSpeed.SLOW)
	assert_false(bool(ShopCatalog.offer("rg_fast_text").get("ready", true)), "nobody can buy what is free")

func test_bench_lessons_need_the_unlock() -> void:
	var keep: bool = GameState.bench_xp
	GameState.bench_xp = true
	assert_eq(GameState.bench_share(), 0.0)
	Billing.state = {"unlocks": {"bench_lessons": 1}}
	assert_eq(GameState.bench_share(), GameState.BENCH_XP_SHARE)
	GameState.bench_xp = keep
