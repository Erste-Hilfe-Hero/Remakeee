class_name LocalRiftglass
extends RefCounted
## Riftglass sinks on the local stand-in server, with the same rules as public.rg_spend and
## public.rg_daily_claim (supabase/migrations/20261127120000_rg_sinks.sql). Spends and daily
## claims live in the player's shop row ("rg_spends", "rg_daily"); the price table is
## data/riftglass_sinks.json. tests/unit/test_riftglass_sinks.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalRiftglass:
	var s := LocalRiftglass.new()
	s._bref = weakref(backend)
	backend._fns["rg_spend"] = Callable(s, "_fn_rg_spend")
	backend._fns["rg_daily_claim"] = Callable(s, "_fn_rg_daily_claim")
	backend.set_meta("riftglass", s)
	return s

func _shop() -> LocalShop:
	return LocalShop.of(b)

func _row(uid: String) -> Dictionary:
	var s: Dictionary = _shop()._shop(uid)
	if not s.has("rg_spends"):
		s["rg_spends"] = []
	if not s.has("rg_daily"):
		s["rg_daily"] = []
	return s

## Server day (whole days of unix time; the SQL uses the Berlin calendar day).
func _day() -> int:
	return b.now() / 86400

func _used(uid: String, reason: String, ref: String, day: int = -1) -> int:
	var n: int = 0
	for x: Dictionary in _row(uid).rg_spends:
		if str(x.reason) == reason and (day < 0 and str(x.ref) == ref or day >= 0 and int(x.day) == day):
			n += 1
	return n

func _fn_rg_spend(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var reason: String = str(a.get("p_reason", ""))
	var ref: String = str(a.get("p_ref", "")).left(64)
	if not reason in RiftglassSinks.REASONS:
		return {"ok": false, "error": "unknown_reason"}
	var band: Variant = _shop().band_of(uid)
	if band != null and int(band) < 13:
		return {"ok": false, "error": "age"}
	if not b._rate_ok("rg_spend", int(RiftglassSinks.data().get("spends_per_hour", 60))):
		return {"ok": false, "error": "slow_down"}
	var s: Dictionary = RiftglassSinks.sink(reason)
	var used: int = 0
	if s.has("max_per_ref"):
		if ref.is_empty():
			return {"ok": false, "error": "bad_ref"}
		used = _used(uid, reason, ref)
		if used >= int(s.max_per_ref):
			return {"ok": false, "error": "used_up"}
	if s.has("max_per_day") and _used(uid, reason, "", _day()) >= int(s.max_per_day):
		return {"ok": false, "error": "used_up"}
	var hours: int = int(ref) if reason == "trip_skip" and ref.is_valid_int() else 0
	var price: int = RiftglassSinks.price(reason, used, hours)
	if price <= 0:
		return {"ok": false, "error": "bad_ref"}
	if price != int(a.get("p_expected", -1)):
		return {"ok": false, "error": "price_changed", "price": price}
	var bal: int = _shop().balance_of(uid)
	if bal < 0 or _shop().spent_of(uid) > _shop().cap_of(uid):
		return {"ok": false, "error": "limit_reached"}
	if bal < price:
		return {"ok": false, "error": "not_enough", "balance": bal}
	_row(uid).rg_spends.append({"reason": reason, "ref": ref, "price": price, "day": _day(), "at": b.now()})
	bal = _shop()._ledger_add(uid, -price, "sink", reason + ":" + ref)
	return {"ok": true, "balance": bal, "price": price, "used": used + 1}

func _fn_rg_daily_claim(_a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var band: Variant = _shop().band_of(uid)
	if band != null and int(band) < 13:
		return {"ok": false, "error": "age"}
	var today: int = _day()
	if today in _row(uid).rg_daily:
		return {"ok": true, "added": 0, "balance": _shop().balance_of(uid)}
	# The welcome gift cycle (20261128060000_daily_gift_cycle.sql): the step is the count of days
	# claimed so far, so missed days reset nothing.
	var taken: int = _row(uid).rg_daily.size()
	_row(uid).rg_daily.append(today)
	var n: int = DailyBoard.gift_rg(taken) if not DailyBoard.gifts().is_empty() else RiftglassSinks.daily_rg()
	var bal: int = _shop()._ledger_add(uid, n, "daily", str(today))
	return {"ok": true, "added": n, "balance": bal, "step": taken % maxi(1, DailyBoard.gifts().size()) + 1}
