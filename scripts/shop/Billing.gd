extends Node
## Autoload "Billing": one interface for Google Play Billing, Apple StoreKit 2 and the local test
## store (items 4093-4099). Rules (docs/MONETIZATION.md):
## - Prices on screen only come from the store (item 4095).
## - Every store purchase goes to the server first; only after the server credited it the store is
##   told it is done (items 4096, 4097). Bag items and coins come from the server (shop_claim).
## - Open purchases are sent again on start and after every reconnect (item 4098).
## - The monthly limit is checked before a store purchase starts (item 4252).

## The purchase flow (item 4099).
enum Step { READY, QUERY, PURCHASING, VERIFYING, CREDITED, FAILED, CANCELLED }

signal step_changed(step: Step)
## Bag items and coins arrived from the server and went into the journey.
signal delivered(grants: Array)
## The Wayfarer Pass paid its daily Riftglass ([param added] includes missed days, item 4631).
signal pass_paid(added: int)

var step: Step = Step.READY
## The store in use, or null when this build cannot buy (web, release builds without a plugin).
var store: BillingStore
## Last shop_state from the server ({} until the shop was opened).
var state: Dictionary = {}
## Store price texts by product id.
var prices: Dictionary = {}
var last_error: String = ""
var _buying: bool = false

func _ready() -> void:
	store = make_store()
	if Online.has_signal("state_changed"):
		Online.state_changed.connect(_on_online_state)

## Picks the store for this build: Google Play on Android (plugins/chimora_billing), the App Store
## with StoreKit 2 on iOS (plugins/chimora_storekit), the local test store in debug builds against
## the local server.
func make_store() -> BillingStore:
	if GoogleBillingStore.available_here():
		var g := GoogleBillingStore.new()
		_connect_store(g)
		return g
	if AppleBillingStore.available_here():
		var a := AppleBillingStore.new()
		a.purchase_updated.connect(_on_store_update)
		_connect_store(a)
		return a
	if Online.is_local() and OS.is_debug_build():
		return LocalBilling.new()
	return null

## Connects to the store in the background; open purchases go to the server once it is up.
func _connect_store(g: BillingStore) -> void:
	if await g.connect_store() and Online.is_online():
		resume_pending()

## A purchase the store finished outside the sheet (Ask to Buy approved, bought on another device):
## the server checks and credits it like any other.
func _on_store_update(receipt: Dictionary) -> void:
	if _buying or not Online.is_online():
		return
	if (await _verify(receipt)).get("ok", false):
		await claim()
		await refresh_state()
	_set_step(Step.READY)

func available() -> bool:
	return store != null and store.is_ready()

func _set_step(s: Step) -> void:
	step = s
	step_changed.emit(s)

func _on_online_state(s: int) -> void:
	if s != Online.State.ONLINE:
		return
	if available():
		resume_pending()
	await refresh_state()

# --- Server state ------------------------------------------------------------------------------

func refresh_state() -> Dictionary:
	var r: Dictionary = await Online.call_fn("shop_state")
	if r.ok and r.data is Dictionary:
		state = r.data
		ShopEffects.apply_unlocks()
		if pass_active():
			await claim_pass_daily()
	return r

## The pass's 30 Riftglass a day, paid by the server once per Berlin calendar day and up to 7
## missed days later (items 4631, 4637, 4659). Returns the Riftglass added (0 = already paid).
func claim_pass_daily() -> int:
	var r: Dictionary = await Online.call_fn("shop_pass_daily")
	if not r.ok or not r.data is Dictionary or not bool(r.data.get("ok", false)):
		return 0
	var added: int = int(r.data.get("added", 0))
	if r.data.has("balance"):
		state["balance"] = int(r.data.balance)
	if added > 0:
		pass_paid.emit(added)
	return added

func band() -> Variant:
	return state.get("band")

## True when the server said the player is under 13 (the pause menu then shows "Shop (locked)").
func kids_locked() -> bool:
	var b: Variant = state.get("band")
	return b != null and int(b) < 13

func balance() -> int:
	return int(state.get("balance", 0))

func unlocked(key: String) -> int:
	var u: Variant = state.get("unlocks", {})
	return int(u.get(key, 0)) if u is Dictionary else 0

func pass_active() -> bool:
	return bool(state.get("pass_active", false))

## Why an offer cannot be bought now ("" = it can). Mirrors the server, so the menu can say it
## before anything starts.
func block_reason(o: Dictionary, with_riftglass: bool) -> String:
	if state.is_empty():
		return "offline"
	if not bool(state.get("open", true)):
		return "shop_closed"
	if state.get("band") == null:
		return "age_needed"
	if int(state.band) < maxi(13, int(o.get("min_band", 13))):
		return "age"
	if not bool(o.get("ready", false)):
		return "not_available"
	if bool(state.get("locked", false)):
		return "limit_reached"
	if o.has("limit") and int(state.get("bought", {}).get(str(o.id), 0)) >= int(o.limit.n):
		return "offer_limit"
	var req: String = str(o.get("requires", ""))
	if req.begins_with("rifts:") and int(state.get("rifts", 0)) < int(req.get_slice(":", 1)):
		return "not_yet"
	if req.begins_with("tier:") and not ShopEffects.tier_ok(req, unlocked(req.get_slice(":", 1))):
		return "tier_order"
	if req.begins_with("none:") and not ShopEffects.none_ok(req, func(k: String) -> int: return unlocked(k)):
		return "not_yet"
	if req.begins_with("max:") and not ShopEffects.max_ok(req, unlocked(req.get_slice(":", 1))):
		return "offer_limit"
	if with_riftglass:
		if int(o.get("rg_price", 0)) <= 0:
			return "not_for_riftglass"
		if balance() < int(o.rg_price):
			return "not_enough"
	else:
		if not available():
			return "no_store"
		if int(state.get("spent_cents", 0)) + int(o.get("eur_cents", 0)) > int(state.get("cap_cents", 0)):
			return "limit"
	return ""

# --- Store prices --------------------------------------------------------------------------------

func query_products(product_ids: Array[String]) -> Dictionary:
	if not available():
		return {}
	_set_step(Step.QUERY)
	var got: Dictionary = await store.query(product_ids)
	prices.merge(got, true)
	_set_step(Step.READY)
	return got

func price_text(o: Dictionary) -> String:
	return str(prices.get(str(o.get("product_id", "")), ""))

# --- Buying --------------------------------------------------------------------------------------

## Buys [param o] with Riftglass on the server (no store involved).
func buy_with_riftglass(o: Dictionary, choice: Variant = null) -> Dictionary:
	var why: String = block_reason(o, true)
	if not why.is_empty():
		return {"ok": false, "error": why}
	var args: Dictionary = {"p_offer": str(o.id), "p_expected_price": int(o.rg_price)}
	if choice != null:
		args["p_choice"] = str(choice)
	var r: Dictionary = await Online.call_fn("shop_buy", args)
	if not r.ok:
		return {"ok": false, "error": "offline" if r.net else str(r.error)}
	var d: Dictionary = r.data if r.data is Dictionary else {}
	if bool(d.get("ok", false)):
		state["balance"] = int(d.get("balance", balance()))
		await claim()
		await refresh_state()
	return d

## Buys [param o] directly in the store, then lets the server check and credit the receipt.
func buy_in_store(o: Dictionary, choice: Variant = null) -> Dictionary:
	# A second tap while a purchase runs starts nothing (item 4106).
	if _buying:
		return {"ok": false, "error": "busy"}
	_buying = true
	var r: Dictionary = await _buy_in_store(o, choice)
	_buying = false
	return r

func busy() -> bool:
	return _buying

func _buy_in_store(o: Dictionary, choice: Variant) -> Dictionary:
	await refresh_state()
	var why: String = block_reason(o, false)
	if not why.is_empty():
		return {"ok": false, "error": why}
	_set_step(Step.PURCHASING)
	var p: Dictionary = await store.purchase(str(o.product_id), str(state.get("account_token", "")), str(state.get("account_hash", "")))
	if not bool(p.get("ok", false)):
		_set_step(Step.CANCELLED if bool(p.get("cancelled", false)) else Step.FAILED)
		var err: String = "cancelled" if bool(p.get("cancelled", false)) else str(p.get("error", "store_error"))
		if err == "already_owned":
			# Paid before but never credited: send it to the server now.
			await resume_pending()
		return {"ok": false, "error": err}
	var r: Dictionary = await _verify(p.receipt, choice)
	if r.get("ok", false):
		await claim()
		await refresh_state()
	return r

## Sends a receipt to the server; finishes it in the store only once it is credited.
func _verify(receipt: Dictionary, choice: Variant = null) -> Dictionary:
	_set_step(Step.VERIFYING)
	var args: Dictionary = {"p_store": str(receipt.get("store", "")), "p_receipt": receipt}
	if choice != null:
		args["p_choice"] = str(choice)
	var r: Dictionary = await Online.call_fn("shop_verify", args)
	var d: Dictionary = r.data if r.ok and r.data is Dictionary else {}
	if not bool(d.get("ok", false)):
		# The purchase stays open in the store and is sent again later (item 4098).
		last_error = "offline" if r.get("net", false) else str(d.get("error", r.get("error", "verify_failed")))
		_set_step(Step.FAILED)
		return {"ok": false, "error": last_error}
	var o: Dictionary = ShopCatalog.by_product(str(receipt.get("product_id", "")))
	store.finish(receipt, str(o.get("store_type", "consumable")) == "consumable")
	_set_step(Step.CREDITED)
	return d

## Sends purchases the store still has open to the server (start, reconnect).
func resume_pending() -> int:
	if not available() or not Online.is_online():
		return 0
	var n: int = 0
	for receipt: Dictionary in await store.unfinished():
		var r: Dictionary = await _verify(receipt)
		if r.get("ok", false):
			n += 1
	if n > 0:
		await claim()
	_set_step(Step.READY)
	return n

## "Restore purchases": unlocks and the pass come back from the store. Returns how many purchases
## the server credited now (receipts it already had do not count), or -1 without a connection, so
## the menu never says "nothing to restore" when it could not ask (bug plan 1354). Bag items and
## coins of a restored purchase are picked up at once.
func restore() -> int:
	if not available():
		return 0
	if not Online.is_online():
		last_error = "offline"
		return -1
	var n: int = 0
	for receipt: Dictionary in await store.restore():
		var r: Dictionary = await _verify(receipt)
		if r.get("ok", false) and not bool(r.get("duplicate", false)):
			n += 1
	if n > 0:
		await claim()
	await refresh_state()
	_set_step(Step.READY)
	return n

## Picks up bag items and coins from the server and puts them into the journey (item 4344).
func claim() -> Array:
	var r: Dictionary = await Online.call_fn("shop_claim")
	if not r.ok or not r.data is Array:
		return []
	var all: Array = []
	for d: Variant in r.data:
		for g: Variant in d.get("grants", []):
			apply_grant(g)
			all.append(g)
	if not all.is_empty():
		delivered.emit(all)
		if GameState.in_game:
			SaveManager.save_game()
	return all

static func apply_grant(g: Dictionary) -> void:
	match str(g.get("t", "")):
		"item":
			GameState.add_item(str(g.id), int(g.get("n", 1)))
		"coins":
			GameState.money = mini(GameState.money + int(g.get("n", 0)), 9999999)
		"spirling":
			var s: Spirling = ShopEffects.bought_spirling(g)
			if s != null:
				GameState.receive_spirling(s)
