extends GutTest
## Chimora 100, menu fixes (plan items 46-48, 51, 56, 60-62, 64; UI audit 2026-11-21 bugs 3, 5,
## 6, 9, 15, 19-21, 23): satchel names in the player's language, the Spirlog page within the
## screen, whole rows above the description, status titles that never pop up, the connection
## mark away from Back, no false zeros offline, the shop and account headers, the update panel.

var _unlocked: int
var _retro: int
var _inventory: Dictionary
var _billing: Dictionary
var _profile: Dictionary
var _name: String
var _money: int
var _settings_path: String

func before_each() -> void:
	_unlocked = EraManager.unlocked_era
	_retro = EraManager.retro_filter
	_inventory = GameState.inventory.duplicate(true)
	_billing = Billing.state.duplicate(true)
	_profile = Online.profile.duplicate(true)
	_name = GameState.tamer_name
	_money = GameState.money
	_settings_path = SaveManager.settings_path
	SaveManager.settings_path = "user://test_c100_menus_settings.json"
	EraManager.unlocked_era = 1
	EraManager.set_retro_filter(0)

func after_each() -> void:
	Loc.set_language("en")
	EraManager.unlocked_era = _unlocked
	EraManager.set_retro_filter(_retro)
	GameState.inventory = _inventory
	Billing.state = _billing
	Online.profile = _profile
	GameState.tamer_name = _name
	GameState.money = _money
	SaveManager.settings_path = _settings_path

func _close(m: MenuHost) -> void:
	m.close_all = true
	for i: int in 60:
		if m._info_wait:
			m._close_info()
		elif m.picker.visible:
			m.picker.picked.emit(-1)
		await wait_process_frames(1)

# --- Satchel (item 46, bug 3) -----------------------------------------------------

func test_satchel_rows_are_in_the_players_language() -> void:
	GameState.inventory = {"rg_echo_scent": 4}
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var name: String = Loc.t("Echo Scent")
		assert_eq(PauseMenu.bag_row_text("rg_echo_scent"), name + " x4", lang)
		if lang != "en":
			assert_false(PauseMenu.bag_row_text("rg_echo_scent").contains("Scent"), "%s: no half-English row" % lang)

func test_the_satchel_list_shows_translated_rows() -> void:
	GameState.inventory = {"rg_echo_scent": 4}
	Loc.set_language("ru")
	var tips: bool = GameState.tips_enabled
	GameState.tips_enabled = false
	var m := PauseMenu.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	m.run_bag()
	await wait_process_frames(4)
	assert_has(m.last_rows, "Аромат Эха x4")
	await _close(m)
	GameState.tips_enabled = tips

func test_satchel_sort_switch_is_not_a_stub() -> void:
	var m := PauseMenu.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	var b: Button = m.sort_toggle()
	assert_gt(b.custom_minimum_size.x, 20.0, "the switch shows its words, not a one-pixel stub (item 64)")
	b.free()

# --- Spirlog page (item 47, bug 5) ------------------------------------------------

func test_spirlog_page_fits_the_screen_in_every_era() -> void:
	var kinds: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		kinds.append(sd)
	# The kind with the longest unfold line makes the widest forms row.
	kinds.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return SpirlogBook.line_of(a).size() > SpirlogBook.line_of(b).size())
	var widest: SpirlingData = kinds[0]
	GameState.spirlog[widest.species_name] = GameState.spirlog.get(widest.species_name, {"seen": true, "caught": true})
	for era: int in range(1, 6):
		EraManager.unlocked_era = era
		EraManager.set_retro_filter(0)
		await wait_process_frames(2)
		var host := Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child_autofree(host)
		SpirlogPage.show_pages(host, [widest] as Array[SpirlingData], 0)
		await wait_process_frames(3)
		var page: SpirlogPage = host.get_child(0) as SpirlogPage
		var room: float = page.get_viewport_rect().size.x - MenuHost.PANEL_MARGIN * 2.0
		assert_lte(page.get_combined_minimum_size().x, room, "era %d: the page is no wider than the screen" % era)
		page._closed.emit()
		await wait_process_frames(1)

func test_form_size_shrinks_to_the_room() -> void:
	assert_eq(SpirlogPage.form_px_for(20, 3, 200.0), 20, "room enough: the era's size")
	assert_eq(SpirlogPage.form_px_for(24, 3, 62.0, 4.0), 16)
	assert_eq(SpirlogPage.form_px_for(20, 9, 10.0), SpirlogPage.MIN_FORM_PX)

# --- Description under the list (item 48, bug 6) ----------------------------------

func test_row_gap_leaves_whole_rows() -> void:
	assert_eq(ListPicker.row_gap(166.0, 17.0, 1.0), 166.0 - (9 * 17.0 - 1.0))
	assert_eq(ListPicker.row_gap(169.0, 17.0, 1.0), 0.0, "exactly ten rows: no gap")
	assert_eq(ListPicker.row_gap(0.0, 17.0, 1.0), 0.0)

func test_the_description_never_sits_on_a_cut_row() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var rows: Array[Dictionary] = []
	for i: int in 30:
		rows.append({"text": "Row %d" % i, "hint": "A description that takes three lines under the list, at least on a small phone."})
	for lang: String in ["en", "fr", "ja"]:
		Loc.set_language(lang)
		host.picker.pick("List", rows, true, 0)
		await wait_process_frames(6)
		var p: ListPicker = host.picker
		assert_true(p._hint.visible)
		var list: Rect2 = p._scroll.get_global_rect()
		var hint: Rect2 = p._hint.get_global_rect()
		assert_lte(list.end.y, hint.position.y, "%s: the list ends above the description" % lang)
		for b: Button in p._buttons:
			var r: Rect2 = b.get_global_rect()
			# A sliver up to the column spacing may stay (the gap itself costs that much).
			var shown: float = list.end.y - r.position.y
			var cut: bool = r.position.y < list.end.y and r.end.y > list.end.y and shown > 2.0
			assert_false(cut, "%s: %s is cut at the bottom of the list (%d px shown)" % [lang, b.text, int(shown)])
		p.picked.emit(-1)
		await wait_process_frames(1)

# --- Pause title (item 51, bug 9) --------------------------------------------------

func test_pause_title_never_pops_up() -> void:
	GameState.tamer_name = "Rowanna"
	GameState.money = 123456
	var m := PauseMenu.new()
	m.current_map = "fernstair"
	add_child_autofree(m)
	await wait_process_frames(1)
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		var t: String = m.pause_title()
		assert_lte(m.title_lines(t), MenuHost.TITLE_MAX_LINES, "%s: %s" % [lang, t])
		assert_true(t.begins_with("Rowanna"), "%s: name and coins stay in the title" % lang)

func test_title_lines_ignores_a_stale_title_width() -> void:
	var m := MenuHost.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	m.picker._title.size.x = 10.0
	assert_eq(m.title_lines("Rowan   500 coins"), 1, "a list not shown yet measures the real title width")

# --- Connection mark and offline values (item 56, bug 15) --------------------------

func test_connection_mark_keeps_off_the_back_button() -> void:
	var m := MenuHost.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	m.pick_strings("List", ["One", "Two"] as Array[String])
	var o := ReconnectOverlay.new()
	add_child_autofree(o)
	o.show_overlay()
	o.update_view(1, 2.0, 1.0)
	await wait_process_frames(4)
	assert_true(o._mark.visible)
	var back: Rect2 = m.picker.back_button().get_global_rect()
	assert_false(o._mark.get_global_rect().intersects(back), "the mark does not cover Back")
	m.picker.picked.emit(-1)

func test_offline_shows_no_false_zeros() -> void:
	Billing.state = {}
	Online.profile = {}
	assert_eq(ShopMenu.balance_text(), Loc.t(ShopMenu.BALANCE_OFFLINE))
	assert_false(ShopMenu.title().contains("0"), ShopMenu.title())
	assert_eq(AccountMenu.title(), "Account  (offline)")
	Online.profile = {"code": "ABCDEFGH"}
	assert_eq(AccountMenu.title(), "Account  Code ABCD-EFGH")

# --- Shop header (item 60, bug 19) ------------------------------------------------

func test_riftglass_tab_names_riftglass_once() -> void:
	Billing.state = {"balance": 120}
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		# Only the balance, which names Riftglass itself: no "Riftglass  120 Riftglass".
		assert_eq(ShopMenu.tab_title("riftglass"), ShopMenu.balance_text(), lang)
		assert_true(ShopMenu.tab_title("packs").begins_with(Loc.t("Packs") + "\n"), lang)

func test_shop_balance_never_breaks_inside_the_brackets() -> void:
	Billing.state = {"balance": 120}
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for line: String in ShopMenu.balance_text(80.0).split("\n"):
			assert_eq(line.count("("), line.count(")"), "%s: %s" % [lang, line])

func test_a_missing_price_is_explained() -> void:
	var o: Dictionary = ShopCatalog.in_tab("riftglass")[0]
	var keep: Dictionary = Billing.prices.duplicate()
	Billing.prices.erase(str(o.get("product_id", "")))
	var row: Dictionary = ShopMenu.offer_row(o, EraMenus.layout(1, "shop"))
	Billing.prices = keep
	assert_eq(str(row.right), ShopMenu.NO_PRICE)
	assert_true(str(row.hint).begins_with(ShopMenu.NO_PRICE_HINT), str(row.hint))

# --- Account (item 61, bug 20) ------------------------------------------------------

func test_account_menu_has_ten_rows_at_most_and_no_popup() -> void:
	Online.profile = {"code": "ABCDEFGH"}
	var m := MenuHost.new()
	add_child_autofree(m)
	await wait_process_frames(1)
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		AccountMenu.run(m)
		await wait_process_frames(2)
		assert_false(m._info_wait, "%s: the title shows no tap-to-continue page first" % lang)
		assert_lte(m.last_rows.size(), 10, lang)
		assert_has(m.last_rows, AccountMenu.NOTICES_ROW)
		await _close(m)
		m.close_all = false

# --- Update panel (item 62, bug 21) ------------------------------------------------

func test_update_panel_title_follows_the_update() -> void:
	var p := UpdatePanel.new()
	add_child_autofree(p)
	await wait_process_frames(1)
	p.show_view(AppUpdater.TEXT_STORE, ["Update"] as Array[String])
	assert_eq(p.title_text(), UpdatePanel.TITLE_STORE)
	p.show_view(AppUpdater.TEXT_APK)
	assert_eq(p.title_text(), UpdatePanel.TITLE_LOADING)
	p.show_view(AppUpdater.TEXT_FLEX)
	assert_eq(p.title_text(), UpdatePanel.TITLE_LOADING)
	p.show_view(AppUpdater.TEXT_APK_DONE)
	assert_eq(p.title_text(), UpdatePanel.TITLE_READY)
	p.show_view(AppUpdater.TEXT_APK_FAILED)
	assert_eq(p.title_text(), UpdatePanel.TITLE_FAILED)
