class_name GoogleBillingStore
extends BillingStore
## Google Play Billing through Chimora's own Android plugin (plugins/chimora_billing, Play Billing
## Library 8). The plugin answers every call with one signal, "billing_event", carrying JSON:
## {"kind": "ready" | "prices" | "purchase" | "owned" | "finished" | "disconnected", "req", "code", ...}.
## Receipts carry the purchaseToken; the server checks it with Google (server/billing/google.py).

const SINGLETON: String = "ChimoraBilling"
## BillingResponseCode values from the Play Billing Library.
const OK: int = 0
const USER_CANCELED: int = 1
const ITEM_ALREADY_OWNED: int = 7
## Purchase.PurchaseState.PURCHASED (PENDING is 2: paid later in a shop, nothing is credited yet).
const PURCHASED: int = 1

## Emitted for every answer of the plugin (parsed).
signal answered(d: Dictionary)

var _p: Object
var _ready_now: bool = false
var _next: int = 0
## Answers that came before anyone waited for them (the plugin may answer during the call).
var _answers: Dictionary = {}

## [param plugin] is the Android singleton, or a stand-in in tests.
func _init(plugin: Object = null) -> void:
	_p = plugin if plugin != null else (Engine.get_singleton(SINGLETON) if Engine.has_singleton(SINGLETON) else null)
	if _p != null:
		_p.connect("billing_event", _on_event)

static func available_here() -> bool:
	return Engine.has_singleton(SINGLETON)

func _on_event(text: String) -> void:
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return
	if str(d.get("kind", "")) == "disconnected":
		_ready_now = false
	if int(d.get("req", -1)) > 0:
		_answers[int(d.req)] = d
	answered.emit(d)

## Calls [param method] on the plugin and waits for the answer with the same request number.
func _ask(method: String, args: Array) -> Dictionary:
	if _p == null:
		return {"code": -1}
	_next += 1
	var req: int = _next
	_p.callv(method, args + [req])
	while not _answers.has(req):
		await answered
	var d: Dictionary = _answers[req]
	_answers.erase(req)
	return d

func store_name() -> String:
	return "google"

func is_ready() -> bool:
	return _ready_now

## Connects to Google Play. Billing calls it on start; it is safe to call again after a drop.
func connect_store() -> bool:
	var d: Dictionary = await _ask("start", [])
	_ready_now = int(d.get("code", -1)) == OK
	return _ready_now

func query(product_ids: Array[String]) -> Dictionary:
	if not _ready_now and not await connect_store():
		return {}
	var d: Dictionary = await _ask("query", [JSON.stringify(product_ids)])
	return d.get("prices", {}) if d.get("prices") is Dictionary else {}

func purchase(product_id: String, _account_token: String, account_hash: String) -> Dictionary:
	if not _ready_now and not await connect_store():
		return {"ok": false, "cancelled": false, "error": "no_store"}
	# The plugin needs the product details from a query before it can open the sheet.
	await query([product_id] as Array[String])
	var d: Dictionary = await _ask("purchase", [product_id, account_hash])
	var code: int = int(d.get("code", -1))
	if code == USER_CANCELED:
		return {"ok": false, "cancelled": true, "error": "cancelled"}
	if code == ITEM_ALREADY_OWNED:
		# Bought before but not finished: Billing.resume_pending() sends it to the server.
		return {"ok": false, "cancelled": false, "error": "already_owned"}
	if code != OK:
		return {"ok": false, "cancelled": false, "error": "store_error"}
	for p: Variant in d.get("purchases", []):
		if p is Dictionary and product_id in (p.get("products", []) as Array):
			if int(p.get("state", 0)) != PURCHASED:
				return {"ok": false, "cancelled": false, "error": "pending"}
			return {"ok": true, "receipt": receipt_of(p, product_id)}
	return {"ok": false, "cancelled": false, "error": "store_error"}

static func receipt_of(p: Dictionary, product_id: String) -> Dictionary:
	return {"store": "google", "product_id": product_id, "token": str(p.get("token", "")),
		"txn": str(p.get("order", "")), "account": str(p.get("account", ""))}

func finish(receipt: Dictionary, consumable: bool) -> void:
	await _ask("finish", [str(receipt.get("token", "")), consumable])

## Bought and paid, but not finished yet: consumables Google still holds and unlocks or passes
## nobody acknowledged (item 4115).
func unfinished() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in await _owned():
		var o: Dictionary = ShopCatalog.by_product(str(r.product_id))
		if not bool(r.get("_acknowledged", false)) or str(o.get("store_type", "consumable")) == "consumable":
			r.erase("_acknowledged")
			out.append(r)
	return out

## Unlocks and the pass come back on a new phone (the server credits each token once).
func restore() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in await _owned():
		r.erase("_acknowledged")
		out.append(r)
	return out

func _owned() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _ready_now and not await connect_store():
		return out
	var d: Dictionary = await _ask("owned", [])
	for p: Variant in d.get("purchases", []):
		if not p is Dictionary or int(p.get("state", 0)) != PURCHASED:
			continue
		for pid: Variant in p.get("products", []):
			var r: Dictionary = receipt_of(p, str(pid))
			r["_acknowledged"] = bool(p.get("acknowledged", false))
			out.append(r)
	return out
