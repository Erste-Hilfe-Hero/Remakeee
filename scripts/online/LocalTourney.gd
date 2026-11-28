class_name LocalTourney
extends RefCounted
## The weekend tournament (Online 100, points 62, 74, 80), watching a friend's live duel (73) and
## the team of the best league player (77) in the local stand-in server, with the same rules as
## supabase/migrations/20261113000030_tourney_watch.sql. tests/unit/test_tourney_watch.gd checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalTourney:
	var s := LocalTourney.new()
	s._bref = weakref(backend)
	for fn: String in ["live_watch_list", "live_watch", "league_top_team", "tourney_info", "tourney_join", "tourney_fight",
			"tourney_reward", "tourney_finals", "tourney_replay"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("tourney", s)
	return s

# --- 73: watching a friend's live duel -------------------------------------------------------------

func _can_watch(d: Dictionary) -> bool:
	var u: String = b.me()
	return d.a != u and d.b != u and (b.is_friend(u, d.a) or b.is_friend(u, d.b)) and not b.is_blocked(u, d.a) \
		and not b.is_blocked(u, d.b)

func _names(d: Dictionary) -> Array:
	return [str(b.profile_of(d.a).name), str(b.profile_of(d.b).name)]

func _live_gate() -> String:
	if not b.flag_on("live_duel", 2147483647):
		return "feature_off"
	return "parent_off" if b.parent_off(b.me(), "live_duel") else ""

func _fn_live_watch_list(_a: Dictionary) -> Dictionary:
	var e: String = _live_gate()
	if not e.is_empty():
		return b._fail(e)
	var out: Array = []
	for d: Dictionary in (b._table("live_duels", {}) as Dictionary).values():
		if d.state == "running" and _can_watch(d):
			out.push_front({"id": int(d.id), "round": int(d.round), "names": _names(d)})
	return {"ok": true, "duels": out}

func _fn_live_watch(a: Dictionary) -> Dictionary:
	var e: String = _live_gate()
	if not e.is_empty():
		return b._fail(e)
	if not b._rate_ok("live_watch", 1200):
		return b._fail("slow_down")
	var d: Variant = b._live(a.get("p_id", -1))
	if d is Dictionary:
		b._live_tick(d)
	if not d is Dictionary or not d.state in ["running", "done"] or not _can_watch(d):
		return b._fail("no_such_duel")
	var out: Dictionary = b._live_out(d)
	out["names"] = _names(d)
	return out

# --- 77: the best league team ----------------------------------------------------------------------

func _fn_league_top_team(a: Dictionary) -> Dictionary:
	var league: String = str(a.get("p_league", ""))
	var e: String = b._league_check(league)
	if not e.is_empty():
		return b._fail(e)
	var sn: int = int(b.league_season().id)
	var least: int = int(b.ranks_cfg().get("placement_games", 5))
	var best: Variant = null
	var t: Dictionary = b._table("league_" + league, {})
	for key: String in t:
		var uid: String = key.substr(key.find("|") + 1)
		var row: Dictionary = t[key]
		if not key.begins_with("%d|" % sn) or int(row.games) < least or b.is_blocked(b.me(), uid):
			continue
		if best == null or float(row.rating) > float(best.rating):
			best = row
	if best == null:
		return {"ok": true, "team": null}
	var team: Array = []
	for m: Dictionary in best.team:
		team.append({"species": str(m.species), "level": int(m.level), "moves": (m.get("moves", []) as Array).duplicate()})
	return {"ok": true, "games": int(best.games), "team": team}

# --- 62, 74, 80: the weekend tournament ------------------------------------------------------------

## server_config.tourney over data/tourney.json (tests change values in db.config).
func cfg() -> Dictionary:
	var c: Dictionary = TourneyRules.config()
	if b.db.config.get("tourney") is Dictionary:
		c.merge(b.db.config.tourney, true)
	return c

func _check() -> String:
	if not b.flag_on("events", 2147483647):
		return "feature_off"
	if not b._social(b.me()):
		return "social_off"
	return "under_review" if b.cheat_held(b.me()) else ""

func _tourneys() -> Dictionary:
	return b._table("tourneys", {})

func _fights() -> Dictionary:
	return b._table("tourney_fights", {})

## Players of [param t] still in, by place.
func _live_players(t: Dictionary) -> Array:
	var out: Array = (t.players as Array).filter(func(p: Dictionary) -> bool: return int(p.out_round) == 0)
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.place) < int(q.place))
	return out

func _player(t: Dictionary, uid: String) -> Variant:
	for p: Dictionary in t.players:
		if p.user == uid:
			return p
	return null

func _foe(t: Dictionary, uid: String) -> Variant:
	var live: Array = _live_players(t)
	for i: int in live.size():
		if live[i].user == uid:
			var j: int = (i / 2) * 2 + 1 - i % 2
			return live[j] if j < live.size() else null
	return null

func _fight(tid: String, round: int, uid: String) -> Variant:
	for id: String in _fights():
		var f: Dictionary = _fights()[id]
		if str(f.tourney) == tid and int(f.round) == round and f.user == uid:
			return f
	return null

func _result(tid: String, round: int, p: Dictionary) -> Dictionary:
	var f: Variant = _fight(tid, round, p.user)
	var done: bool = f is Dictionary and f.state == "done"
	return {"won": done and bool(f.won), "damage": int(f.damage) if done else 0, "rounds": int(f.rounds) if done else 999,
		"place": int(p.place)}

## Like public._tourney_advance.
func advance(tid: String) -> void:
	while true:
		var t: Variant = _tourneys().get(tid)
		if not t is Dictionary or t.state != "running":
			return
		var round: int = int(t.round)
		var live: Array = _live_players(t)
		var done: int = 0
		for p: Dictionary in live:
			var f: Variant = _fight(tid, round, p.user)
			if f is Dictionary and f.state == "submitted" and int(f.created_at) > b.now() - 3600:
				return
			if f is Dictionary and f.state == "done":
				done += 1
		if b.now() < int(t.round_ends) and done < live.size():
			return
		for i: int in range(0, live.size() - 1, 2):
			var first: bool = TourneyRules.beats(_result(tid, round, live[i]), _result(tid, round, live[i + 1]))
			live[i + 1 if first else i].out_round = round
		var left: Array = _live_players(t)
		if left.size() <= 1:
			t.state = "done"
			t.winner = str(left[0].user) if left.size() == 1 else ""
			return
		t.round = round + 1
		t.round_ends = b.now() + 3600 * int(cfg().round_hours)

## Id of the latest tournament of the player this week, or "".
func _mine() -> String:
	var best: String = ""
	for id: String in _tourneys():
		var t: Dictionary = _tourneys()[id]
		if t.week == b._week() and _player(t, b.me()) != null and (best.is_empty() or int(id) > int(best)):
			best = id
	return best

func _name_for(uid: String) -> String:
	return str(b.profile_of(uid).name) if uid == b.me() or b.is_friend(b.me(), uid) else ""

func _fn_tourney_info(_a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	var u: String = b.me()
	var c: Dictionary = cfg()
	var tid: String = _mine()
	if tid.is_empty():
		for id: String in _tourneys():
			var x: Dictionary = _tourneys()[id]
			var px: Variant = _player(x, u)
			if x.state == "done" and px is Dictionary and not bool(px.claimed) and int(x.created_at) > b.now() - 14 * 86400 \
					and (tid.is_empty() or int(id) > int(tid)):
				tid = id
	var out: Dictionary = {"ok": true, "day": TourneyRules.is_day(c, b.now()), "size": int(c.size),
		"rounds": TourneyRules.rounds(int(c.size)), "days": (c.days as Array).duplicate(),
		"rewards": (c.rewards as Array).duplicate(true), "tourney": null}
	if tid.is_empty():
		return out
	advance(tid)
	var t: Dictionary = _tourneys()[tid]
	var me_p: Dictionary = _player(t, u)
	var foe: Variant = _foe(t, u) if t.state == "running" and int(me_p.out_round) == 0 else null
	var f: Variant = _fight(tid, int(t.round), u) if foe != null else null
	var players: Array = []
	for p: Dictionary in t.players:
		players.append({"place": int(p.place), "me": p.user == u, "out_round": int(p.out_round), "name": _name_for(p.user)})
	out.tourney = {"id": int(tid), "state": t.state, "round": int(t.round), "round_ends": int(t.round_ends),
		"out_round": int(me_p.out_round), "claimed": bool(me_p.claimed), "won": t.state == "done" and str(t.winner) == u,
		"fight": null if not f is Dictionary else (str(f.state) if f.state != "done" else ("won" if bool(f.won) else "lost")),
		"foe": null if foe == null else {"place": int(foe.place), "name": b.profile_of(foe.user).name if b.is_friend(u, foe.user) else "",
			"team": (foe.team as Array).map(func(m: Dictionary) -> String: return str(m.species))},
		"players": players}
	return out

func _fn_tourney_join(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	var u: String = b.me()
	var c: Dictionary = cfg()
	if not TourneyRules.is_day(c, b.now()):
		return b._fail("tourney_closed")
	if not _mine().is_empty():
		return b._fail("joined")
	if not b._rate_ok("tourney_join", 6):
		return b._fail("slow_down")
	var built: Dictionary = LeagueRules.build_team(b.profile_of(u).get("team", []), LeagueRules.FAIR, a.get("p_pick"),
		b.config_int("league_fair_ring", 50), b.config_int("level_max", 60))
	if built.has("error"):
		return b._fail(str(built.error))
	var tid: String = ""
	for id: String in _tourneys():
		var x: Dictionary = _tourneys()[id]
		if x.week == b._week() and x.state == "signup" and (tid.is_empty() or int(id) < int(tid)) \
				and not (x.players as Array).any(func(p: Dictionary) -> bool: return b.is_blocked(u, p.user)):
			tid = id
	if tid.is_empty():
		tid = str(b._next_id("tourney"))
		_tourneys()[tid] = {"week": b._week(), "state": "signup", "round": 0, "round_ends": 0, "winner": "", "players": [],
			"created_at": b.now()}
	var t: Dictionary = _tourneys()[tid]
	(t.players as Array).append({"user": u, "place": (t.players as Array).size() + 1, "team": built.team, "out_round": 0, "claimed": false})
	if (t.players as Array).size() >= int(c.size):
		t.state = "running"
		t.round = 1
		t.round_ends = b.now() + 3600 * int(c.round_hours)
	return _fn_tourney_info({})

## The battle setup of a tournament fight (like public._tourney_expect).
func expect(f: Dictionary) -> Dictionary:
	return {"seed": f.seed, "teams": (f.teams as Array).duplicate(true), "ai": b.config_int("league_ai", 2), "wild": false,
		"front": [1, 1], "items_allowed": false, "seals": [0, 0, 0], "amulets": [0, 0, 0]}

func _fn_tourney_fight(_a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	var u: String = b.me()
	var tid: String = _mine()
	if not tid.is_empty():
		advance(tid)
	var t: Variant = _tourneys().get(tid)
	var me_p: Variant = _player(t, u) if t is Dictionary else null
	if not t is Dictionary or t.state != "running" or int(me_p.out_round) != 0:
		return b._fail("no_tourney")
	var foe: Variant = _foe(t, u)
	if foe == null:
		return b._fail("no_tourney")
	var f: Variant = _fight(tid, int(t.round), u)
	if f is Dictionary and f.state != "open":
		return b._fail("fought")
	var fid: String = ""
	if f is Dictionary:
		fid = str(f.id)
	else:
		fid = str(b._next_id("tourney_fight"))
		_fights()[fid] = {"id": int(fid), "tourney": tid, "round": int(t.round), "user": u, "seed": b.rng.randi() & 0x7fffffff,
			"teams": [me_p.team, foe.team], "state": "open", "won": false, "damage": 0, "rounds": 999, "replay": null,
			"created_at": b.now()}
	var out: Dictionary = expect(_fights()[fid])
	out.merge({"ok": true, "fight_id": int(fid), "round": int(t.round)})
	return out

## Like public._tourney_apply.
func apply(battle_id: int, ok: bool, detail: Variant) -> void:
	for id: String in _fights():
		var f: Dictionary = _fights()[id]
		if int(f.get("battle_id", -1)) == battle_id and f.state == "submitted":
			var d: Dictionary = detail if ok and detail is Dictionary else {}
			f.state = "done"
			f.won = ok and str(d.get("winner", "")) == "player"
			f.damage = maxi(0, int(d.get("foe_damage", 0)))
			f.rounds = maxi(1, int(d.get("rounds", 999))) if ok else 999
			if not ok:
				f.replay = null
			advance(str(f.tourney))
			return

func _fn_tourney_reward(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	var u: String = b.me()
	var c: Dictionary = cfg()
	var best: String = ""
	for id: String in _tourneys():
		var x: Dictionary = _tourneys()[id]
		var px: Variant = _player(x, u)
		if x.state == "done" and px is Dictionary and not bool(px.claimed) and (best.is_empty() or int(id) > int(best)):
			best = id
	if best.is_empty():
		return b._fail("no_reward")
	var p: Dictionary = _player(_tourneys()[best], u)
	var tier: int = TourneyRules.tier(c, TourneyRules.rounds(int(c.size)), int(p.out_round))
	var rw: Dictionary = c.rewards[tier]
	var r: Dictionary = b._trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {str(rw.item): int(rw.count)})
	if not bool(r.ok):
		return r
	p.claimed = true
	return {"ok": true, "rev": r.rev, "item": rw.item, "count": int(rw.count), "tier": tier, "bag": {str(rw.item): int(rw.count)}}

func _final_fights() -> Array:
	var out: Array = []
	for id: String in _fights():
		var f: Dictionary = _fights()[id]
		var t: Variant = _tourneys().get(str(f.tourney))
		if t is Dictionary and t.state == "done" and int(f.round) == int(t.round) and f.state == "done" and f.replay != null \
				and int(t.created_at) > b.now() - 14 * 86400 and not b.is_blocked(b.me(), f.user):
			out.append(f)
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.id) > int(q.id))
	return out

func _fn_tourney_finals(_a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	var rows: Array = []
	for f: Dictionary in _final_fights().slice(0, int(cfg().finals_rows)):
		var t: Dictionary = _tourneys()[str(f.tourney)]
		var names: Array = []
		for team: Array in f.teams:
			names.append(team.map(func(m: Dictionary) -> String: return str(m.species)))
		rows.append({"fight": int(f.id), "week": t.week, "won": bool(f.won), "rounds": int(f.rounds),
			"champion": str(t.winner) == str(f.user), "name": _name_for(f.user), "teams": names})
	return {"ok": true, "rows": rows}

func _fn_tourney_replay(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return b._fail(e)
	if not b._rate_ok("tourney_replay", 60):
		return b._fail("slow_down")
	for f: Dictionary in _final_fights():
		if int(f.id) == int(a.get("p_fight", -1)):
			return {"ok": true, "replay": (f.replay as Dictionary).duplicate(true)}
	return b._fail("no_such_fight")
