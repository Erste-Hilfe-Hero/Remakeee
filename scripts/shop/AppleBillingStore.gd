class_name AppleBillingStore
extends BillingStore
## App Store purchases with StoreKit 2 through Chimora's own iOS GDExtension (plugins/chimora_storekit,
## plan item 4092). Same JSON protocol as the Android plugin: every call answers once with the
## signal "billing_event" {"kind", "req", "code", ...}; codes follow Play Billing (0 ok, 1 cancelled,
## 2 offline, 3 no store, 4 not available, 6 error).
## Receipts carry Apple's signed transaction (JWS); the server checks it (server/billing/apple.py),
## including appAccountToken = the player's account id.

const SINGLETON: String = "ChimoraStoreKit"
const OK: int = 0
const USER_CANCELED: int = 1
const CODE_ERRORS: Dictionary = {2: "offline", 3: "no_store", 4: "not_available"}

signal answered(d: Dictionary)
## A purchase finished outside the sheet (Ask to Buy, a renewal, another device). Billing sends it on.
signal purchase_updated(receipt: Dictionary)

var _p: Object
var _ready_now: bool = false
var _next: int = 0
var _answers: Dictionary = {}

## [param plugin] is the engine singleton, or a stand-in in tests.
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
	if str(d.get("kind", "")) == "update":
		for p: Variant in d.get("purchases", []):
			if p is Dictionary and not bool(p.get("revoked", false)):
				purchase_updated.emit(receipt_of(p))
	if int(d.get("req", -1)) > 0:
		_answers[int(d.req)] = d
	answered.emit(d)

func _ask(method: String, args: Array) -> Dictionary:
	if _p == null:
		return {"code": 3}
	_next += 1
	var req: int = _next
	_p.callv(method, args + [req])
	while not _answers.has(req):
		await answered
	var d: Dictionary = _answers[req]
	_answers.erase(req)
	return d

func store_name() -> String:
	return "apple"

func is_ready() -> bool:
	return _ready_now

func connect_store() -> bool:
	var d: Dictionary = await _ask("start", [])
	_ready_now = int(d.get("code", -1)) == OK
	return _ready_now

func query(product_ids: Array[String]) -> Dictionary:
	if not _ready_now and not await connect_store():
		return {}
	var d: Dictionary = await _ask("query", [JSON.stringify(product_ids)])
	return d.get("prices", {}) if d.get("prices") is Dictionary else {}

## Apple ties the purchase to [param account_token] (the account id, a UUID) as appAccountToken.
func purchase(product_id: String, account_token: String, _account_hash: String) -> Dictionary:
	if not _ready_now and not await connect_store():
		return {"ok": false, "cancelled": false, "error": "no_store"}
	var d: Dictionary = await _ask("purchase", [product_id, account_token])
	var code: int = int(d.get("code", -1))
	if code == USER_CANCELED:
		return {"ok": false, "cancelled": true, "error": "cancelled"}
	if code != OK:
		return {"ok": false, "cancelled": false, "error": str(CODE_ERRORS.get(code, "store_error"))}
	if bool(d.get("pending", false)):
		return {"ok": false, "cancelled": false, "error": "pending"}
	for p: Variant in d.get("purchases", []):
		if p is Dictionary and str(p.get("product", "")) == product_id:
			return {"ok": true, "receipt": receipt_of(p)}
	return {"ok": false, "cancelled": false, "error": "store_error"}

static func receipt_of(p: Dictionary) -> Dictionary:
	return {"store": "apple", "product_id": str(p.get("product", "")), "jws": str(p.get("jws", "")),
		"txn": str(p.get("txn", "")), "account": str(p.get("account", ""))}

func finish(receipt: Dictionary, _consumable: bool) -> void:
	await _ask("finish", [str(receipt.get("txn", ""))])

## Bought, but the server has not credited it yet (StoreKit keeps it unfinished, item 4098).
func unfinished() -> Array[Dictionary]:
	return _receipts(await _ask("owned", []), true)

## Restore purchases (guideline 3.1.1): syncs with the App Store, then unlocks and the pass come back.
func restore() -> Array[Dictionary]:
	return _receipts(await _ask("restore", []), false)

func _receipts(d: Dictionary, only_unfinished: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Variant in d.get("purchases", []):
		if not p is Dictionary or bool(p.get("revoked", false)):
			continue
		if only_unfinished and not bool(p.get("unfinished", false)):
			continue
		out.append(receipt_of(p))
	return out
