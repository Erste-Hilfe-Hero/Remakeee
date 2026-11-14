extends GutTest
## GoogleBillingStore against a stand-in for the Android plugin (plugins/chimora_billing).

class FakePlay extends RefCounted:
	signal billing_event(text: String)
	var calls: Array = []
	var purchase_answer: Dictionary = {}
	var owned_list: Array = []
	var now: bool = false

	func _say(d: Dictionary) -> void:
		if now:
			billing_event.emit(JSON.stringify(d))
		else:
			billing_event.emit.call_deferred(JSON.stringify(d))

	func start(req: int) -> void:
		calls.append(["start"])
		_say({"kind": "ready", "req": req, "code": 0})

	func query(ids: String, req: int) -> void:
		calls.append(["query", ids])
		var prices: Dictionary = {}
		for id: Variant in JSON.parse_string(ids):
			prices[str(id)] = "2,99 €"
		_say({"kind": "prices", "req": req, "code": 0, "prices": prices})

	func purchase(pid: String, account: String, req: int) -> void:
		calls.append(["purchase", pid, account])
		var d: Dictionary = purchase_answer.duplicate(true)
		d["kind"] = "purchase"
		d["req"] = req
		_say(d)

	func owned(req: int) -> void:
		_say({"kind": "owned", "req": req, "code": 0, "purchases": owned_list})

	func finish(token: String, consume: bool, req: int) -> void:
		calls.append(["finish", token, consume])
		_say({"kind": "finished", "req": req, "code": 0})

const GLASS: String = "de.chimora.game.glass.500"
const BOX: String = "de.chimora.game.unlock.share_band"

func _store(fake: FakePlay) -> GoogleBillingStore:
	var g := GoogleBillingStore.new(fake)
	await g.connect_store()
	return g

func test_connect_query_and_buy() -> void:
	var fake := FakePlay.new()
	var g: GoogleBillingStore = await _store(fake)
	assert_true(g.is_ready())
	assert_eq(await g.query([GLASS] as Array[String]), {GLASS: "2,99 €"})
	fake.purchase_answer = {"code": 0, "purchases": [{"token": "tok1", "order": "GPA.1", "products": [GLASS], "state": 1,
		"acknowledged": false, "account": "hash"}]}
	var r: Dictionary = await g.purchase(GLASS, "uid", "hash")
	assert_true(r.ok, str(r))
	assert_eq(r.receipt, {"store": "google", "product_id": GLASS, "token": "tok1", "txn": "GPA.1", "account": "hash"})
	assert_true(["purchase", GLASS, "hash"] in fake.calls, "the account hash goes to Google")
	await g.finish(r.receipt, true)
	assert_true(["finish", "tok1", true] in fake.calls)

func test_answer_during_the_call_is_not_lost() -> void:
	var fake := FakePlay.new()
	fake.now = true
	var g: GoogleBillingStore = await _store(fake)
	assert_true(g.is_ready())

func test_cancel_pending_owned() -> void:
	var fake := FakePlay.new()
	var g: GoogleBillingStore = await _store(fake)
	fake.purchase_answer = {"code": 1, "purchases": []}
	assert_true((await g.purchase(GLASS, "", "h")).cancelled)
	fake.purchase_answer = {"code": 0, "purchases": [{"token": "t", "products": [GLASS], "state": 2}]}
	assert_eq((await g.purchase(GLASS, "", "h")).error, "pending", "paid later: nothing yet")
	fake.purchase_answer = {"code": 7}
	assert_eq((await g.purchase(GLASS, "", "h")).error, "already_owned")
	fake.purchase_answer = {"code": 12}
	assert_eq((await g.purchase(GLASS, "", "h")).error, "offline", "network error")
	fake.purchase_answer = {"code": 6}
	assert_eq((await g.purchase(GLASS, "", "h")).error, "store_error")

func test_unfinished_skips_acknowledged_unlocks() -> void:
	var fake := FakePlay.new()
	var g: GoogleBillingStore = await _store(fake)
	fake.owned_list = [
		{"token": "a", "products": [GLASS], "state": 1, "acknowledged": true},
		{"token": "b", "products": [BOX], "state": 1, "acknowledged": true},
		{"token": "c", "products": [BOX], "state": 1, "acknowledged": false},
		{"token": "d", "products": [GLASS], "state": 2, "acknowledged": false}]
	var tokens: Array = (await g.unfinished()).map(func(r: Dictionary) -> String: return r.token)
	assert_eq(tokens, ["a", "c"], "consumables until consumed, unlocks until acknowledged, never pending ones")
	assert_eq((await g.restore()).size(), 3)

func test_no_plugin_no_store() -> void:
	if GoogleBillingStore.available_here():
		return
	var g := GoogleBillingStore.new()
	assert_false(await g.connect_store())
	assert_false((await g.purchase(GLASS, "", "")).ok)
