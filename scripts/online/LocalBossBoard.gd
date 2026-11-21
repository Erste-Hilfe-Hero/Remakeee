class_name LocalBossBoard
extends RefCounted
## Weekly boss boards by rounds (KAMPF_PLAN_1000 item 435) in the local stand-in server, with the
## same rules as supabase/migrations/20261114032010_kampf_k32.sql: the fewest rounds a player
## needed this week to clear the heart stair (all Rift hearts) or the week's prism heart, both
## battle halls where everyone meets the same hearts with the same seed. Names only for you and
## your friends. tests/unit/test_kampf_k32.gd checks it.

## Most rounds a clear can take per board: BattleModel.BOSS_ROUND_LIMIT per heart.
const MAX_ROUNDS: Dictionary = {"boss_tower": 90, "prism_boss": 30}

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalBossBoard:
	var s := LocalBossBoard.new()
	s._bref = weakref(backend)
	for fn: String in ["boss_submit", "boss_board"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("boss_board", s)
	return s

func _fn_boss_submit(a: Dictionary) -> Dictionary:
	if not b.flag_on("boss_board", 2147483647):
		return b._fail("feature_off")
	var kind: String = str(a.get("p_kind", ""))
	if not MAX_ROUNDS.has(kind):
		return b._fail("bad_kind")
	var n: int = int(a.get("p_rounds", -1))
	if n < 1 or n > int(MAX_ROUNDS[kind]):
		return b._fail("implausible")
	if not b._rate_ok("boss_board", 60):
		return b._fail("slow_down")
	var rows: Dictionary = b._table("boss_scores", {})
	var key: String = "%s|%s|%s" % [b._week(), kind, b.me()]
	var cur: Variant = rows.get(key)
	if cur == null or n < int(cur.v):
		rows[key] = {"week": b._week(), "kind": kind, "u": b.me(), "v": n, "at": b.now()}
	return {"ok": true}

func _fn_boss_board(a: Dictionary) -> Dictionary:
	if not b.flag_on("boss_board", 2147483647):
		return b._fail("feature_off")
	var kind: String = str(a.get("p_kind", ""))
	if not MAX_ROUNDS.has(kind):
		return b._fail("bad_kind")
	var u: String = b.me()
	var friends_only: bool = bool(a.get("p_friends", true))
	var rows: Array = []
	for r: Dictionary in (b._table("boss_scores", {}) as Dictionary).values():
		if r.week != b._week() or r.kind != kind or not b.db.users.has(r.u) or b.is_blocked(u, r.u):
			continue
		if friends_only and r.u != u and not b.is_friend(u, r.u):
			continue
		rows.append(r.duplicate())
	return {"ok": true, "week": b._week(), "kind": kind, "rows": b._board(rows, true)}
