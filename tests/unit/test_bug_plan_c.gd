extends GutTest
## Bug plan sweep C (master plan 1341-1380: menus, shop and purchases, saving). One test per fix.

const TEST_SLOT: String = "user://test_bug_c_slot.json"
const TEST_SETTINGS: String = "user://test_bug_c_settings.json"

var _old_slot: String
var _old_settings_path: String
var _old_settings: Dictionary
var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_store: BillingStore
var _old_billing: Dictionary
var _old_retro: int

func before_all() -> void:
	Database.load_all()
	_old_slot = SaveManager.slot_path
	_old_settings_path = SaveManager.settings_path
	_old_settings = GameState.settings_to_dict()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_store = Billing.store
	_old_billing = Billing.state
	_old_retro = EraManager.retro_filter

func after_all() -> void:
	SaveManager.slot_path = TEST_SLOT
	SaveManager.delete_save()
	SaveManager.slot_path = _old_slot
	SaveManager.settings_path = _old_settings_path
	GameState.settings_from_dict(_old_settings)
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.store = _old_store
	Billing.state = _old_billing
	EraManager.set_retro_filter(_old_retro)

func before_each() -> void:
	SaveManager.slot_path = TEST_SLOT
	SaveManager.delete_save()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func after_each() -> void:
	for p: String in SaveManager.save_paths(TEST_SETTINGS):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Billing.state = _old_billing
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.store = _old_store

static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

# --- Saving (1371-1380) --------------------------------------------------------------------

## 1373: the app died between moving the old save aside and renaming the new one, so only the
## backup is left. Continue must still find that slot.
func test_continue_finds_a_slot_with_only_a_backup() -> void:
	var kept: Dictionary = {}
	for n: int in range(1, SaveManager.SLOTS + 1):
		for p: String in SaveManager.save_paths(SaveManager.path_for_slot(n)):
			if FileAccess.file_exists(p):
				kept[p] = FileAccess.get_file_as_string(p)
				DirAccess.remove_absolute(p)
	var bak: String = SaveManager.backup_path_for(SaveManager.path_for_slot(3), 1)
	_write(bak, SaveManager.seal(JSON.stringify(SaveManager.build_save(), "\t")))
	assert_eq(SaveManager.latest_slot(), 3)
	DirAccess.remove_absolute(bak)
	for p: String in kept:
		_write(p, kept[p])

## 1373: a new journey in a used slot drops the old journey's backups, so a damaged new save
## never loads the old journey instead.
func test_new_journey_drops_the_old_backups() -> void:
	GameState.money = 111
	SaveManager.save_game()
	SaveManager.save_game()
	assert_true(FileAccess.file_exists(SaveManager.backup_path()))
	GameState.new_game(GameState.Difficulty.TAMER, "Nell", 1, "Zippit")
	GameState.money = 7
	assert_true(SaveManager.start_fresh_slot())
	for n: int in range(1, SaveManager.BACKUPS + 1):
		assert_false(FileAccess.file_exists(SaveManager.backup_path_for(TEST_SLOT, n)), "backup %d gone" % n)
	assert_true(SaveManager.load_game())
	assert_eq(GameState.tamer_name, "Nell")
	_write(TEST_SLOT, "{ broken")
	assert_false(SaveManager.load_game(), "nothing of the old journey is left to load")

## 1357: every shop boost survives a reload, at its real strength (Mighty Growth is x5).
func test_shop_boosts_survive_a_reload() -> void:
	GameState.shop_boosts = {"overcharge": {"mult": 1.0, "left": 1}, "encounters": {"mult": 2.0, "left": 30},
		"growth": {"mult": 5.0, "left": 20}}
	GameState.from_dict(GameState.to_dict())
	assert_eq(int(GameState.shop_boosts.get("overcharge", {}).get("left", 0)), 1)
	assert_eq(int(GameState.shop_boosts.get("encounters", {}).get("left", 0)), 30)
	assert_eq(float(GameState.shop_boosts.growth.mult), 5.0)
	assert_eq(ShopEffects.energy_bonus(false), ShopEffects.OVERCHARGE)

## 1380: empty and negative bag rows are not loaded or saved; a negative one used to swallow the
## next item of that kind.
func test_bag_keeps_only_real_counts() -> void:
	var d: Dictionary = GameState.to_dict()
	d["inventory"] = {"tonic": 0, "kin_charm": -2, "rope": 3}
	GameState.from_dict(d)
	assert_eq(JSON.stringify(GameState.inventory), JSON.stringify({"rope": 3}))
	GameState.add_item("kin_charm")
	assert_eq(GameState.item_count("kin_charm"), 1)
	GameState.inventory["tonic"] = 0
	assert_false((GameState.to_dict().inventory as Dictionary).has("tonic"), "used up in battle")

## 1380: handing the last keepsake to a Spirling leaves no empty row in the bag.
func test_last_keepsake_leaves_no_empty_row() -> void:
	var id: String = ""
	for k: String in Database.items:
		if BattleRules.is_holdable(k):
			id = k
			break
	assert_false(id.is_empty())
	GameState.inventory = {id: 1}
	assert_true(GameState.set_held(GameState.party[0], id))
	assert_false(GameState.inventory.has(id))

## 1373: a Spirling from Era V stays from Era V after a reload and in a trade.
func test_era_five_origin_is_kept() -> void:
	var s: Spirling = GameState.party[0]
	s.origin_era = 5
	assert_eq(Spirling.from_dict(s.to_dict()).origin_era, 5)
	assert_eq(int(LocalBackend.trade_mon_clean({"uid": "a", "origin_era": 5}).origin_era), 5)
	assert_eq(int(LocalBackend.trade_mon_clean({"uid": "a", "origin_era": 9}).origin_era), 1)
	assert_string_contains(TradeMenu.mons_text([{"species": "Kindlop", "level": 3, "origin_era": 5}]), Loc.t("Era V"))

# --- Menus and settings (1341-1350) ---------------------------------------------------------

## 1348: a damaged settings file falls back to its backup instead of losing every setting.
func test_damaged_settings_load_the_backup() -> void:
	SaveManager.settings_path = TEST_SETTINGS
	_write(TEST_SETTINGS, "{ broken")
	_write(SaveManager.backup_path_for(TEST_SETTINGS, 1), JSON.stringify({"volume": 0.3, "text_speed": 0}))
	GameState.volume = 0.9
	SaveManager.load_settings()
	assert_almost_eq(GameState.volume, 0.3, 0.001)
	assert_eq(GameState.text_speed, GameState.TextSpeed.SLOW)
	SaveManager.settings_path = _old_settings_path
	GameState.settings_from_dict(_old_settings)

# --- Shop and purchases (1351-1360) ---------------------------------------------------------

func _shop_online() -> LocalBilling:
	var s := LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	s.call_fn("shop_set_age", {"p_year": 1990, "p_month": 3})
	var store := LocalBilling.new()
	Billing.store = store
	Billing.state = {}
	GameState.inventory = {}
	GameState.in_game = false
	return store

## 1354: restoring a purchase that was paid but never credited brings its bag items too, and a
## receipt the server already had does not count as restored again.
func test_restore_delivers_bag_items_once() -> void:
	var store: LocalBilling = _shop_online()
	var o: Dictionary = ShopCatalog.offer("rg_overcharge")
	var p: Dictionary = await store.purchase(str(o.product_id), "", (Online.backend as LocalBackend).me().sha256_text())
	assert_eq(await Billing.restore(), 1)
	assert_eq(GameState.item_count("rg_overcharge"), 1, "the bought item is in the bag")
	store.owned = [p.receipt]
	assert_eq(await Billing.restore(), 0, "already credited")
	assert_eq(GameState.item_count("rg_overcharge"), 1)

## 1354: without a connection the menu says so instead of "nothing to restore".
func test_restore_offline_says_so() -> void:
	_shop_online()
	Online.state = Online.State.OFFLINE
	assert_eq(await Billing.restore(), -1)
	assert_eq(ShopMenu.restore_text(-1), Loc.t("Restoring needs a connection. Try again when you are online."))
	assert_ne(ShopMenu.restore_text(0), ShopMenu.restore_text(-1))

## 1360: a refunded setting goes back to its plain state.
func test_refunded_settings_fall_back() -> void:
	EraManager.set_retro_filter(EraManager.Era.INK)
	GameState.day_night = false
	GameState.weather = false
	GameState.text_speed = GameState.TextSpeed.FAST
	Billing.state = {"unlocks": {"retro_filter": 1, "sky_control": 1, "fast_text": 1}}
	ShopEffects.apply_unlocks()
	assert_eq(EraManager.retro_filter, EraManager.Era.INK, "kept while owned")
	assert_false(GameState.day_night)
	assert_eq(GameState.text_speed, GameState.TextSpeed.FAST)
	Billing.state = {"unlocks": {}}
	ShopEffects.apply_unlocks()
	assert_eq(EraManager.retro_filter, 0)
	assert_true(GameState.day_night)
	assert_true(GameState.weather)
	assert_eq(GameState.text_speed, GameState.TextSpeed.NORMAL)
	GameState.settings_from_dict(_old_settings)
