extends GutTest
## AppleBillingStore against a stand-in for the iOS GDExtension (plugins/chimora_storekit).

class FakeStoreKit extends RefCounted:
	signal billing_event(text: String)
	var calls: Array = []
	var purchase_answer: Dictionary = {}
	var owned_list: Array = []
	var ready_code: int = 0

	func _say(d: Dictionary) -> void:
		billing_event.emit.call_deferred(JSON.stringify(d))

	func start(req: int) -> void:
		calls.append(["start"])
		_say({"kind": "ready", "req": req, "code": ready_code})

	func query(ids: String, req: int) -> void:
		var prices: Dictionary = {}
		for id: Variant in JSON.parse_string(ids):
			prices[str(id)] = "4,99 €"
		_say({"kind": "prices", "req": req, "code": 0, "prices": prices})

	func purchase(pid: String, token: String, req: int) -> void:
		calls.append(["purchase", pid, token])
		var d: Dictionary = purchase_answer.duplicate(true)
		d["kind"] = "purchase"
		d["req"] = req
		_say(d)

	func finish(txn: String, req: int) -> void:
		calls.append(["finish", txn])
		_say({"kind": "finished", "req": req, "code": 0, "txn": txn})

	func owned(req: int) -> void:
		_say({"kind": "owned", "req": req, "code": 0, "purchases": owned_list})

	func restore(req: int) -> void:
		calls.append(["restore"])
		_say({"kind": "owned", "req": req, "code": 0, "purchases": owned_list})

const GLASS: String = "de.chimora.game.glass.500"
const UID: String = "0b7c2f3e-1111-4222-8333-444455556666"

func _tx(txn: String, unfinished: bool, revoked: bool = false) -> Dictionary:
	return {"product": GLASS, "jws": "a.b.c", "txn": txn, "account": UID, "unfinished": unfinished,
		"revoked": revoked, "verified": true}

func test_buy_sends_the_account_token_and_returns_the_jws() -> void:
	var fake := FakeStoreKit.new()
	var a := AppleBillingStore.new(fake)
	assert_true(await a.connect_store())
	assert_eq(a.store_name(), "apple")
	assert_eq(await a.query([GLASS] as Array[String]), {GLASS: "4,99 €"})
	fake.purchase_answer = {"code": 0, "purchases": [_tx("2000001", true)]}
	var r: Dictionary = await a.purchase(GLASS, UID, "hash")
	assert_true(r.ok, str(r))
	assert_eq(r.receipt, {"store": "apple", "product_id": GLASS, "jws": "a.b.c", "txn": "2000001", "account": UID})
	assert_true(["purchase", GLASS, UID] in fake.calls, "appAccountToken is the account id, not the hash")
	await a.finish(r.receipt, true)
	assert_true(["finish", "2000001"] in fake.calls)

func test_cancel_pending_and_errors() -> void:
	var fake := FakeStoreKit.new()
	var a := AppleBillingStore.new(fake)
	fake.purchase_answer = {"code": 1}
	var r: Dictionary = await a.purchase(GLASS, UID, "")
	assert_true(r.cancelled)
	fake.purchase_answer = {"code": 0, "pending": true, "purchases": []}
	assert_eq((await a.purchase(GLASS, UID, "")).error, "pending")
	fake.purchase_answer = {"code": 2}
	assert_eq((await a.purchase(GLASS, UID, "")).error, "offline")

func test_no_store_when_payments_are_off() -> void:
	var fake := FakeStoreKit.new()
	fake.ready_code = 3
	var a := AppleBillingStore.new(fake)
	assert_false(await a.connect_store())
	assert_eq((await a.purchase(GLASS, UID, "")).error, "no_store")

func test_unfinished_and_restore_skip_revoked() -> void:
	var fake := FakeStoreKit.new()
	var a := AppleBillingStore.new(fake)
	fake.owned_list = [_tx("1", true), _tx("2", false), _tx("3", true, true)]
	var open: Array[Dictionary] = await a.unfinished()
	assert_eq(open.size(), 1)
	assert_eq(open[0].txn, "1")
	var all: Array[Dictionary] = await a.restore()
	assert_eq(all.size(), 2)
	assert_true(["restore"] in fake.calls)

func test_updates_outside_the_sheet_are_passed_on() -> void:
	var fake := FakeStoreKit.new()
	var a := AppleBillingStore.new(fake)
	watch_signals(a)
	fake.billing_event.emit(JSON.stringify({"kind": "update", "req": -1, "code": 0, "purchases": [_tx("9", true)]}))
	assert_signal_emitted(a, "purchase_updated")

func test_not_available_without_the_extension() -> void:
	assert_false(AppleBillingStore.available_here())
