class_name LocalLiveMore
extends RefCounted
## The referee for live duels (Online 100, point 3) and borrowed Spirlings in a live duel or a raid
## attempt (45) in the local stand-in server, with the same rules as
## supabase/migrations/20261113000040_live_referee.sql. tests/unit/test_live_referee.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalLiveMore:
	var s := LocalLiveMore.new()
	s._bref = weakref(backend)
	for fn: String in ["live_finish", "live_borrow", "raid_start_loan"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("live_more", s)
	return s

# --- 3: the referee plays the duel again -----------------------------------------------------------

## What the referee gets for duel [param d]: seed, picked teams and the rounds up to [param last].
func expect(d: Dictionary, last: int) -> Dictionary:
	var moves: Dictionary = {}
	for key: String in (d.moves as Dictionary):
		if int(key) <= last:
			moves[key] = (d.moves[key] as Array).duplicate(true)
	return {"live": true, "seed": d.seed, "teams": _teams(d), "moves": moves}

func _teams(d: Dictionary) -> Array:
	var teams: Array = []
	if d.pick[0] != null and d.pick[1] != null:
		for side: int in 2:
			var rows: Array = []
			for i: Variant in d.pick[side]:
				rows.append((d.show[side][int(i)] as Dictionary).duplicate(true))
			teams.append(rows)
	return teams

## Like public._live_judged: over with a winner, not over yet, or no winner when it cannot be played.
func judged(d: Dictionary, result: Dictionary) -> void:
	if d.state != "running":
		return
	var detail: Dictionary = result.get("detail", {})
	if str(result.get("verdict", "")) == BattleReferee.OK and bool(detail.get("finished", false)) and int(detail.get("winner", -2)) in [-1, 0, 1]:
		d.state = "done"
		d.reason = "played"
		d.winner = int(detail.winner)
	elif str(result.get("verdict", "")) == BattleReferee.OK:
		d.deadline = b.now() + int(b.live_cfg().turn_seconds)
	else:
		d.state = "done"
		d.reason = "disputed"
		d.winner = -1

## The winner a phone reports is only kept as a note; the referee decides.
func _fn_live_finish(a: Dictionary) -> Dictionary:
	var d: Variant = b._live_mine(a)
	if d == null:
		return LocalBackend._fail("no_such_duel")
	if d.state != "running":
		return LocalBackend._fail("duel_closed")
	var last: int = int(d.round) - 1
	if last < 1 or last <= int(d.get("judged_round", 0)):
		return LocalBackend._fail("not_over")
	d["judged_round"] = last
	d.report[b._live_side(d)] = int(a.get("p_winner", -1)) if a.get("p_winner") != null else -1
	judged(d, BattleReferee.check({}, {"expect": expect(d, last)}))
	return b._live_out(d)

# --- 45: a borrowed Spirling in a live duel and in a raid attempt ----------------------------------

## The unused loan [param id] of the player: {"loan": row} or {"error": code} (like public._lend_take).
func _take(id: Variant) -> Dictionary:
	if not b.flag_on("lend", 2147483647):
		return {"error": "feature_off"}
	var l: Variant = (b.get_meta("trade_gifts") as LocalTradeGifts)._loans().get(str(int(id)))
	if l == null or l.borrower != b.me() or b.is_blocked(b.me(), l.lender) or Database.species(str(l.mon.get("species", ""))) == null:
		return {"error": "no_such_loan"}
	if l.state != "lent":
		return {"error": "used"}
	return {"loan": l}

func _fn_live_borrow(a: Dictionary) -> Dictionary:
	var d: Variant = b._live_mine(a)
	if d == null:
		return LocalBackend._fail("no_such_duel")
	var side: int = b._live_side(d)
	if d.state != "picking" or d.pick[side] != null:
		return LocalBackend._fail("duel_closed")
	for row: Dictionary in d.show[side]:
		if row.has("loan"):
			return LocalBackend._fail("used")
	var t: Dictionary = _take(a.get("p_loan", 0))
	if t.has("error"):
		return LocalBackend._fail(str(t.error))
	var mon: Dictionary = t.loan.mon
	var moves: Array = []
	for m: Variant in (mon.get("moves", []) as Array if mon.get("moves") is Array else []):
		if m is String and moves.size() < 4:
			moves.append(m)
	(d.show[side] as Array).append({"species": str(mon.species), "level": clampi(int(mon.get("level", 1)), 1, b.config_int("level_max", 60)),
		"moves": moves, "loan": true})
	t.loan.state = "used"
	t.loan.used_for = "live_duel"
	return b._live_out(d)

func _fn_raid_start_loan(a: Dictionary) -> Dictionary:
	var t: Dictionary = _take(a.get("p_loan") if a.get("p_loan") != null else -1)
	var e: String = b._raid_check(b.me())
	if not e.is_empty():
		return LocalBackend._fail(e)
	if t.has("error"):
		return LocalBackend._fail(str(t.error))
	var sp: String = str(t.loan.mon.species)
	var pick: Variant = a.get("p_pick")
	if pick is Array:
		if (pick as Array).size() > 4:
			return LocalBackend._fail("bad_team")
		for p: Variant in pick:
			if (str(p.get("species", "")) if p is Dictionary else str(p)) == sp:
				return LocalBackend._fail("duplicate_species")
	var out: Dictionary = b._fn_raid_start(a)
	if not bool(out.get("ok", false)):
		return out
	var aid: int = int(out.attempt_id)
	var at: Dictionary = b._table("raid_attempts", {})[str(aid)]
	(at.teams[0] as Array).append(LeagueRules.fair_row(sp, t.loan.mon.get("moves", []) if t.loan.mon.get("moves") is Array else []))
	t.loan.state = "used"
	t.loan.used_for = "raid"
	out = b._raid_expect(at)
	out.merge({"ok": true, "attempt_id": aid})
	return out
