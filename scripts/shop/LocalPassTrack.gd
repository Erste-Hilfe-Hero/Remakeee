class_name LocalPassTrack
extends RefCounted
## The pass track in the local stand-in server, same rules as
## supabase/migrations/20261127140040_pass_track.sql. Progress lives in each player's row ("pass"),
## keyed by season. tests/unit/test_pass_track.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalPassTrack:
	var s := LocalPassTrack.new()
	s._bref = weakref(backend)
	for fn: String in ["pass_state", "pass_points_add", "pass_claim"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("pass_track", s)
	return s

static func of(backend: LocalBackend) -> LocalPassTrack:
	return backend.get_meta("pass_track") if backend.has_meta("pass_track") else null

## The caller's row of the running season.
func row(uid: String) -> Dictionary:
	var all: Dictionary = (b.db.users[uid] as Dictionary).get_or_add("pass", {})
	var season: int = PassTrack.season_of(b.now())
	return all.get_or_add(str(season), {"season": season, "points": 0, "day": -1, "day_points": 0,
		"hour_at": b.now(), "hour_calls": 0, "claimed_free": 0, "claimed_premium": 0})

func _json(r: Dictionary, uid: String) -> Dictionary:
	var shop: LocalShop = LocalShop.of(b)
	var season: int = int(r.season)
	return {"ok": true, "season": season, "points": int(r.points), "tier": PassTrack.tier_for(int(r.points)),
		"tiers": PassTrack.tier_count(), "per_tier": PassTrack.per_tier(), "claimed_free": int(r.claimed_free),
		"claimed_premium": int(r.claimed_premium), "premium": shop != null and shop.pass_until(uid) > b.now(),
		"day_points": int(r.day_points) if int(r.day) == b.now() / 86400 else 0, "day_cap": PassTrack.day_cap(),
		"starts": PassTrack.season_start(season), "ends": PassTrack.season_end(season)}

func _fn_pass_state(_a: Dictionary) -> Dictionary:
	return _json(row(b.me()), b.me())

func _fn_pass_points_add(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var r: Dictionary = row(uid)
	if int(r.hour_at) < b.now() - 3600:
		r.hour_at = b.now()
		r.hour_calls = 0
	if int(r.hour_calls) >= int(PassTrack.data().get("hour_calls", 120)):
		return LocalBackend._fail("slow_down")
	var today: int = b.now() / 86400
	if int(r.day) != today:
		r.day = today
		r.day_points = 0
	var n: int = mini(PassTrack.points_for(str(a.get("p_kind", ""))) * clampi(int(a.get("p_amount", 0)), 0, 3),
		maxi(PassTrack.day_cap() - int(r.day_points), 0))
	r.points = int(r.points) + n
	r.day_points = int(r.day_points) + n
	r.hour_calls = int(r.hour_calls) + 1
	var out: Dictionary = _json(r, uid)
	out["added"] = n
	return out

func _fn_pass_claim(a: Dictionary) -> Dictionary:
	var uid: String = b.me()
	var r: Dictionary = row(uid)
	var lane: String = str(a.get("p_lane", ""))
	var tier: int = int(a.get("p_tier", 0))
	if not lane in PassTrack.LANES:
		return LocalBackend._fail("bad_lane")
	if tier < 1 or tier > PassTrack.tier_count():
		return LocalBackend._fail("bad_tier")
	var why: String = PassTrack.block_reason(_json(r, uid), tier, lane)
	if not why.is_empty():
		return LocalBackend._fail(why)
	var grants: Array = PassTrack.reward(tier, lane)
	var shop: LocalShop = LocalShop.of(b)
	var s: Dictionary = shop._shop(uid)
	var bag: Array = []
	for g: Dictionary in grants:
		match str(g.t):
			"rg":
				shop._ledger_add(uid, int(g.n), "pass_track", "pass:%d:%d:%s" % [int(r.season), tier, lane])
			"unlock":
				s.unlocks[str(g.id)] = int(s.unlocks.get(str(g.id), 0)) + 1
			"item", "coins", "spirling":
				bag.append(g.duplicate())
	if not bag.is_empty():
		s.deliveries.append({"id": shop._next_id(s), "purchase": null, "grants": bag, "claimed": false})
	r["claimed_" + lane] = int(r["claimed_" + lane]) | (1 << (tier - 1))
	return {"ok": true, "tier": tier, "lane": lane, "grants": grants.duplicate(true), "balance": shop.balance_of(uid)}
