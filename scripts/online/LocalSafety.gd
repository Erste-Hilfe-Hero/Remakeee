class_name LocalSafety
extends RefCounted
## Safety and fairness (Online 100, area 9) in the local stand-in server, with the same rules as
## supabase/migrations/20261113000010_safety.sql: parent switches (parent_get, parent_set) and the
## report straight after a battle (report_battle). The gates themselves sit in LocalBackend
## (parent_off). tests/unit/test_safety.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalSafety:
	var s := LocalSafety.new()
	s._bref = weakref(backend)
	for fn: String in ["parent_get", "parent_set", "report_battle"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("safety", s)
	return s

func _fn_parent_get(_a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var shop: LocalShop = LocalShop.of(b)
	var band: Variant = shop.band_of(u) if shop != null else null
	var c: Dictionary = b.safety_cfg()
	return {"ok": true, "off": b.parent_off_list(u), "young": band != null and int(band) < int(c.young_band),
		"custom": b.profile_of(u).get("parent_off") is Array, "keys": (c.parent_keys as Array).duplicate()}

func _fn_parent_set(a: Dictionary) -> Dictionary:
	var list: Variant = a.get("p_off")
	if not SafetyRules.keys_ok(b.safety_cfg(), list):
		return LocalBackend._fail("bad_key")
	var keys: Array = []
	for k: Variant in list:
		if not keys.has(k):
			keys.append(str(k))
	b.profile_of(b.me())["parent_off"] = keys
	return {"ok": true, "off": keys.duplicate(), "flags": b.active_flags(int(a.get("p_version", 0)))}

func _fn_report_battle(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var ref: String = str(a.get("p_ref", ""))
	if RegEx.create_from_string("^[0-9]{1,18}$").search(ref) == null:
		return LocalBackend._fail("no_such_battle")
	var kind: String = str(a.get("p_kind", ""))
	var t: String = ""
	if kind == "league":
		var m: Variant = (b._table("league_matches", {}) as Dictionary).get(str(int(ref)))
		t = str(m.get("opponent", "")) if m != null and str(m.user) == u else ""
	elif kind == "duel":
		var d: Variant = (b._table("live_duels", {}) as Dictionary).get(str(int(ref)))
		if d != null and (d.a == u or d.b == u):
			t = str(d.b if d.a == u else d.a)
	else:
		return LocalBackend._fail("bad_context")
	if t.is_empty() or t == u or not b.db.users.has(t):
		return LocalBackend._fail("no_such_battle")
	if not b._rate_ok("report", int(b.safety_cfg().reports_per_hour)):
		return LocalBackend._fail("slow_down")
	var id: int = b._next_id("report")
	(b._table("reports", []) as Array).append({"id": id, "reporter": u, "target": t, "target_name": b.profile_of(t).name,
		"reason": clampi(int(a.get("p_reason", 3)), 0, 3), "context": kind, "object_id": ref, "status": "open",
		"action": "", "at": b.now()})
	return {"ok": true, "report_id": id}
