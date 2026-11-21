class_name LocalClimb
extends RefCounted
## Weekly climb boards for the lighthouse stair and the echo tower (KAMPF_PLAN_1000 items 512, 553)
## in the local stand-in server, with the same rules as
## supabase/migrations/20261113207070_climb_boards.sql. tests/unit/test_climb_boards.gd checks it.

## Highest floor per climb kind.
const MAX_FLOOR: Dictionary = {"stair": 30, "tower": 1000}

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalClimb:
	var s := LocalClimb.new()
	s._bref = weakref(backend)
	for fn: String in ["climb_submit", "climb_board"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("climb", s)
	return s

func _fn_climb_submit(a: Dictionary) -> Dictionary:
	if not b.flag_on("climb_board", 2147483647):
		return b._fail("feature_off")
	var kind: String = str(a.get("p_kind", ""))
	if not MAX_FLOOR.has(kind):
		return b._fail("bad_kind")
	var fl: int = int(a.get("p_floor", -1))
	if fl < 1 or fl > int(MAX_FLOOR[kind]):
		return b._fail("implausible")
	if not b._rate_ok("climb", 60):
		return b._fail("slow_down")
	var rows: Dictionary = b._table("climb_scores", {})
	var key: String = "%s|%s|%s" % [b._week(), kind, b.me()]
	var cur: Variant = rows.get(key)
	if cur == null or fl > int(cur.v):
		rows[key] = {"week": b._week(), "kind": kind, "u": b.me(), "v": fl, "at": b.now()}
	return {"ok": true}

func _fn_climb_board(a: Dictionary) -> Dictionary:
	if not b.flag_on("climb_board", 2147483647):
		return b._fail("feature_off")
	var kind: String = str(a.get("p_kind", ""))
	if not MAX_FLOOR.has(kind):
		return b._fail("bad_kind")
	var u: String = b.me()
	var friends_only: bool = bool(a.get("p_friends", true))
	var rows: Array = []
	for r: Dictionary in (b._table("climb_scores", {}) as Dictionary).values():
		if r.week != b._week() or r.kind != kind or not b.db.users.has(r.u) or b.is_blocked(u, r.u):
			continue
		if friends_only and r.u != u and not b.is_friend(u, r.u):
			continue
		rows.append(r.duplicate())
	return {"ok": true, "week": b._week(), "kind": kind, "rows": b._board(rows, false)}
