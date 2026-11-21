class_name LocalPromo
extends RefCounted
## Promo codes in the local stand-in server, with the same rules as
## supabase/migrations/20261115100000_promo_codes.sql. Codes live in db.promo_codes
## ({code: {"reward", "max_uses", "uses", "starts_at", "ends_at", "active"}}), tests add them.
## tests/unit/test_promo_codes.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalPromo:
	var s := LocalPromo.new()
	s._bref = weakref(backend)
	backend._fns["promo_redeem"] = Callable(s, "_fn_promo_redeem")
	# The backend keeps this object alive (Callables do not hold a RefCounted).
	backend.set_meta("promo", s)
	return s

## Letters and digits only, upper case (like public._promo_norm).
static func norm(code: String) -> String:
	var out: String = ""
	for ch: String in code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

func _fn_promo_redeem(a: Dictionary) -> Dictionary:
	if not b.flag_on("promo", 2147483647):
		return LocalBackend._fail("feature_off")
	if not b._rate_ok("promo", 10):
		return LocalBackend._fail("slow_down")
	var c: String = norm(str(a.get("p_code", "")))
	var p: Variant = (b._table("promo_codes", {}) as Dictionary).get(c)
	if not p is Dictionary or not bool(p.get("active", true)) or b.now() < int(p.get("starts_at", 0)):
		return LocalBackend._fail("no_such_code")
	if p.get("ends_at") != null and b.now() >= int(p.ends_at):
		return LocalBackend._fail("code_expired")
	var used: Dictionary = b._table("promo_redemptions", {})
	if used.has(c + "|" + b.me()):
		return LocalBackend._fail("code_used")
	if p.get("max_uses") != null and int(p.get("uses", 0)) >= int(p.max_uses):
		return LocalBackend._fail("code_used_up")
	var reward: Dictionary = p.get("reward", {})
	for k: String in reward:
		if int(reward[k]) < 1 or int(reward[k]) > 999:
			return LocalBackend._fail("no_such_code")
	var r: Dictionary = b._trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), reward)
	if not bool(r.ok):
		return r
	used[c + "|" + b.me()] = b.now()
	p["uses"] = int(p.get("uses", 0)) + 1
	return {"ok": true, "rev": r.rev, "bag": reward.duplicate()}
