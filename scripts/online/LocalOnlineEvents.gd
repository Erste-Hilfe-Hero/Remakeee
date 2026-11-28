class_name LocalOnlineEvents
extends RefCounted
## Online events (Online 100, area 7) in the local stand-in server: the same rules as
## supabase/migrations/20261112000070_online_events.sql. Used by tests and by builds without a server
## address. tests/unit/test_online_events.gd checks the rules.

const FNS: Array[String] = ["event_list", "event_claim", "event_enter", "event_board", "event_reward", "event_recap"]

## The backend this belongs to (weak, so the two do not keep each other alive).
var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> LocalOnlineEvents:
	var s := LocalOnlineEvents.new()
	s._bref = weakref(backend)
	for fn: String in FNS:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	if not backend.db.flags.has("events"):
		backend.db.flags["events"] = {"enabled": false, "min_version": 1}
	backend.set_meta("online_events", s)
	return s

static func of(backend: LocalBackend) -> LocalOnlineEvents:
	return backend.get_meta("online_events") if backend.has_meta("online_events") else null

func ev_cfg() -> Dictionary:
	var v: Variant = b.db.config.get("online_events")
	if not v is Dictionary:
		v = OnlineEvents.config()
		b.db.config["online_events"] = v
	return v

func _int(cfg: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = cfg.get(key, fallback)
	return int(v) if (v is int or v is float) else fallback

# --- Online events -------------------------------------------------------------------------

## Like the SQL community_add, called from LocalBackend._fn_community_add.
func on_contribute(uid: String, kind: String, amount: int) -> void:
	_event_goal_add(uid, kind, amount)

func _events() -> Dictionary:
	return b._table("online_events", {})

## Adds or replaces an event row, like an insert into public.online_events (tests, fixed events).
func put_event(row: Dictionary) -> void:
	var ev: Dictionary = row.duplicate(true)
	ev["total"] = int((_events().get(str(row.id), {}) as Dictionary).get("total", row.get("total", 0)))
	_events()[str(row.id)] = ev

## Like public._event_weekly: this week's and next week's event from the rotation, the fixed events
## from data/online_events.json, and old events go after 90 days.
func _weekly() -> void:
	var cfg: Dictionary = ev_cfg()
	var rot: Array = cfg.get("weekly", []) if cfg.get("weekly") is Array else []
	for i: int in 2:
		var start: int = OnlineEvents.week_start(b.now()) + 7 * 86400 * i
		var id: String = OnlineEvents.week_id(start)
		if not rot.is_empty() and not _events().has(id):
			var t: Dictionary = (OnlineEvents.weekly_template(rot, start) as Dictionary).duplicate(true)
			var kind: String = str(t.get("kind", "board"))
			t.erase("kind")
			put_event({"id": id, "kind": kind, "starts": start, "ends": start + 7 * 86400, "data": t})
	var fixed: Array = cfg.get("events", []) if cfg.get("events") is Array else []
	for x: Variant in fixed:
		if x is Dictionary and not _events().has(str(x.id)):
			var data: Dictionary = (x as Dictionary).duplicate(true)
			for k: String in ["id", "kind", "starts", "ends"]:
				data.erase(k)
			put_event({"id": str(x.id), "kind": str(x.kind), "starts": _unix(x.starts), "ends": _unix(x.ends), "data": data})
	for id: String in _events().keys():
		if int(_events()[id].ends) < b.now() - 90 * 86400:
			_events().erase(id)
			for key: String in (b._table("event_scores", {}) as Dictionary).keys():
				if key.begins_with(id + "|"):
					b.db.event_scores.erase(key)

static func _unix(v: Variant) -> int:
	return int(v) if (v is int or v is float) else Time.get_unix_time_from_datetime_string(str(v).trim_suffix("Z"))

func _allowed(ev: Dictionary) -> Variant:
	var data: Dictionary = ev.data
	if data.get("allowed") is Array:
		return data.allowed
	return OnlineEvents.allowed(data.rules) if data.get("rules") is Dictionary else null

func _check() -> String:
	if not b.flag_on("events", 2147483647):
		return "feature_off"
	b.profile_of(b.me())
	_weekly()
	return ""

func _scores() -> Dictionary:
	return b._table("event_scores", {})

func _score_row(id: String, uid: String) -> Variant:
	return _scores().get("%s|%s" % [id, uid])

func _public(ev: Dictionary) -> Dictionary:
	var out: Dictionary = (ev.data as Dictionary).duplicate(true)
	out.erase("allowed")
	out.merge({"id": ev.id, "kind": ev.kind, "starts": int(ev.starts), "ends": int(ev.ends),
		"state": OnlineEvents.state_of(ev, b.now()), "total": int(ev.total)}, true)
	return out

## Like public._event_rows: [{u, v, at}] of everyone on the board of [param ev].
func _rows(ev: Dictionary) -> Array:
	var out: Array = []
	for key: String in _scores():
		var parts: PackedStringArray = key.split("|")
		if parts[0] != str(ev.id) or not b.db.users.has(parts[1]):
			continue
		var s: Dictionary = _scores()[key]
		if ev.kind == "festival" and int(s.score) > 0:
			out.append({"u": parts[1], "v": int(s.score), "at": int(s.at)})
		elif ev.kind == "board" and s.get("team") != null:
			var n: int = 0
			var last: int = 0
			for r: Dictionary in b._table("rift_runs", []):
				if r.u != parts[1] or int(r.at) < maxi(int(s.at), int(ev.starts)) or int(r.at) >= int(ev.ends):
					continue
				if ev.data.get("rift") != null and str(r.rift) != str(ev.data.rift):
					continue
				if b.battle_ok(int(r.battle_id)):
					n += 1
					last = maxi(last, int(r.at))
			if n > 0:
				out.append({"u": parts[1], "v": n, "at": last})
	return out

func _event_goal_add(uid: String, kind: String, amount: int) -> void:
	if amount <= 0 or not b.flag_on("events", 2147483647):
		return
	_weekly()
	var cfg: Dictionary = ev_cfg()
	for ev: Dictionary in _events().values():
		if ev.kind != "festival" or str(ev.data.get("goal_kind", "")) != kind or OnlineEvents.state_of(ev, b.now()) != "running":
			continue
		var s: Dictionary = _scores().get_or_add("%s|%s" % [ev.id, uid], {"score": 0, "claimed": 0, "team": null, "at": b.now()})
		var cap: int = int(ev.data.get("user_cap", _int(cfg, "user_cap", 500)))
		var n: int = mini(mini(amount, _int(cfg, "add_max", 5)), maxi(cap - int(s.score), 0))
		if n <= 0:
			continue
		s.score = int(s.score) + n
		s.at = b.now()
		ev.total = int(ev.total) + n

func _mine(ev: Dictionary, uid: String) -> int:
	for r: Dictionary in _rows(ev):
		if r.u == uid:
			return int(r.v)
	return 0

func _award(id: String, uid: String) -> Variant:
	var a: Variant = (b._table("event_awards", {}) as Dictionary).get("%s|%s" % [id, uid])
	return {"rank": a.rank, "players": a.players, "title": a.title, "item": a.item} if a is Dictionary else null

func _fn_event_list(_a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var cfg: Dictionary = ev_cfg()
	var list: Array = []
	for ev: Dictionary in _events().values():
		if int(ev.ends) <= b.now() - _int(cfg, "recap_days", 14) * 86400 or int(ev.starts) >= b.now() + _int(cfg, "calendar_days", 35) * 86400:
			continue
		var s: Variant = _score_row(ev.id, u)
		var row: Dictionary = _public(ev)
		row.merge({"mine": _mine(ev, u), "claimed": int(s.claimed) if s is Dictionary else 0,
			"entered": s is Dictionary and s.get("team") != null, "award": _award(ev.id, u)}, true)
		list.append(row)
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.starts) < int(y.starts) or (int(x.starts) == int(y.starts) and str(x.id) < str(y.id)))
	var titles: Array = []
	var awards: Dictionary = b._table("event_awards", {})
	for key: String in awards:
		var parts: PackedStringArray = key.split("|")
		if parts[1] == u:
			titles.append({"event": parts[0], "title": awards[key].title, "at": int(awards[key].at),
				"name": (_events().get(parts[0], {"data": {}}) as Dictionary).data.get("name")})
	titles.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.at) > int(y.at))
	for t: Dictionary in titles:
		t.erase("at")
	return {"ok": true, "now": b.now(), "tiers": cfg.tiers, "events": list, "titles": titles}

func _fn_event_claim(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var cfg: Dictionary = ev_cfg()
	var ev: Variant = _events().get(str(a.get("p_event", "")))
	if not ev is Dictionary or ev.kind != "festival" or b.now() < int(ev.starts):
		return LocalBackend._fail("no_such_event")
	if b.now() > int(ev.ends) + _int(cfg, "recap_days", 14) * 86400:
		return LocalBackend._fail("event_over")
	var tier: int = int(a.get("p_tier", 0))
	var tiers: Array = cfg.tiers
	if tier < 1 or tier > tiers.size():
		return LocalBackend._fail("bad_tier")
	var s: Variant = _score_row(ev.id, u)
	if not s is Dictionary or int(s.score) <= 0:
		return LocalBackend._fail("not_helped")
	if not OnlineEvents.tier_reached(int(ev.total), int(ev.data.get("target", 0)), int(tiers[tier - 1])):
		return LocalBackend._fail("not_reached")
	var bit: int = 1 << (tier - 1)
	if int(s.claimed) & bit != 0:
		return LocalBackend._fail("claimed")
	var rewards: Array = ev.data.get("rewards", []) if ev.data.get("rewards") is Array else []
	var item: String = str(rewards[tier - 1]) if tier <= rewards.size() else "tonic"
	var r: Dictionary = b._trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {item: 1})
	if not bool(r.ok):
		return r
	s.claimed = int(s.claimed) | bit
	return {"ok": true, "rev": r.rev, "item": item, "bag": {item: 1}}

func _fn_event_enter(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var ev: Variant = _events().get(str(a.get("p_event", "")))
	if not ev is Dictionary or ev.kind != "board" or OnlineEvents.state_of(ev, b.now()) != "running":
		return LocalBackend._fail("no_such_event")
	var team: Array = a.get("p_team", []) if a.get("p_team") is Array else []
	if OnlineEvents.team_error(team, {}) != "":
		return LocalBackend._fail("bad_team")
	var ok: Variant = _allowed(ev)
	if ok is Array and team.any(func(n: Variant) -> bool: return not (ok as Array).has(str(n))):
		return LocalBackend._fail("rules")
	var s: Dictionary = _scores().get_or_add("%s|%s" % [ev.id, u], {"score": 0, "claimed": 0, "team": null, "at": b.now()})
	s.team = team.duplicate()
	return {"ok": true}

func _fn_event_board(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var ev: Variant = _events().get(str(a.get("p_event", "")))
	if not ev is Dictionary or ev.kind == "sighting":
		return LocalBackend._fail("no_such_event")
	var friends_only: bool = bool(a.get("p_friends", true))
	var rows: Array = _rows(ev).filter(func(r: Dictionary) -> bool:
		return not b.is_blocked(u, r.u) and (not friends_only or r.u == u or b.is_friend(u, r.u)))
	return {"ok": true, "event": ev.id, "rows": b._board(rows, false)}

## Like public._event_rank: {rank (null when not on the board), players, score, best}.
func _rank(ev: Dictionary, uid: String) -> Dictionary:
	var rows: Array = _rows(ev)
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return int(x.v) > int(y.v) or (int(x.v) == int(y.v) and int(x.at) < int(y.at)))
	var out: Dictionary = {"rank": null, "players": rows.size(), "score": 0, "best": int(rows[0].v) if not rows.is_empty() else 0}
	for i: int in rows.size():
		if rows[i].u == uid:
			out.rank = i + 1
			out.score = int(rows[i].v)
	return out

func _fn_event_reward(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var cfg: Dictionary = ev_cfg()
	var ev: Variant = _events().get(str(a.get("p_event", "")))
	if not ev is Dictionary or ev.kind == "sighting":
		return LocalBackend._fail("no_such_event")
	if b.now() < int(ev.ends):
		return LocalBackend._fail("still_running")
	var awards: Dictionary = b._table("event_awards", {})
	if awards.has("%s|%s" % [ev.id, u]):
		return LocalBackend._fail("claimed")
	var rk: Dictionary = _rank(ev, u)
	if rk.rank == null:
		return LocalBackend._fail("not_helped")
	var title: String = OnlineEvents.title_for(int(rk.rank), int(rk.players), cfg.titles)
	if title.is_empty():
		return LocalBackend._fail("not_helped")
	var item: Variant = (cfg.get("title_items", {}) as Dictionary).get(title)
	var rev: Variant = null
	if item != null:
		var r: Dictionary = b._trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {str(item): 1})
		if not bool(r.ok):
			return r
		rev = r.rev
	awards["%s|%s" % [ev.id, u]] = {"rank": rk.rank, "players": rk.players, "title": title, "item": item, "at": b.now()}
	return {"ok": true, "rev": rev, "rank": rk.rank, "players": rk.players, "title": title, "item": item,
		"bag": {} if item == null else {str(item): 1}}

func _fn_event_recap(a: Dictionary) -> Dictionary:
	var e: String = _check()
	if not e.is_empty():
		return LocalBackend._fail(e)
	var u: String = b.me()
	var ev: Variant = _events().get(str(a.get("p_event", "")))
	if not ev is Dictionary or ev.kind == "sighting" or b.now() < int(ev.starts):
		return LocalBackend._fail("no_such_event")
	var out: Dictionary = _public(ev)
	out.merge(_rank(ev, u), true)
	out.merge({"ok": true, "award": _award(ev.id, u),
		"reached": OnlineEvents.tiers_reached(int(ev.total), int(ev.data.get("target", 0)), ev_cfg().tiers) if ev.kind == "festival" else 0}, true)
	return out
