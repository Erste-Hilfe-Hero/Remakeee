extends GutTest
## docs/OFFLINE.md: a lost connection never pauses the game (a battle included), the parts that
## need the server say so in one short line, and nothing can be bought or paid for offline.
## Bought unlocks, the pass and the age band stay usable offline from a checked local copy.

const BF = preload("res://tests/helpers/BattleFixtures.gd")
const CACHE: String = "user://test_offline_entitlements.json"

class FakeStore:
	extends BillingStore
	var purchases: int = 0
	func is_ready() -> bool:
		return true
	func purchase(_product_id: String, _account_token: String, _account_hash: String) -> Dictionary:
		purchases += 1
		return {"ok": true, "receipt": {"product_id": _product_id}}

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_retry: float
var _billing: Dictionary
var _store: BillingStore
var _lang: String
var _keep_era: Dictionary
var s: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_retry = Online.net_retry_seconds

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.net_retry_seconds = _old_retry

func before_each() -> void:
	_billing = Billing.state
	_store = Billing.store
	_lang = Loc.language()
	_keep_era = {"unlocked": EraManager.unlocked_era, "retro": EraManager.retro_filter}
	Loc.set_language("en")
	s = LocalBackend.new()
	s.rng.seed = 1
	s.offline = true
	Online.backend = s
	Online.state = Online.State.OFFLINE
	Online.kicked = false
	Online.net_retry_seconds = 0.0
	Online._offline_for = 0.0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	Billing.state = _billing
	Billing.store = _store
	Loc.set_language(_lang)
	EraManager.unlocked_era = _keep_era.unlocked
	EraManager.set_retro_filter(_keep_era.retro)
	GameState.in_game = false
	Online.in_battle = false
	Online.offline_mark.visible = false
	get_tree().paused = false
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)

# --- No pause ------------------------------------------------------------------------------

## The connection drops in the middle of a battle: the battle plays to its end, the tree is never
## paused, only the small mark shows.
func test_drop_mid_battle_never_pauses() -> void:
	s.offline = false
	assert_eq(await Online.connect_now(), Online.State.ONLINE)
	GameState.in_game = true
	GameState.tips_enabled = false
	GameState.battle_speed = 2
	GameState.auto_mode = BattleComfort.AutoMode.STORY
	GameState.reduce_motion = true
	var m := BattleModel.new([BF.make("Kindlop", 12)] as Array[Spirling], [BF.make("Mossling", 4)] as Array[Spirling], false, 5, 1)
	m.trainer_name = "Hauler Tobin"
	m.set_meta("quick", true)
	var host := Control.new()
	host.size = Vector2(144, 256)
	add_child_autofree(host)
	var scene: BattleScene = load("res://scenes/battle/Battle.tscn").instantiate()
	scene.setup(m)
	scene.auto_kind = BattleComfort.auto_kind(false, {"story": true})
	Online.in_battle = true
	host.add_child(scene)
	await wait_process_frames(5)
	# The phone loses the connection now (a call fails), and stays offline for a long time.
	s.offline = true
	await Online.call_fn("presence", {"p_place": "x"})
	assert_eq(Online.state, Online.State.OFFLINE)
	Online._offline_for = OfflineMark.SHOW_AFTER + 600.0
	var paused: bool = false
	for i: int in 20000:
		if m.is_finished():
			break
		paused = paused or get_tree().paused
		scene._text.advance_now()
		await wait_process_frames(1)
	assert_true(m.is_finished(), "the battle went on to its end")
	assert_false(paused, "the game never paused")
	assert_true(Online.offline_mark.visible, "the small mark shows")
	GameState.auto_mode = 0

func test_offline_mark_is_small_and_out_of_the_way() -> void:
	assert_lte(OfflineMark.MARK_SIZE.x, 16.0)
	assert_lte(OfflineMark.MARK_SIZE.y, 12.0)
	var o := OfflineMark.new()
	add_child_autofree(o)
	var draws: Array[int] = [0]
	o.mark.draw.connect(func() -> void: draws[0] += 1)
	o.update_view(1.0)
	assert_false(o.visible, "a short drop shows nothing")
	o.update_view(OfflineMark.SHOW_AFTER)
	assert_true(o.visible)
	await wait_process_frames(2)
	assert_gt(draws[0], 0, "the mark is drawn once it shows (it was hidden when it entered the tree)")
	assert_eq(o.mark.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_false(get_tree().paused)

# --- Needs internet ------------------------------------------------------------------------

## Waits for the info box of [param host] (or its zoomed host) and returns its text.
func _info_text(host: MenuHost) -> String:
	for i: int in 120:
		await wait_process_frames(1)
		var live: MenuHost = _live_host(host)
		if live._info_panel.visible:
			var t: String = live._info_label.text
			live._close_info()
			return t
	return ""

func _live_host(host: MenuHost) -> MenuHost:
	var v: Node = host.get_node_or_null("shop_zoom")
	return v.get_child(0).get_child(0) as MenuHost if v != null else host

func test_error_text_offline_is_the_needs_internet_line() -> void:
	assert_eq(Online.error_text(), OnlineErrors.NEEDS_INTERNET)
	assert_eq(Online.error_text("offline"), OnlineErrors.NEEDS_INTERNET, "a call refused offline says the same")
	Online.kicked = true
	assert_eq(Online.error_text(), OnlineErrors.text(Online.last_error) if Online.last_error != "" else OnlineErrors.GENERIC)
	Online.kicked = false

func test_shop_offline_says_needs_internet_and_opens_nothing() -> void:
	Billing.state = {"band": 30, "unlocks": {}, "cached": true}
	var fake := FakeStore.new()
	Billing.store = fake
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	ShopMenu.run(host)
	var t: String = await _info_text(host)
	assert_string_contains(t, Loc.t(OnlineErrors.NEEDS_INTERNET))
	await wait_process_frames(3)
	assert_null(_find(host, ShopScreen), "no shop screen behind it")
	assert_eq(fake.purchases, 0)

func test_league_offline_says_needs_internet() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(1)
	LeagueMenu.run(menu)
	assert_string_contains(await _info_text(menu), Loc.t(OnlineErrors.NEEDS_INTERNET))

func test_friends_offline_says_needs_internet() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(1)
	FriendsMenu.run(menu)
	assert_string_contains(await _info_text(menu), Loc.t(OnlineErrors.NEEDS_INTERNET))

func test_needs_internet_line_has_every_language_and_says_it_in_german() -> void:
	Loc.set_language("de")
	assert_eq(Loc.t(OnlineErrors.NEEDS_INTERNET), "Dafür brauchst du Internet. Der Rest deiner Reise geht offline weiter.")
	for code: String in Loc.LANGUAGES:
		if code == "en":
			continue
		Loc.set_language(code)
		assert_ne(Loc.t(OnlineErrors.NEEDS_INTERNET), OnlineErrors.NEEDS_INTERNET, code)

## The line shows at reading size: every text at least 13 pt, every button 44 pt, in all eras
## on the smallest supported phone (ShopZoom, iPhone SE).
func test_needs_internet_line_is_at_reading_size_in_every_era() -> void:
	for e: int in range(1, 6):
		EraManager.unlocked_era = e
		EraManager.set_retro_filter(0)
		var vp := SubViewport.new()
		vp.size = ShopZoom.phone_view(e)
		add_child_autofree(vp)
		var host := MenuHost.new()
		vp.add_child(host)
		await wait_process_frames(1)
		OnlineErrors.say_offline(host)
		var live: MenuHost = host
		for i: int in 60:
			await wait_process_frames(1)
			live = _live_host(host)
			if live._info_panel.visible:
				break
		assert_true(live._info_panel.visible, "era %d" % e)
		assert_eq(_too_small(live, e), [] as Array[String], "era %d" % e)
		live._close_info()
		await wait_process_frames(2)

func _too_small(root: Node, e: int) -> Array[String]:
	var out: Array[String] = []
	_walk(root, ShopZoom.pt_per_px(e), out)
	return out

func _walk(n: Node, pt: float, out: Array[String]) -> void:
	for c: Node in n.get_children():
		var ctl: Control = c as Control
		if ctl == null or not ctl.is_visible_in_tree():
			continue
		var k: float = ShopZoom.screen_scale(ctl) * pt
		if ctl is Button and ctl.size.y * k < ShopZoom.MIN_TOUCH_PT - 0.01:
			out.append("button %.0f pt: %s" % [ctl.size.y * k, (ctl as Button).text.left(30)])
		var text: String = (ctl as Label).text if ctl is Label else ((ctl as Button).text if ctl is Button else "")
		if not text.strip_edges().is_empty():
			var h: float = ctl.get_theme_font("font").get_height(ctl.get_theme_font_size("font_size")) * k
			if h < ShopZoom.MIN_TEXT_PT - 0.01:
				out.append("text %.1f pt: %s" % [h, text.left(30)])
		_walk(ctl, pt, out)

func _find(root: Node, cls: Variant) -> Node:
	for c: Node in root.get_children():
		if is_instance_of(c, cls):
			return c
		var d: Node = _find(c, cls)
		if d != null:
			return d
	return null

# --- No purchase offline -------------------------------------------------------------------

func test_no_store_purchase_offline_even_with_a_known_shop_state() -> void:
	# The shop state of a moment ago is still in memory, the connection is gone.
	Billing.state = {"band": 30, "open": true, "balance": 500, "cap_cents": 30000, "spent_cents": 0, "unlocks": {}}
	var fake := FakeStore.new()
	Billing.store = fake
	var o: Dictionary = ShopCatalog.offer(ShopScreen.STARTER_ID)
	assert_false(o.is_empty())
	var r: Dictionary = await Billing.buy_in_store(o)
	assert_false(bool(r.ok))
	assert_eq(str(r.error), "offline")
	assert_eq(fake.purchases, 0, "the store sheet never opened")

func test_no_riftglass_spent_or_granted_offline() -> void:
	Billing.state = {"band": 30, "open": true, "balance": 500, "unlocks": {}}
	var o: Dictionary = {"id": "x", "rg_price": 10, "ready": true}
	var r: Dictionary = await Billing.buy_with_riftglass(o)
	assert_eq(str(r.error), "offline")
	assert_eq(Billing.balance(), 500, "the balance did not move")
	assert_eq(str((await RiftglassSinks.spend("heal", "", 10)).error), "offline")
	assert_eq(await RiftglassSinks.claim_daily(), 0, "no free Riftglass offline")
	assert_false(RiftglassSinks.visible(), "Riftglass rows are hidden offline")

func test_no_starter_pack_note_offline() -> void:
	Billing.state = {"band": 30, "open": true, "balance": 0, "cap_cents": 30000, "spent_cents": 0, "unlocks": {}}
	GameState.set_flag(GameState.ACT1_END_FLAG)
	assert_false(ShopScreen.starter_popup_now(), "a purchase prompt needs the server")

func test_kids_lock_holds_offline_without_any_purchase_prompt() -> void:
	Billing.state = {"band": 10, "unlocks": {}, "cached": true}
	assert_true(Billing.kids_locked())
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	ShopMenu.run(host)
	assert_string_contains(await _info_text(host), Loc.t(ShopMenu.LOCKED_TEXT))
	GameState.set_flag(GameState.ACT1_END_FLAG)
	assert_false(ShopScreen.starter_popup_now())

# --- Entitlements offline ------------------------------------------------------------------

func test_bought_unlocks_and_pass_work_offline_from_the_local_copy() -> void:
	var now: int = 2_000_000_000
	Billing.state = {"band": 30, "balance": 999, "unlocks": {"team_slot_6": 1, "swift_steps": 1},
		"pass_active": true, "pass_until": now + 3600, "account_token": "secret"}
	Billing.save_cache(CACHE)
	# The app starts again without a connection.
	Billing.state = {}
	assert_true(Billing.load_cache(CACHE, now))
	assert_eq(Billing.unlocked("team_slot_6"), 1)
	assert_eq(GameState.party_max(), GameState.MAX_PARTY + 1, "the bought team slot is there offline")
	assert_true(Billing.pass_active())
	assert_false(Billing.state.has("balance"), "the Riftglass balance is never copied")
	assert_false(Billing.state.has("account_token"))
	assert_true(bool(Billing.state.get("cached", false)))

func test_local_copy_ignores_edits_a_set_back_clock_and_an_ended_pass() -> void:
	var now: int = 2_000_000_000
	Billing.state = {"band": 30, "unlocks": {"swift_steps": 1}, "pass_active": true, "pass_until": now + 60}
	Billing.save_cache(CACHE)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CACHE))
	# The pass ran out while offline.
	Billing.state = {}
	assert_true(Billing.load_cache(CACHE, now + 120))
	assert_false(Billing.pass_active(), "an ended pass does not run on offline")
	# A clock set back before the copy was written.
	Billing.state = {}
	assert_false(Billing.load_cache(CACHE, int(raw.ent.cached_at) - 10))
	# A hand-edited copy.
	raw.ent.unlocks["growth_plus_2"] = 1
	var f := FileAccess.open(CACHE, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	Billing.state = {}
	assert_false(Billing.load_cache(CACHE, now))
	assert_eq(Billing.unlocked("growth_plus_2"), 0)

func test_server_state_replaces_the_local_copy() -> void:
	Billing.state = {"band": 30, "unlocks": {"swift_steps": 1}}
	Billing.save_cache(CACHE)
	Billing.state = {"band": 30, "unlocks": {}}
	assert_false(Billing.load_cache(CACHE), "a state from the server is never overwritten by the copy")
	assert_eq(Billing.unlocked("swift_steps"), 0)
