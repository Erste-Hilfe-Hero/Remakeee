extends GutTest
## QA of the merged pay-to-win shop (claude/c-p2w-all, 27.11.2026): the seams between the shop
## screen, the pass track, the Riftglass sinks, the deals and the Monthly Card.

## Monday 30 Nov 2026 12:00 UTC (13:00 in Berlin).
const MONDAY_NOON: int = 1796040000

var _old_backend: OnlineBackend
var _old_state: Online.State
var _billing: Dictionary
var _lang: String
var s: LocalBackend
var shop: LocalShop

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state

func before_each() -> void:
	_billing = Billing.state
	_lang = Loc.language()
	Loc.set_language("en")
	s = LocalBackend.new()
	s.rng.seed = 1
	shop = LocalShop.of(s)
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})

func after_each() -> void:
	Billing.state = _billing
	Loc.set_language(_lang)

## The "not enough Riftglass" link of a sink opens the new shop screen on its Riftglass tab,
## not the old offer list.
func test_riftglass_link_opens_the_shop_screen_tab() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	RiftglassSinks.open_riftglass_page(host)
	var screen: ShopScreen = null
	for i: int in 30:
		await wait_process_frames(1)
		for c: Node in host.get_children():
			if c is ShopScreen:
				screen = c
		if screen != null:
			break
	assert_not_null(screen, "the shop screen opened")
	if screen == null:
		return
	assert_eq(screen.tab, "riftglass")
	assert_not_null(screen._list.get_node_or_null("card_rg_monthly_card"), "the Monthly Card is on the tab")
	screen.closed.emit()

## The Monthly Card's daily Riftglass shows a toast in the world, like the pass's.
func test_monthly_card_pays_with_a_toast() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var ow: Overworld = load("res://scenes/overworld/Overworld.tscn").instantiate()
	add_child_autofree(ow)
	await wait_process_frames(2)
	var before: int = ow.toast.pending()
	Billing.card_paid.emit(100)
	assert_eq(ow.toast.pending(), before + 1, "a note is queued")
	assert_true(Billing.card_paid.is_connected(ow._on_card_paid))

## The pass screen names its end as a fixed date, never a running "ends in" (MONETIZATION.md rule 5).
func test_pass_end_is_a_date_not_a_countdown() -> void:
	var ends: int = Online.unix_now() + 3 * 3600
	var t: String = PassScreen.title({"points": 40, "ends": ends})
	assert_false(t.contains("ends in"), t)
	assert_true(t.contains(ShopScreen.time_text(ends)), t)

## The Pass tab's "Show the pass" reaches PassScreen.run.
func test_shop_reaches_the_pass_screen() -> void:
	var path: String = ShopScreen.pass_screen_path()
	assert_eq(path, ShopScreen.PASS_PATH)
	assert_true(load(path).has_method("run"))

## Monday's deal is on the Packs tab on Monday only; the first purchase x2 tag goes after the first buy.
func test_deals_and_first_buy_tag() -> void:
	var ids: Array[String] = []
	for o: Dictionary in ShopScreen.shown_offers("packs", MONDAY_NOON):
		ids.append(str(o.id))
	assert_true("rg_deal_mon" in ids, str(ids))
	assert_false("rg_deal_tue" in ids)
	await Billing.refresh_state()
	var o: Dictionary = ShopCatalog.offer("rg_glass_1000")
	assert_true(_has_tag(o, "double"), str(Billing.state.get("bought")) + str(ShopScreen.tags(o, MONDAY_NOON)))
	shop.credit(s.me(), "apple", "Q1", str(o.product_id), 999)
	await Billing.refresh_state()
	assert_false(_has_tag(o, "double"), "state.bought from the server hides it")

func _has_tag(o: Dictionary, kind: String) -> bool:
	for t: Array in ShopScreen.tags(o, MONDAY_NOON):
		if str(t[1]) == kind:
			return true
	return false

## The pass screen's status title fits the list title on the smallest phone screen (Era I), so it
## never pops up as a text page before the steps.
func test_pass_title_never_pops_up_first() -> void:
	var vp := SubViewport.new()
	vp.size = EraManager.RESOLUTION[1]
	add_child_autofree(vp)
	var host := MenuHost.new()
	vp.add_child(host)
	await wait_process_frames(2)
	var st: Dictionary = {"points": 550, "ends": Online.unix_now() + 20 * 86400}
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		var t: String = host.fit_title(PassScreen.titles(st))
		assert_lte(host.title_lines(t), MenuHost.TITLE_MAX_LINES, lang + ": " + t)

## A Riftglass question has one way back: the list's own Back row, not a second "Back" answer.
func test_riftglass_question_has_one_back_row() -> void:
	shop._ledger_add(s.me(), 1250, "support", "test")
	await Billing.refresh_state()
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	RiftglassSinks.pay_in_menu(host, "heal", "", 100, "Heal?")
	for i: int in 60:
		await wait_process_frames(1)
		if host.picks > 0:
			break
	var texts: Array[String] = []
	for b: Button in host.picker.buttons():
		texts.append(b.text)
	assert_eq(texts.count(Loc.t("Back")), 1, str(texts))
	host.picker.picked.emit(-1)

## The continue choice after a lost battle shows the price with its euro value, not only the balance.
func test_continue_choice_shows_the_price() -> void:
	Billing.state = {"balance": 1250}
	var t: String = BattleScene.continue_title(200)
	assert_true(t.contains(RiftglassSinks.cost_text(200)), t)
	assert_true(t.contains(RiftglassSinks.balance_line()), t)
