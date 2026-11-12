class_name LocalRaidBund
extends RefCounted
## Raid search with a random group (Online 100 point 25), Echo teams for free places (26), role
## signs (27), the bund house (35) and bund against bund on weekends (37) in the local stand-in
## server, with the same rules as supabase/migrations/20261113000020_raid_bund_more.sql. Bund rank
## perks (34) live in LocalBackend's bund functions. tests/unit/test_raid_bund_more.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalRaidBund:
	var s := LocalRaidBund.new()
	s._bref = weakref(backend)
	for fn: String in ["raid_find", "raid_find_cancel", "raid_role", "bund_house", "bund_house_set", "bund_war_info",
			"bund_war_join", "bund_war_fight"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("raid_bund", s)
	return s

# --- 25, 26: random groups ------------------------------------------------------------------------

func _queue() -> Dictionary:
	return b._table("raid_queue", {})

func _fn_raid_find(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var e: String = b._raid_check(u)
	if not e.is_empty():
		return b._fail(e)
	var rc: Dictionary = b.raid_cfg()
	var tier: Variant = a.get("p_tier", 1)
	if not RaidRules.tier_ok(rc, tier):
		return b._fail("bad_tier")
	var role: Variant = a.get("p_role", "")
	if not RaidRules.role_ok(rc, role):
		return b._fail("bad_role")
	if not b._rate_ok("raid_find", 400):
		return b._fail("slow_down")
	var q: Dictionary = _queue()
	var fresh: int = b.now() - 60 * int(rc.get("queue_minutes", 10))
	var mine: Variant = q.get(u)
	if mine is Dictionary and int(mine.get("raid", 0)) > 0:
		q.erase(u)
		return {"ok": true, "found": true, "raid": int(mine.raid), "echoes": int(b.db.raids[str(mine.raid)].get("echoes", 0))}
	var waited: int = 0
	if not mine is Dictionary or int(mine.tier) != int(tier) or int(mine.at) < fresh:
		q[u] = {"tier": int(tier), "role": role, "at": b.now(), "raid": 0}
	else:
		mine.role = role
		waited = b.now() - int(mine.at)
	var others: Array = []
	for x: String in q:
		var w: Dictionary = q[x]
		if x != u and int(w.tier) == int(tier) and int(w.raid) == 0 and int(w.at) >= fresh and not b.is_blocked(u, x) \
				and b._raid_check(x).is_empty():
			others.append(x)
	others.sort_custom(func(p: String, r: String) -> bool: return int(q[p].at) < int(q[r].at))
	others = others.slice(0, 3)
	var echoes: int = RaidRules.group_echoes(rc, others.size(), waited)
	if echoes < 0:
		return {"ok": true, "found": false, "waiting": others.size(), "waited": waited}
	var made: Dictionary = b.raid_new([u] + others, int(tier), echoes)
	if made.is_empty():
		return b._fail("no_guardian")
	var mem: Dictionary = b._raid_members(str(made.id))
	for x: String in [u] + others:
		mem[x].role = str(q[x].role)
	for x: String in others:
		q[x].raid = int(made.id)
	q.erase(u)
	return {"ok": true, "found": true, "raid": int(made.id), "echoes": echoes}

func _fn_raid_find_cancel(_a: Dictionary) -> Dictionary:
	var v: Variant = _queue().get(b.me())
	if v is Dictionary and int(v.raid) == 0:
		_queue().erase(b.me())
	return {"ok": true}

# --- 27: role signs -------------------------------------------------------------------------------

func _fn_raid_role(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var e: String = b._raid_check(u)
	if not e.is_empty():
		return b._fail(e)
	var role: Variant = a.get("p_role", "")
	if not RaidRules.role_ok(b.raid_cfg(), role):
		return b._fail("bad_role")
	var mem: Dictionary = b._raid_members(str(int(a.get("p_raid", 0))))
	if not mem.has(u):
		return b._fail("no_such_raid")
	mem[u].role = role
	return {"ok": true, "role": role}

# --- 35: the bund house ---------------------------------------------------------------------------

func _my_bund() -> Variant:
	var e: String = b._bund_check(b.me())
	if not e.is_empty():
		return b._fail(e)
	var bund: String = b._bund_of(b.me())
	return bund if not bund.is_empty() else b._fail("no_bund")

func _fn_bund_house(_a: Dictionary) -> Dictionary:
	var v: Variant = _my_bund()
	if v is Dictionary:
		return v
	var bund: String = v
	var u: String = b.me()
	var row: Dictionary = b.db.bunds[bund]
	var lvl: int = b.bund_level(bund)
	var members: Array = []
	for x: String in b._bund_list(bund):
		var p: Dictionary = b.profile_of(x)
		members.append({"name": p.name, "role": b._bund_role(x), "me": x == u, "online": int(p.get("last_seen", 0)) > b.now() - 300})
	return {"ok": true, "name": row.name, "level": lvl, "house": (row.get("house", []) as Array).duplicate(),
		"slots": BundRules.house_slots(b.bund_cfg(), lvl), "war_wins": int(row.get("war_wins", 0)),
		"can_edit": b._bund_role(u) in ["leader", "helper"], "decor": BundRules.decor_open(b.bund_cfg(), lvl), "members": members}

func _fn_bund_house_set(a: Dictionary) -> Dictionary:
	var v: Variant = _my_bund()
	if v is Dictionary:
		return v
	var bund: String = v
	if not b._bund_role(b.me()) in ["leader", "helper"]:
		return b._fail("not_allowed")
	var house: Variant = a.get("p_house")
	if not BundRules.house_ok(b.bund_cfg(), b.bund_level(bund), house):
		return b._fail("bad_decor")
	b.db.bunds[bund]["house"] = (house as Array).duplicate()
	return {"ok": true, "house": (house as Array).duplicate()}

# --- 37: bund against bund ------------------------------------------------------------------------

func _war_day() -> bool:
	return BundRules.war_day(b.bund_cfg(), b.now())

func _war_size() -> int:
	return int(b.bund_cfg().get("war_size", 5))

func _fighters(week: String, bund: String) -> Array:
	var out: Array = []
	for f: Dictionary in (b._table("bund_war_fighters", {}) as Dictionary).values():
		if f.week == week and str(f.bund) == bund:
			out.append(f)
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.slot) < int(q.slot))
	return out

## The war of [param bund] this week as [id, row], or [].
func _war_of(bund: String) -> Array:
	var wars: Dictionary = b._table("bund_wars", {})
	for id: String in wars:
		var w: Dictionary = wars[id]
		if w.week == b._week() and (str(w.a) == bund or str(w.b) == bund):
			return [id, w]
	return []

func _pair(bund: String) -> void:
	var wk: String = b._week()
	if _fighters(wk, bund).size() < _war_size() or not _war_of(bund).is_empty():
		return
	var mine: int = int(b.db.bunds[bund].get("xp", 0))
	var best: String = ""
	for o: String in b._table("bunds", {}):
		if o == bund or int(b.db.bunds[o].dissolve_at) > 0 or _fighters(wk, o).size() < _war_size() or not _war_of(o).is_empty():
			continue
		var d: int = absi(int(b.db.bunds[o].get("xp", 0)) - mine)
		if best.is_empty() or d < absi(int(b.db.bunds[best].get("xp", 0)) - mine) \
				or (d == absi(int(b.db.bunds[best].get("xp", 0)) - mine) and int(o) < int(best)):
			best = o
	if not best.is_empty():
		(b._table("bund_wars", {}) as Dictionary)[str(b._next_id("bund_war"))] = {"week": wk, "a": bund, "b": best,
			"settled": false, "winner": ""}

func _fights(war: String) -> Array:
	return (b._table("bund_war_fights", {}) as Dictionary).values().filter(func(f: Dictionary) -> bool: return str(f.war) == war)

func _settle(war: String) -> void:
	var w: Dictionary = b.db.bund_wars[war]
	if bool(w.settled):
		return
	var fs: Array = _fights(war)
	if w.week == b._week() and _war_day() and fs.filter(func(f: Dictionary) -> bool: return f.state == "done").size() < 2 * _war_size():
		return
	var wa: int = fs.filter(func(f: Dictionary) -> bool: return f.side == "a" and bool(f.won)).size()
	var wb: int = fs.filter(func(f: Dictionary) -> bool: return f.side == "b" and bool(f.won)).size()
	w.settled = true
	w.winner = str(w.a) if wa > wb else (str(w.b) if wb > wa else "")
	var c: Dictionary = b.bund_cfg()
	for side: String in ["a", "b"]:
		var id: String = str(w[side])
		if not b.db.bunds.has(id):
			continue
		var row: Dictionary = b.db.bunds[id]
		var won: bool = w.winner == id
		row["xp"] = int(row.get("xp", 0)) + (int(c.get("war_win_xp", 300)) if won else int(c.get("war_xp", 100)))
		row["war_wins"] = int(row.get("war_wins", 0)) + (1 if won else 0)

func _result(war: String, side: String, slot: int) -> Variant:
	for f: Dictionary in _fights(war):
		if f.side == side and int(f.slot) == slot:
			return "pending" if f.state != "done" else ("won" if bool(f.won) else "lost")
	return null

func _fn_bund_war_info(_a: Dictionary) -> Dictionary:
	var v: Variant = _my_bund()
	if v is Dictionary:
		return v
	var bund: String = v
	var u: String = b.me()
	var wk: String = b._week()
	for id: String in b._table("bund_wars", {}):
		var w: Dictionary = b.db.bund_wars[id]
		if (str(w.a) == bund or str(w.b) == bund) and not bool(w.settled):
			_settle(id)
	var fighters: Array = []
	for f: Dictionary in _fighters(wk, bund):
		fighters.append({"slot": int(f.slot), "name": b.profile_of(f.user).name, "me": f.user == u})
	var out: Dictionary = {"ok": true, "day": _war_day(), "size": _war_size(), "days": (b.bund_cfg().get("war_days", [6, 7]) as Array).duplicate(),
		"joined": (b._table("bund_war_fighters", {}) as Dictionary).has(wk + "|" + u), "fighters": fighters, "war": null}
	var wv: Array = _war_of(bund)
	if wv.is_empty():
		return out
	var w: Dictionary = wv[1]
	var my: String = "a" if str(w.a) == bund else "b"
	var other: String = "b" if my == "a" else "a"
	var foe: String = str(w[other])
	var places: Array = []
	var mine_f: Array = _fighters(wk, bund)
	var foe_f: Array = _fighters(wk, foe)
	for s: int in range(1, _war_size() + 1):
		places.append({"slot": s, "mine": b.profile_of(mine_f[s - 1].user).name if s <= mine_f.size() else null,
			"foe": b.profile_of(foe_f[s - 1].user).name if s <= foe_f.size() else null,
			"mine_result": _result(wv[0], my, s), "foe_result": _result(wv[0], other, s)})
	var fs: Array = _fights(wv[0])
	out.war = {"id": int(wv[0]), "settled": w.settled,
		"result": null if not bool(w.settled) else ("won" if w.winner == bund else ("draw" if str(w.winner).is_empty() else "lost")),
		"foe": {"name": b.db.bunds[foe].name, "level": b.bund_level(foe)} if b.db.bunds.has(foe) else null,
		"wins": fs.filter(func(f: Dictionary) -> bool: return f.side == my and bool(f.won)).size(),
		"foe_wins": fs.filter(func(f: Dictionary) -> bool: return f.side == other and bool(f.won)).size(), "places": places}
	return out

func _fn_bund_war_join(a: Dictionary) -> Dictionary:
	var v: Variant = _my_bund()
	if v is Dictionary:
		return v
	var bund: String = v
	var u: String = b.me()
	var wk: String = b._week()
	if not _war_day():
		return b._fail("war_closed")
	var t: Dictionary = b._table("bund_war_fighters", {})
	if t.has(wk + "|" + u):
		return b._fail("joined")
	var n: int = _fighters(wk, bund).size()
	if not _war_of(bund).is_empty() or n >= _war_size():
		return b._fail("war_full")
	var built: Dictionary = LeagueRules.build_team(b.profile_of(u).get("team", []), LeagueRules.FAIR, a.get("p_pick"),
		b.config_int("league_fair_ring", 50), b.config_int("level_max", 60))
	if built.has("error"):
		return b._fail(str(built.error))
	t[wk + "|" + u] = {"week": wk, "bund": bund, "user": u, "slot": n + 1, "team": built.team}
	_pair(bund)
	return _fn_bund_war_info({})

## The battle setup of a war fight (like public._bund_war_expect).
func war_expect(f: Dictionary) -> Dictionary:
	return {"seed": f.seed, "teams": (f.teams as Array).duplicate(true), "ai": b.config_int("league_ai", 2), "wild": false, "front": [1, 1],
		"items_allowed": false, "seals": [0, 0, 0], "amulets": [0, 0, 0]}

func _fn_bund_war_fight(_a: Dictionary) -> Dictionary:
	var v: Variant = _my_bund()
	if v is Dictionary:
		return v
	var bund: String = v
	var u: String = b.me()
	var wk: String = b._week()
	if not _war_day():
		return b._fail("war_closed")
	var me_f: Variant = (b._table("bund_war_fighters", {}) as Dictionary).get(wk + "|" + u)
	var wv: Array = _war_of(bund)
	if not me_f is Dictionary or str(me_f.bund) != bund or wv.is_empty():
		return b._fail("no_war")
	var side: String = "a" if str(wv[1].a) == bund else "b"
	var foe_list: Array = _fighters(wk, str(wv[1]["b" if side == "a" else "a"]))
	if int(me_f.slot) > foe_list.size():
		return b._fail("no_war")
	var foe_f: Dictionary = foe_list[int(me_f.slot) - 1]
	var fights: Dictionary = b._table("bund_war_fights", {})
	var fid: String = ""
	for id: String in fights:
		var f: Dictionary = fights[id]
		if str(f.war) == wv[0] and f.side == side and int(f.slot) == int(me_f.slot):
			if f.state != "open" or f.user != u:
				return b._fail("fought")
			fid = id
	if fid.is_empty():
		fid = str(b._next_id("bund_war_fight"))
		fights[fid] = {"war": wv[0], "user": u, "side": side, "slot": int(me_f.slot), "seed": b.rng.randi() & 0x7fffffff,
			"teams": [me_f.team, foe_f.team], "state": "open", "won": false, "created_at": b.now()}
	var out: Dictionary = war_expect(fights[fid])
	out.merge({"ok": true, "fight_id": int(fid), "foe": b.profile_of(foe_f.user).name})
	return out

## Like public._bund_war_apply: a checked win counts for the own bund.
func war_apply(battle_id: int, ok: bool, detail: Variant) -> void:
	for id: String in b._table("bund_war_fights", {}):
		var f: Dictionary = b.db.bund_war_fights[id]
		if int(f.get("battle_id", -1)) == battle_id and f.state == "submitted":
			f.state = "done"
			f.won = ok and detail is Dictionary and str(detail.get("winner", "")) == "player"
			_settle(str(f.war))
			return
