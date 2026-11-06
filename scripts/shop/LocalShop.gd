class_name LocalShop
extends RefCounted
## The shop part of the local stand-in server: the same rules as
## supabase/migrations/20261110000001_shop.sql, kept in each player's row ("shop"), so moving to a
## new phone and deleting the account work like on the server. Used by tests and by builds
## without a server address. tests/unit/test_shop_server.gd checks the rules.

const CAPS: Dictionary = {13: 1500, 16: 3000, 18: 10000}
const ADULT_MAX_CENTS: int = 30000
const RAISE_WAIT: int = 7 * 86400
const PASS_DAILY_RG: int = 30
const PASS_MAX_DAYS: int = 7

## The backend this belongs to (weak, so the two do not keep each other alive).
var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef
## Shop switched off for everyone (server_config shop_open).
var closed: bool = false

static func install(backend: LocalBackend) -> LocalShop:
	var s := LocalShop.new()
	s._bref = weakref(backend)
	for fn: String in ["shop_state", "shop_set_age", "shop_withdrawal_ok", "shop_set_limit", "shop_buy", "shop_claim",
			"shop_history", "shop_pass_daily", "shop_verify"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("shop", s)
	return s

static func of(backend: LocalBackend) -> LocalShop:
	return backend.get_meta("shop") if backend.has_meta("shop") else null

func _shop(uid: String) -> Dictionary:
	var u: Dictionary = b.db.users[uid]
	if not u.has("shop"):
		u["shop"] = {"band": null, "rises_at": 0, "withdrawal_ok": false, "ledger": [], "purchases": [], "unlocks": {},
			"deliveries": [], "subs": [], "cap": null, "raise_to": null, "raise_at": 0, "next_id": 1}
	return u.shop

func _next_id(s: Dictionary) -> int:
	s.next_id = int(s.next_id) + 1
	return int(s.next_id) - 1

# --- Helpers (same names as the SQL ones) ---------------------------------------------------

## {"band": 0 | 13 | 16 | 18, "rises_at": unix of the day the next band starts or 0}.
static func band_for(year: int, month: int, today: Dictionary) -> Dictionary:
	var age: int = int(today.year) - year - (1 if int(today.month) < month else 0)
	var at: Callable = func(years: int) -> int:
		return int(Time.get_unix_time_from_datetime_dict({"year": year + years, "month": month, "day": 1}))
	if age < 13:
		return {"band": 0, "rises_at": at.call(13)}
	if age < 16:
		return {"band": 13, "rises_at": at.call(16)}
	if age < 18:
		return {"band": 16, "rises_at": at.call(18)}
	return {"band": 18, "rises_at": 0}

func _today() -> Dictionary:
	return Time.get_date_dict_from_unix_time(b.now())

func band_of(uid: String) -> Variant:
	var s: Dictionary = _shop(uid)
	if s.band == null:
		return null
	while int(s.rises_at) > 0 and int(s.rises_at) <= b.now():
		var d: Dictionary = Time.get_date_dict_from_unix_time(int(s.rises_at))
		match int(s.band):
			0:
				s.band = 13
				s.rises_at = Time.get_unix_time_from_datetime_dict({"year": int(d.year) + 3, "month": d.month, "day": 1})
			13:
				s.band = 16
				s.rises_at = Time.get_unix_time_from_datetime_dict({"year": int(d.year) + 2, "month": d.month, "day": 1})
			_:
				s.band = 18
				s.rises_at = 0
	return int(s.band)

func cap_of(uid: String) -> int:
	var band: Variant = band_of(uid)
	if band == null or int(band) < 13:
		return 0
	if int(band) < 18:
		return CAPS[int(band)]
	var s: Dictionary = _shop(uid)
	if s.raise_to != null and int(s.raise_at) <= b.now():
		s.cap = s.raise_to
		s.raise_to = null
		s.raise_at = 0
	return CAPS[18] if s.cap == null else int(s.cap)

func _month_key(t: int) -> String:
	return Time.get_date_string_from_unix_time(t).left(7)

func spent_of(uid: String) -> int:
	var n: int = 0
	var month: String = _month_key(b.now())
	for p: Dictionary in _shop(uid).purchases:
		if p.store != "riftglass" and p.status == "credited" and _month_key(int(p.at)) == month:
			n += int(p.eur_cents)
	return n

func balance_of(uid: String) -> int:
	var n: int = 0
	for row: Dictionary in _shop(uid).ledger:
		n += int(row.amount)
	return n

func _ledger_add(uid: String, amount: int, reason: String, ref: String) -> int:
	_shop(uid).ledger.append({"amount": amount, "reason": reason, "ref": ref, "at": b.now()})
	return balance_of(uid)

func pass_until(uid: String) -> int:
	var t: int = 0
	for sub: Dictionary in _shop(uid).subs:
		if sub.status in ["active", "grace"]:
			t = maxi(t, int(sub.expires_at))
	return t

func bought(uid: String, offer_id: String, per: String) -> int:
	var n: int = 0
	var week: String = WeeklyChallenge.week_key(b.now())
	var month: String = _month_key(b.now())
	for p: Dictionary in _shop(uid).purchases:
		if p.offer == offer_id and p.status == "credited":
			if per == "week" and WeeklyChallenge.week_key(int(p.at)) != week:
				continue
			if per == "month" and _month_key(int(p.at)) != month:
				continue
			n += 1
	return n

func rifts_of(uid: String) -> int:
	var n: int = 0
	var saves: Variant = b.db.users[uid].get("saves", {})
	if saves is Dictionary:
		for slot: Variant in saves:
			var d: Variant = saves[slot].get("data") if saves[slot] is Dictionary else null
			if d is Dictionary and d.get("rifts") is Array:
				n = maxi(n, (d.rifts as Array).size())
	return n

func offer_block(uid: String, o: Dictionary, choice: Variant) -> String:
	if closed:
		return "shop_closed"
	var band: Variant = band_of(uid)
	if band == null:
		return "age_needed"
	if int(band) < maxi(13, int(o.get("min_band", 13))):
		return "age"
	if not bool(o.get("ready", false)):
		return "not_available"
	if o.has("limit") and bought(uid, str(o.id), str(o.limit.get("per", "account"))) >= int(o.limit.n):
		return "offer_limit"
	var req: String = str(o.get("requires", ""))
	if req.begins_with("rifts:"):
		if rifts_of(uid) < int(req.get_slice(":", 1)):
			return "not_yet"
	elif not req.is_empty():
		return "not_yet"
	if o.has("choice") and (choice == null or not str(choice) in o.choice):
		return "choice_needed"
	return ""

func _grant(uid: String, purchase_id: int, o: Dictionary, choice: Variant) -> void:
	var s: Dictionary = _shop(uid)
	var bag: Array = []
	for g: Dictionary in o.get("grants", []):
		match str(g.t):
			"rg":
				_ledger_add(uid, int(g.n), "store", "purchase:%d" % purchase_id)
			"unlock":
				s.unlocks[str(g.id)] = int(s.unlocks.get(str(g.id), 0)) + 1
			"item", "coins":
				bag.append(g.duplicate())
			"choice":
				bag.append({"t": "item", "id": str(choice), "n": int(g.get("n", 1))})
	if not bag.is_empty():
		s.deliveries.append({"id": _next_id(s), "purchase": purchase_id, "grants": bag, "claimed": false})

# --- Player functions ------------------------------------------------------------------------

func _fn_shop_state(_a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var s: Dictionary = _shop(uid)
	var cap: int = cap_of(uid)
	var spent: int = spent_of(uid)
	var bal: int = balance_of(uid)
	var counts: Dictionary = {}
	for o: Dictionary in ShopCatalog.offers():
		if o.has("limit"):
			counts[str(o.id)] = bought(uid, str(o.id), str(o.limit.get("per", "account")))
	var pending: int = 0
	for d: Dictionary in s.deliveries:
		if not bool(d.claimed):
			pending += 1
	var until: int = pass_until(uid)
	return {"open": not closed, "band": band_of(uid), "withdrawal_ok": bool(s.withdrawal_ok), "balance": bal,
		"cap_cents": cap, "spent_cents": spent, "locked": bal < 0 or spent > cap, "raise_to_cents": s.raise_to,
		"raise_at": int(s.raise_at) if s.raise_to != null else null, "pass_until": until if until > 0 else null,
		"pass_active": until > b.now(), "unlocks": (s.unlocks as Dictionary).duplicate(), "bought": counts,
		"pending": pending, "rifts": rifts_of(uid), "account_token": uid, "account_hash": uid.sha256_text(),
		"server_time": b.now()}

func _fn_shop_set_age(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var y: int = int(a.get("p_year", 0))
	var m: int = int(a.get("p_month", 0))
	var today: Dictionary = _today()
	if m < 1 or m > 12 or y < int(today.year) - 120 or y > int(today.year) or (y == int(today.year) and m > int(today.month)):
		return {"ok": false, "error": "bad_date"}
	var nb: Dictionary = band_for(y, m, today)
	var cur: Variant = band_of(uid)
	if cur != null and int(nb.band) > int(cur):
		return {"ok": false, "error": "age_locked", "band": cur}
	var s: Dictionary = _shop(uid)
	s.band = int(nb.band)
	s.rises_at = int(nb.rises_at)
	return {"ok": true, "band": int(nb.band)}

func _fn_shop_withdrawal_ok(_a: Dictionary) -> Dictionary:
	var s: Dictionary = _shop(b.me())
	if s.band == null:
		return {"ok": false}
	s.withdrawal_ok = true
	return {"ok": true}

func _fn_shop_set_limit(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var want: int = int(a.get("p_cap_cents", -1))
	var cur: int = cap_of(uid)
	var band: Variant = band_of(uid)
	if band == null or int(band) < 18:
		return {"ok": false, "error": "fixed_limit"}
	if want < 0 or want > ADULT_MAX_CENTS:
		return {"ok": false, "error": "bad_limit"}
	var s: Dictionary = _shop(uid)
	if want <= cur:
		s.cap = want
		s.raise_to = null
		s.raise_at = 0
		return {"ok": true, "cap_cents": want}
	s.cap = cur
	s.raise_to = want
	s.raise_at = b.now() + RAISE_WAIT
	return {"ok": true, "cap_cents": cur, "raise_to_cents": want, "raise_at": s.raise_at}

func _fn_shop_buy(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var id: String = str(a.get("p_offer", ""))
	var o: Dictionary = ShopCatalog.offer(id)
	if o.is_empty():
		return {"ok": false, "error": "unknown_offer"}
	var price: int = int(o.get("rg_price", 0))
	if price <= 0:
		return {"ok": false, "error": "not_for_riftglass"}
	if price != int(a.get("p_expected_price", -1)):
		return {"ok": false, "error": "price_changed", "price": price}
	var choice: Variant = a.get("p_choice")
	var why: String = offer_block(uid, o, choice)
	if not why.is_empty():
		return {"ok": false, "error": why}
	var bal: int = balance_of(uid)
	if bal < 0 or spent_of(uid) > cap_of(uid):
		return {"ok": false, "error": "limit_reached"}
	if bal < price:
		return {"ok": false, "error": "not_enough", "balance": bal}
	var s: Dictionary = _shop(uid)
	var pid: int = _next_id(s)
	s.purchases.append({"id": pid, "store": "riftglass", "txn": "", "product": "", "offer": id, "eur_cents": 0,
		"rg": price, "choice": choice, "status": "credited", "at": b.now()})
	bal = _ledger_add(uid, -price, "spend", "purchase:%d" % pid)
	_grant(uid, pid, o, choice)
	return {"ok": true, "balance": bal, "purchase": pid}

func _fn_shop_claim(_a: Dictionary) -> Array:
	var out: Array = []
	for d: Dictionary in _shop(b.me()).deliveries:
		if not bool(d.claimed):
			d.claimed = true
			out.append({"id": d.id, "grants": (d.grants as Array).duplicate(true)})
	return out

func _fn_shop_history(_a: Dictionary) -> Array:
	var out: Array = []
	for p: Dictionary in _shop(b.me()).purchases:
		out.push_front({"id": p.id, "offer": p.offer, "store": p.store, "eur_cents": p.eur_cents, "rg": p.rg,
			"status": p.status, "at": p.at})
	return out.slice(0, 100)

func _fn_shop_pass_daily(_a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var sub: Dictionary = {}
	for x: Dictionary in _shop(uid).subs:
		if x.status in ["active", "grace"] and int(x.expires_at) > b.now() and (sub.is_empty() or int(x.expires_at) > int(sub.expires_at)):
			sub = x
	if sub.is_empty():
		return {"ok": false, "error": "no_pass"}
	var today: int = b.now() / 86400
	var days: int = 1 if sub.get("paid_day") == null else mini(today - int(sub.paid_day), PASS_MAX_DAYS)
	days = mini(days, PASS_MAX_DAYS)
	if days <= 0:
		return {"ok": true, "added": 0, "balance": balance_of(uid)}
	sub.paid_day = today
	var bal: int = _ledger_add(uid, days * PASS_DAILY_RG, "pass_daily", str(today))
	return {"ok": true, "added": days * PASS_DAILY_RG, "balance": bal}

## Test store only: LocalBilling sends a fake receipt; the local server "checks" it and credits.
## On the real server this is the billing service (server/billing) with Apple's and Google's APIs.
func _fn_shop_verify(a: Dictionary) -> Dictionary:
	var receipt: Dictionary = a.get("p_receipt", {}) if a.get("p_receipt") is Dictionary else {}
	if str(receipt.get("store", "")) != "local" or str(receipt.get("account", "")) != b.me().sha256_text():
		return {"ok": false, "error": "bad_receipt"}
	var o: Dictionary = ShopCatalog.by_product(str(receipt.get("product_id", "")))
	var r: Dictionary = credit(b.me(), "local", str(receipt.get("txn", "")), str(receipt.get("product_id", "")),
		int(o.get("eur_cents", 0)), a.get("p_choice"))
	if r.ok and str(o.get("store_type", "")) == "subscription":
		sub_set(b.me(), "local", str(receipt.txn), str(receipt.product_id), b.now() + 30 * 86400, "active", true)
	return r

# --- Billing service functions (service role on the server) ----------------------------------

func _find_txn(txn: String) -> Array:
	for uid: String in b.db.users:
		var u: Dictionary = b.db.users[uid]
		if not u.has("shop"):
			continue
		for p: Dictionary in u.shop.purchases:
			if str(p.txn) == txn and not txn.is_empty():
				return [uid, p]
	return []

func credit(uid: String, store: String, txn: String, product_id: String, eur_cents: int, choice: Variant = null) -> Dictionary:
	if txn.is_empty():
		return {"ok": false, "error": "bad_receipt"}
	var prev: Array = _find_txn(txn)
	if not prev.is_empty():
		return {"ok": true, "duplicate": true, "purchase": prev[1].id, "user": prev[0]}
	var o: Dictionary = ShopCatalog.by_product(product_id)
	if o.is_empty():
		return {"ok": false, "error": "unknown_product"}
	var why: String = offer_block(uid, o, choice)
	if why in ["age", "age_needed"]:
		return {"ok": false, "error": why}
	if o.has("choice") and (choice == null or not str(choice) in o.choice):
		choice = o.choice[0]
	var s: Dictionary = _shop(uid)
	var pid: int = _next_id(s)
	s.purchases.append({"id": pid, "store": store, "txn": txn, "product": product_id, "offer": str(o.id),
		"eur_cents": maxi(eur_cents, 0), "rg": 0, "choice": choice, "status": "credited", "at": b.now()})
	_grant(uid, pid, o, choice)
	return {"ok": true, "purchase": pid, "balance": balance_of(uid), "locked": spent_of(uid) > cap_of(uid)}

func refund(store: String, txn: String) -> Dictionary:
	var hit: Array = _find_txn(txn)
	if hit.is_empty() or str(hit[1].store) != store:
		return {"ok": false, "error": "unknown_transaction"}
	var uid: String = hit[0]
	var p: Dictionary = hit[1]
	if p.status == "refunded":
		return {"ok": true, "duplicate": true}
	p.status = "refunded"
	var s: Dictionary = _shop(uid)
	for g: Dictionary in ShopCatalog.offer(str(p.offer)).get("grants", []):
		if str(g.t) == "rg":
			_ledger_add(uid, -int(g.n), "refund", "purchase:%d" % int(p.id))
		elif str(g.t) == "unlock":
			var n: int = int(s.unlocks.get(str(g.id), 0)) - 1
			if n > 0:
				s.unlocks[str(g.id)] = n
			else:
				s.unlocks.erase(str(g.id))
	s.deliveries = (s.deliveries as Array).filter(func(d: Dictionary) -> bool: return int(d.purchase) != int(p.id) or bool(d.claimed))
	for sub: Dictionary in s.subs:
		if str(sub.txn) == txn:
			sub.status = "revoked"
			sub.expires_at = mini(int(sub.expires_at), b.now())
	return {"ok": true, "balance": balance_of(uid)}

func sub_set(uid: String, store: String, txn: String, product_id: String, expires_at: int, status: String, auto_renew: bool) -> Dictionary:
	if not status in ["active", "grace", "expired", "revoked", "billing_retry"]:
		return {"ok": false, "error": "bad_status"}
	var s: Dictionary = _shop(uid)
	for sub: Dictionary in s.subs:
		if str(sub.txn) == txn:
			sub.expires_at = expires_at
			sub.status = status
			sub.auto_renew = auto_renew
			return {"ok": true}
	s.subs.append({"txn": txn, "store": store, "product": product_id, "expires_at": expires_at, "status": status,
		"auto_renew": auto_renew, "paid_day": null})
	return {"ok": true}
