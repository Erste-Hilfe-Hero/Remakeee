class_name LocalBilling
extends BillingStore
## Pretend store for the editor, desktop debug builds and tests. It only works together with the
## local test server (LocalBackend), which accepts its fake receipts. Never active in release
## builds (item 4094): Billing only picks it when the build is a debug build and the server is local.

## Set by tests: the next purchase is cancelled or fails in the store.
var cancel_next: bool = false
var fail_next: bool = false
var finished: Array[String] = []
var _open: Array[Dictionary] = []
var _n: int = 0

func store_name() -> String:
	return "local"

func is_ready() -> bool:
	return true

func query(product_ids: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for pid: String in product_ids:
		var o: Dictionary = ShopCatalog.by_product(pid)
		if not o.is_empty():
			var c: int = int(o.eur_cents)
			out[pid] = "%d,%02d €" % [c / 100, c % 100]
	return out

func purchase(product_id: String, _account_token: String, account_hash: String) -> Dictionary:
	if cancel_next:
		cancel_next = false
		return {"ok": false, "cancelled": true, "error": "cancelled"}
	if fail_next:
		fail_next = false
		return {"ok": false, "cancelled": false, "error": "store_error"}
	if ShopCatalog.by_product(product_id).is_empty():
		return {"ok": false, "cancelled": false, "error": "unknown_product"}
	_n += 1
	var r: Dictionary = {"store": "local", "product_id": product_id, "txn": "LOCAL-%d-%d" % [Time.get_ticks_usec(), _n],
		"account": account_hash}
	_open.append(r)
	return {"ok": true, "receipt": r}

func finish(receipt: Dictionary, _consumable: bool) -> void:
	finished.append(str(receipt.get("txn", "")))
	_open = _open.filter(func(r: Dictionary) -> bool: return r.txn != receipt.get("txn"))

func unfinished() -> Array[Dictionary]:
	return _open.duplicate()
