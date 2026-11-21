extends GutTest
## Chimora 100, items 67-73: less shop pressure early, free display settings, a "Tomorrow"
## line, early exchange offers and roaming trips in Act I.

var _state: Dictionary
var _lang: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_state = Billing.state
	_lang = Loc.language()
	Loc.set_language("en")
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Billing.state = _state
	Loc.set_language(_lang)

## Item 67: the Team title carries no shop note; the note lives in the shop's Advantages tab.
func test_team_title_has_no_shop_note() -> void:
	var team: String = FileAccess.get_file_as_string("res://scripts/ui/PauseMenu.gd")
	assert_false(team.contains("next_power_line"), "no shop line in the Team title")
	assert_true(FileAccess.get_file_as_string("res://scripts/shop/ShopMenu.gd").contains("ShopEffects.next_power_line()"))

## Item 68: Day and night, Weather and Retro filter are free; locked rows show no euro mark.
func test_display_settings_free_and_no_euro() -> void:
	Billing.state = {"unlocks": {}}
	for key: String in ["day_night", "weather", "retro"]:
		assert_true(ShopEffects.owns_setting(key), key)
		assert_false(key in ShopEffects.SETTING_UNLOCKS, key)
	for row: Array in MenuHost.display_rows():
		assert_false(str(row[1]).contains("€"), str(row[1]))
	assert_false(MenuHost.SHOP_MARK.contains("€"))
	# A refund check never switches the free settings back.
	GameState.day_night = false
	GameState.weather = false
	ShopEffects.apply_unlocks()
	assert_false(GameState.day_night)
	assert_false(GameState.weather)

## Item 68: who bought Sky Control or the Retro Filter keeps the unlock in the account.
func test_bought_unlocks_stay_owned() -> void:
	Billing.state = {"unlocks": {"sky_control": 1, "retro_filter": 1}}
	assert_eq(Billing.unlocked("sky_control"), 1)
	assert_eq(Billing.unlocked("retro_filter"), 1)

## Item 68 follow-up (owner wish, 2026-11-21): the two products only granted settings that are now
## free, so they are no longer sold (catalog v38, like rg_fast_text in v37). Buyers keep the unlock:
## the server's _shop_credit still credits a restored receipt of a not-ready offer.
func test_free_settings_products_no_longer_sold() -> void:
	for id: String in ["rg_sky_control", "rg_retro_filter"]:
		var o: Dictionary = ShopCatalog.offer(id)
		assert_false(o.is_empty(), id + " stays in the catalog for restore")
		assert_false(bool(o.get("ready", true)), id + ": nobody can buy what is free")
		assert_false(o in ShopCatalog.in_tab(str(o.tab)), id + " is not shown in the shop")
		Billing.state = {"open": true, "band": 18, "unlocks": {}}
		assert_eq(Billing.block_reason(o, true), "not_available", id)

## Item 69: no in-app purchase banner on the title art.
func test_no_title_banner() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/TitleScreen.gd")
	assert_false(src.contains("Loc.t(IAP_NOTE)"))
	assert_false(src.contains("_iap_note"))

## Item 70: the shop sits at the end of the menu until the first Rift is mended.
func test_shop_entry_quiet_before_first_rift() -> void:
	var labels: Array[String] = PauseMenu.menu_labels(false, false, false)
	PauseMenu.place_shop(labels, "Shop", false)
	assert_eq(labels.back(), "Shop", "still reachable, at the end")
	labels = PauseMenu.menu_labels(false, false, false)
	PauseMenu.place_shop(labels, "Shop", true)
	assert_eq(labels.find("Shop"), labels.find("Satchel") + 1, "after the Satchel once a Rift is mended")

## Item 71: the "Tomorrow" line names tomorrow's visitor place and the task count.
func test_tomorrow_line() -> void:
	var day: String = "2026-11-22"
	var line: String = DailyFind.tomorrow_line(day)
	assert_true(line.begins_with("Tomorrow: a rare visitor stirs in"), line)
	var p: Dictionary = DailyFind.pick(day)
	var where: String = MapData.load_map(str(p.table)).display_name if MapData.exists(str(p.table)) else str(p.table).capitalize()
	assert_string_contains(line, where)
	if DailyTasks.draw(day).size() > 0:
		assert_string_contains(line, "New daily tasks: %d" % DailyTasks.draw(day).size())
	assert_ne(DailyFind.tomorrow_key(), DailyFind.today_key())

## Item 72: two Waymark offers open with met_kestra, before the first Rift.
func test_exchange_open_after_kestra() -> void:
	assert_false(Exchange.is_open())
	GameState.set_flag("met_kestra")
	assert_eq(Exchange.offers().size(), 2)
	Waymarks.earn(30, "daily_task")
	assert_eq(Exchange.buy("remedy"), "", "Waymarks are spendable before the first Rift")
	assert_eq(Exchange.buy("spark_charm"), "Marla doesn't have that right now.")

## Item 73: Aldo offers roaming trips in Act I, once Kestra is met.
func test_roaming_in_act_one() -> void:
	var aldo: Dictionary = Dialogue.get_entry("lighthouse/aldo")
	assert_eq(Dialogue.choices_for(aldo, {}).size(), 0, "not in the first talk")
	var ch: Array[Dictionary] = Dialogue.choices_for(aldo, {"aldo_gift": true, "met_kestra": true})
	assert_eq(ch.size(), 2)
	assert_eq(str(ch[0].action), "expedition")
