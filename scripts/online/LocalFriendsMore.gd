class_name LocalFriendsMore
extends RefCounted
## Friends and the shared world (Online 100, area 6) in the local stand-in server, with the same
## rules as supabase/migrations/20261112230020_friends_more.sql: friendship levels 6-10 with
## rewards, favourite friends, the joint task of the day, the league rank on the Wanderer card,
## recent league opponents as suggestions and the invite reward. tests/unit/test_friends_more.gd
## checks it.

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef
var _friends_list: Callable

static func install(backend: LocalBackend) -> LocalFriendsMore:
	var s := LocalFriendsMore.new()
	s._bref = weakref(backend)
	s._friends_list = backend._fns["friends_list"]
	for fn: String in ["friends_list", "friend_favorite", "friend_level_claim", "pair_task_claim", "friend_suggestions",
			"friend_suggest_request", "invite_redeem", "invite_state", "invite_claim"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("friends_more", s)
	return s

## server_config.friends_more over data/friends_more.json (tests change values in db.config).
func cfg() -> Dictionary:
	var c: Dictionary = FriendRules.config().duplicate(true)
	if b.db.config.get("friends_more") is Dictionary:
		c.merge(b.db.config.friends_more, true)
	return c

func _points(u: String, t: String) -> int:
	var f: Variant = b._friendship(u, t)
	return int(f.points) if f != null and str(f.status) == "accepted" else 0

func _pay(slot: int, rev: int, reward: Dictionary, times: int) -> Dictionary:
	var item: String = str(reward.get("item", "tonic"))
	var n: int = int(reward.get("count", 1)) * times
	var r: Dictionary = b._trade_bag(slot, rev, {item: n})
	if not bool(r.ok):
		return r
	return {"ok": true, "rev": r.rev, "item": item, "count": n, "bag": {item: n}}

func _friend_ok(t: String) -> bool:
	return not t.is_empty() and b.is_friend(b.me(), t) and not b.is_blocked(b.me(), t)

# --- 53, 56, 57, 59 in the friend list ------------------------------------------------------------

func _favs() -> Array:
	return b._user().get_or_add("friend_favorites", [])

func _level_ready(u: String, t: String) -> Array:
	var c: Dictionary = cfg()
	var claimed: Array = (b._table("friend_level_claims", {}) as Dictionary).get(u + "|" + t, [])
	var out: Array = []
	for lvl: int in range(6, FriendRules.level(c, _points(u, t)) + 1):
		if not FriendRules.level_reward(c, lvl).is_empty() and not claimed.has(lvl):
			out.append(lvl)
	return out

func _sent_today(from: String, to: String, kind: String) -> bool:
	for m: Dictionary in b._table("mail", []):
		if m.sender == from and m.recipient == to and m.kind == kind and Time.get_date_string_from_unix_time(int(m.at)) == b._today():
			return true
	return false

func _claims_today() -> Dictionary:
	var all: Dictionary = b._table("pair_task_claims", {})
	for k: String in all.keys():
		if str(all[k]) < Time.get_date_string_from_unix_time(b.now() - 7 * 86400):
			all.erase(k)
	return all

func pair_task(u: String, t: String) -> Dictionary:
	var kind: String = FriendRules.pair_kind(cfg(), b.now())
	return {"kind": kind, "mine": _sent_today(u, t, kind), "theirs": _sent_today(t, u, kind),
		"claimed": str(_claims_today().get(u + "|" + t, "")) == b._today()}

## League rank of [param t] in the fair league of their latest season (-1 = none or placement).
func card_rank(t: String) -> int:
	var best_season: int = -1
	var out: int = -1
	for key: String in (b._table("league_fair", {}) as Dictionary):
		var parts: PackedStringArray = key.split("|")
		if parts[1] == t and int(parts[0]) > best_season:
			best_season = int(parts[0])
			var e: Dictionary = b.db.league_fair[key]
			out = LeagueRules.rank(b.ranks_cfg(), float(e.rating), int(e.games))
	return out

func _fn_friends_list(a: Dictionary) -> Dictionary:
	var r: Dictionary = _friends_list.call(a)
	var u: String = b.me()
	for f: Dictionary in r.friends:
		var t: String = b.uid_for_code(str(f.code))
		f["fav"] = _favs().has(t)
		f["rank"] = card_rank(t)
		f["level_ready"] = _level_ready(u, t)
		f["task"] = pair_task(u, t)
	var list: Array = r.friends
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if bool(x.fav) != bool(y.fav):
			return bool(x.fav)
		return int(x.last_seen) > int(y.last_seen))
	return r

# --- 59: favourite friends --------------------------------------------------------------------

func _fn_friend_favorite(a: Dictionary) -> Dictionary:
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not _friend_ok(t):
		return LocalBackend._fail("not_friends")
	var favs: Array = _favs()
	if not bool(a.get("p_on", false)):
		favs.erase(t)
		return {"ok": true, "fav": false}
	if not favs.has(t):
		var live: int = favs.filter(func(x: String) -> bool: return b.is_friend(b.me(), x)).size()
		if live >= int(cfg().get("favorites_max", 10)):
			return LocalBackend._fail("favorites_full")
		favs.append(t)
	return {"ok": true, "fav": true}

# --- 56: rewards of friendship levels 6-10 ---------------------------------------------------------

func _fn_friend_level_claim(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not _friend_ok(t):
		return LocalBackend._fail("not_friends")
	var lvl: int = int(a.get("p_level", 0))
	var rw: Dictionary = FriendRules.level_reward(cfg(), lvl)
	if rw.is_empty():
		return LocalBackend._fail("bad_level")
	if FriendRules.level(cfg(), _points(u, t)) < lvl:
		return LocalBackend._fail("friend_level")
	var claims: Dictionary = b._table("friend_level_claims", {})
	var mine: Array = claims.get_or_add(u + "|" + t, [])
	if mine.has(lvl):
		return LocalBackend._fail("already")
	var r: Dictionary = _pay(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), rw, 1)
	if bool(r.ok):
		mine.append(lvl)
	return r

# --- 57: the joint task of the day ---------------------------------------------------------------

func _fn_pair_task_claim(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not b._can_reach(t):
		return LocalBackend._fail("not_friends")
	var task: Dictionary = pair_task(u, t)
	if bool(task.claimed):
		return LocalBackend._fail("already_today")
	if not (bool(task.mine) and bool(task.theirs)):
		return LocalBackend._fail("not_done")
	var c: Dictionary = cfg()
	var r: Dictionary = _pay(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), c.get("pair_reward", {}), 1)
	if not bool(r.ok):
		return r
	var claims: Dictionary = _claims_today()
	# The pair gets the friendship points once, with the first of the two claims.
	if str(claims.get(t + "|" + u, "")) != b._today():
		b._add_points(u, t, int(c.get("pair_points", 3)))
	claims[u + "|" + t] = b._today()
	r["points"] = int(c.get("pair_points", 3))
	return r

# --- 60: recent league opponents as friend suggestions -------------------------------------------

## The opponent of the player's league match [param id] when it can be suggested, else "".
func _suggest_target(id: String) -> String:
	var m: Variant = (b._table("league_matches", {}) as Dictionary).get(id)
	if m == null or str(m.user) != b.me():
		return ""
	var t: String = str(m.get("opponent", ""))
	if t.is_empty() or t == b.me() or not b.db.users.has(t):
		return ""
	if b.now() - int(m.created_at) > int(cfg().get("suggest_days", 14)) * 86400:
		return ""
	if b._friendship(b.me(), t) != null or b.is_blocked(b.me(), t) or not b._social(t):
		return ""
	if b.parent_off(b.me(), "suggest") or b.parent_off(t, "suggest"):
		return ""
	return t

func _fn_friend_suggestions(_a: Dictionary) -> Dictionary:
	b.profile_of(b.me())
	if not b._social(b.me()):
		return {"ok": true, "rows": []}
	var latest: Dictionary = {}
	for id: String in (b._table("league_matches", {}) as Dictionary):
		var t: String = _suggest_target(id)
		if t.is_empty():
			continue
		var m: Dictionary = b.db.league_matches[id]
		if not latest.has(t) or int(m.created_at) > int(latest[t].at):
			latest[t] = {"ref": int(id), "at": int(m.created_at), "league": str(m.league), "rank": card_rank(t)}
	var rows: Array = latest.values()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.at) > int(y.at))
	return {"ok": true, "rows": rows.slice(0, int(cfg().get("suggest_max", 5)))}

func _fn_friend_suggest_request(a: Dictionary) -> Dictionary:
	var t: String = _suggest_target(str(int(a.get("p_match", 0))))
	if t.is_empty():
		return LocalBackend._fail("no_such_code")
	return b._fns["friend_request"].call({"p_code": b.profile_of(t).code})

# --- 55: invite link with a reward for both ------------------------------------------------------

func _invites() -> Dictionary:
	return b._table("invites", {})

func _invite_due(u: String) -> Dictionary:
	var c: Dictionary = cfg()
	var own: Variant = _invites().get(u)
	var paid: int = 0
	var open: int = 0
	for k: String in _invites():
		var i: Dictionary = _invites()[k]
		if str(i.inviter) != u:
			continue
		if bool(i.inviter_paid):
			paid += 1
		elif b.is_friend(u, k):
			open += 1
	return {"self": own != null and not bool(own.invitee_paid) and b.is_friend(u, str(own.inviter)),
		"others": mini(open, maxi(0, int(c.get("invite_max", 10)) - paid))}

func _can_redeem(u: String) -> bool:
	return not _invites().has(u) and int(b.profile_of(u).get("created_at", 0)) >= b.now() - int(cfg().get("invite_days", 7)) * 86400

func _fn_invite_redeem(a: Dictionary) -> Dictionary:
	if not b.flag_on("invite", 2147483647):
		return LocalBackend._fail("feature_off")
	var u: String = b.me()
	b.profile_of(u)
	if _invites().has(u):
		return LocalBackend._fail("already")
	if not _can_redeem(u):
		return LocalBackend._fail("too_late")
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == u:
		return LocalBackend._fail("no_such_code")
	var r: Dictionary = b._fns["friend_request"].call({"p_code": a.get("p_code", "")})
	if not bool(r.get("ok", false)):
		return r
	_invites()[u] = {"inviter": t, "at": b.now(), "invitee_paid": false, "inviter_paid": false}
	return r

func _fn_invite_state(_a: Dictionary) -> Dictionary:
	if not b.flag_on("invite", 2147483647):
		return LocalBackend._fail("feature_off")
	var u: String = b.me()
	var p: Dictionary = b.profile_of(u)
	var d: Dictionary = _invite_due(u)
	var invited: int = 0
	var paid: int = 0
	for i: Dictionary in _invites().values():
		if str(i.inviter) == u:
			invited += 1
			paid += 1 if bool(i.inviter_paid) else 0
	return {"ok": true, "code": p.code, "can_redeem": _can_redeem(u), "invited": invited, "paid": paid,
		"max": int(cfg().get("invite_max", 10)), "ready": (1 if bool(d.self) else 0) + int(d.others),
		"reward": cfg().get("invite_reward", {})}

func _fn_invite_claim(a: Dictionary) -> Dictionary:
	if not b.flag_on("invite", 2147483647):
		return LocalBackend._fail("feature_off")
	var u: String = b.me()
	var d: Dictionary = _invite_due(u)
	var n: int = (1 if bool(d.self) else 0) + int(d.others)
	if n <= 0:
		return LocalBackend._fail("nothing")
	var r: Dictionary = _pay(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), cfg().get("invite_reward", {}), n)
	if not bool(r.ok):
		return r
	if bool(d.self):
		_invites()[u].invitee_paid = true
	var left: int = int(d.others)
	var mine: Array = []
	for k: String in _invites():
		var i: Dictionary = _invites()[k]
		if str(i.inviter) == u and not bool(i.inviter_paid) and b.is_friend(u, k):
			mine.append(k)
	mine.sort_custom(func(x: String, y: String) -> bool: return int(_invites()[x].at) < int(_invites()[y].at))
	for k: String in mine.slice(0, left):
		_invites()[k].inviter_paid = true
	r["times"] = n
	return r
