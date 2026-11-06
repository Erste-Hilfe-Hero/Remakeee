class_name LocalBackend
extends OnlineBackend
## In-memory stand-in for the server with the same rules as supabase/migrations.
## Used by tests (several fake players, a movable clock) and by builds that have no server
## address yet, so the online menus can be tried. Keep it in step with the SQL functions;
## tests/unit/test_online.gd checks both sides behave alike for the cases that matter.

const CODE_ALPHABET: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const BANNED: Array[String] = ["fuck", "shit", "bitch", "nazi", "hitler", "arsch", "fotze", "hure",
	"wichser", "nigg", "schwuchtel", "sex", "porn", "kill", "cunt", "dick"]
const ONLINE_WINDOW: int = 300
## Same limit as save_max_bytes in server_config (plan item 3662).
const SAVE_MAX_BYTES: int = 262144
## Same defaults as server_config in the migrations.
const DEFAULT_CONFIG: Dictionary = {
	"min_version": 1, "motd": "", "friend_limit": 100, "gift_open_limit": 10, "goal_user_cap": 500,
	"gift_table": [{"item": "tonic", "w": 25}, {"item": "remedy", "w": 20}, {"item": "strong_tonic", "w": 15},
		{"item": "spark_drop", "w": 12}, {"item": "cooling_gel", "w": 5}, {"item": "dry_towel", "w": 5},
		{"item": "wake_bell", "w": 5}, {"item": "power_brew", "w": 3}, {"item": "guard_brew", "w": 3},
		{"item": "focus_brew", "w": 3}, {"item": "dash_brew", "w": 3}, {"item": "revival_leaf", "w": 1}],
	"goal_rotation": [{"kind": "battles", "target": 5000}, {"kind": "bonds", "target": 800}, {"kind": "rests", "target": 2000}],
	"goal_rewards": ["strong_tonic", "spark_drop", "max_tonic", "spark_charm"],
}

## Where the fake server keeps its data between runs ("" = memory only, as in tests).
var store_path: String = ""
## {"users": {uid: user}, "config": {...}}; a user holds "profile" and "saves".
var db: Dictionary = {"users": {}, "config": DEFAULT_CONFIG.duplicate(true)}
## Seconds added to the real clock (tests move time with this).
var clock_offset: int = 0
## When true every call fails like a dropped connection.
var offline: bool = false
var rng := RandomNumberGenerator.new()
## Server functions by name (social and together functions are added by later parts).
var _fns: Dictionary[String, Callable] = {}

func _init(p_store_path: String = "") -> void:
	store_path = p_store_path
	rng.randomize()
	_load()
	for fn: String in ["hello", "profile_set", "presence", "save_list", "save_get", "save_put", "save_delete", "delete_account",
			"transfer_create", "transfer_claim",
			"friend_request", "friend_respond", "friend_remove", "block", "unblock", "report", "set_social", "friends_list",
			"mail_send", "gift_send", "mail_list", "gift_open", "mail_open", "team_set", "friend_team", "echo_report",
			"community_get", "community_add", "community_claim", "weekly_submit", "weekly_board"]:
		_fns[fn] = Callable(self, "_fn_" + fn)

func is_local() -> bool:
	return true

func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset

func sign_in_anonymous() -> Dictionary:
	if offline:
		return fail("network", true)
	var uid: String = _new_uid()
	db.users[uid] = {}
	_set_session(uid)
	_save()
	return ok(session)

func refresh() -> Dictionary:
	if offline:
		return fail("network", true)
	var uid: String = str(session.get("user_id", ""))
	if not db.users.has(uid):
		session = {}
		return fail("not_signed_in")
	_set_session(uid)
	return ok(session)

func call_fn(name: String, args: Dictionary = {}) -> Dictionary:
	if offline:
		return fail("network", true)
	if not signed_in() or not db.users.has(str(session.get("user_id", ""))):
		return fail("not_signed_in")
	if not _fns.has(name):
		return fail("unknown function %s" % name)
	var r: Variant = _fns[name].call(args)
	_save()
	return ok(r)

## Test helper: acts as another player from now on (creates them if needed).
func switch_user(uid: String) -> void:
	if not db.users.has(uid):
		db.users[uid] = {}
	_set_session(uid)

func me() -> String:
	return str(session.get("user_id", ""))

func _set_session(uid: String) -> void:
	session = {"access_token": "local-" + uid, "refresh_token": "local-" + uid, "expires_at": now() + 3600,
		"user_id": uid}

func _new_uid() -> String:
	return "%08x-%04x-%04x" % [rng.randi(), rng.randi() & 0xffff, rng.randi() & 0xffff]

func _load() -> void:
	if store_path.is_empty() or not FileAccess.file_exists(store_path):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(store_path))
	if raw is Dictionary and raw.get("users") is Dictionary:
		db = raw
		var cfg: Dictionary = DEFAULT_CONFIG.duplicate(true)
		if db.get("config") is Dictionary:
			cfg.merge(db.config, true)
		db["config"] = cfg

func _save() -> void:
	if store_path.is_empty():
		return
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(db))

# --- Helpers that mirror the SQL ones -----------------------------------------------------

func _user() -> Dictionary:
	return db.users[me()]

func profile_of(uid: String) -> Dictionary:
	var u: Dictionary = db.users[uid]
	if not u.has("profile"):
		u["profile"] = {"code": _new_code(), "name": "Tamer", "color": 0, "favorite": "", "card": {},
			"place": "", "social": true, "last_seen": now(), "created_at": now()}
	return u.profile

func uid_for_code(code: String) -> String:
	var c: String = code.strip_edges().to_upper().replace(" ", "").replace("-", "")
	for uid: String in db.users:
		var u: Dictionary = db.users[uid]
		if u.has("profile") and str(u.profile.code) == c:
			return uid
	return ""

func _new_code() -> String:
	while true:
		var c: String = ""
		for i: int in 8:
			c += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
		if uid_for_code(c).is_empty():
			return c
	return ""

static func clean_name(p_name: String, code: String) -> String:
	var n: String = " ".join(p_name.strip_edges().split(" ", false))
	var fallback: String = "Tamer " + code.right(4)
	if n.is_empty() or n.length() > 10:
		return fallback
	var re := RegEx.create_from_string("^[\\p{L}\\p{N} ]+$")
	if re.search(n) == null:
		return fallback
	var folded: String = n.to_lower()
	for pair: Array in [["0", "o"], ["1", "i"], ["3", "e"], ["4", "a"], ["5", "s"], ["7", "t"], ["@", "a"], ["$", "s"], [" ", ""]]:
		folded = folded.replace(pair[0], pair[1])
	for w: String in BANNED:
		if folded.contains(w):
			return fallback
	return n

static func profile_json(p: Dictionary) -> Dictionary:
	return {"code": p.code, "name": p.name, "color": p.color, "favorite": p.favorite,
		"card": p.card, "place": p.place, "social": p.social}

func online_now() -> int:
	var n: int = 0
	for uid: String in db.users:
		var u: Dictionary = db.users[uid]
		if u.has("profile") and now() - int(u.profile.last_seen) < ONLINE_WINDOW:
			n += 1
	return n

static func save_ok(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	if JSON.stringify(d).length() > 400000:
		return false
	var party: Variant = d.get("party", [])
	var storage: Variant = d.get("storage", [])
	if not party is Array or not storage is Array or (party as Array).size() > 6:
		return false
	var money: Variant = d.get("money", 0)
	if not (money is int or money is float) or float(money) < 0 or float(money) > 9999999:
		return false
	for s: Variant in (party as Array) + (storage as Array):
		if s is Dictionary:
			var lvl: Variant = s.get("level", 1)
			if not (lvl is int or lvl is float) or float(lvl) < 1 or float(lvl) > 100:
				return false
	return true

# --- Core functions (20261101000001_online_core.sql) ---------------------------------------

func _fn_hello(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	p.last_seen = now()
	return {"profile": profile_json(p), "server_time": now(),
		"update_required": int(a.get("p_version", 0)) < int(db.config.get("min_version", 1)),
		"motd": str(db.config.get("motd", "")), "online_now": online_now()}

func _fn_profile_set(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	var card: Dictionary = {}
	var given: Variant = a.get("p_card", {})
	if given is Dictionary:
		for k: String in ["seals", "seen", "bonded", "hours", "achievements"]:
			var v: Variant = given.get(k)
			if v is int or v is float:
				card[k] = clampi(int(v), 0, 99999)
	p.name = clean_name(str(a.get("p_name", "")), p.code)
	p.color = clampi(int(a.get("p_color", 0)), 0, 3)
	var fav: String = ""
	for ch: String in str(a.get("p_favorite", "")):
		if ch == " " or ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			fav += ch
	p.favorite = fav.left(20)
	p.card = card
	p.last_seen = now()
	return profile_json(p)

func _fn_presence(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	p.last_seen = now()
	var place: String = ""
	for ch: String in str(a.get("p_place", "")):
		if ch in [" ", "'", "-"] or ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			place += ch
	p.place = place.left(24)
	return {"server_time": now(), "online_now": online_now()}

func _saves() -> Dictionary:
	var u: Dictionary = _user()
	if not u.has("saves"):
		u["saves"] = {}
	return u.saves

func _fn_save_list(_a: Dictionary) -> Array:
	var out: Array = []
	var saves: Dictionary = _saves()
	var keys: Array = saves.keys()
	keys.sort()
	for k: Variant in keys:
		var s: Dictionary = saves[k]
		out.append({"slot": int(k), "rev": s.rev, "summary": s.summary, "saved_at": s.saved_at})
	return out

func _fn_save_get(a: Dictionary) -> Variant:
	var s: Variant = _saves().get(str(int(a.get("p_slot", 0))))
	if s == null:
		return null
	return {"slot": int(a.p_slot), "rev": s.rev, "data": (s.data as Dictionary).duplicate(true), "summary": s.summary, "saved_at": s.saved_at}

func _fn_save_put(a: Dictionary) -> Dictionary:
	var slot: int = int(a.get("p_slot", 0))
	if slot < 1 or slot > 3:
		return {"ok": false, "error": "bad_slot"}
	if JSON.stringify(a.get("p_data")).to_utf8_buffer().size() > SAVE_MAX_BYTES:
		return {"ok": false, "error": "too_big"}
	if not save_ok(a.get("p_data")):
		return {"ok": false, "error": "implausible"}
	var saves: Dictionary = _saves()
	var cur: Variant = saves.get(str(slot))
	var rid: String = str(a.get("p_request_id", "")).left(64) if a.get("p_request_id") != null else ""
	# The same upload again after a lost answer is already stored (plan item 3658).
	if cur != null and not rid.is_empty() and str(cur.get("request_id", "")) == rid:
		return {"ok": true, "rev": cur.rev, "saved_at": cur.saved_at, "repeat": true}
	if cur != null and int(cur.rev) != int(a.get("p_base_rev", 0)) and not bool(a.get("p_force", false)):
		return {"ok": false, "conflict": true, "rev": cur.rev, "saved_at": cur.saved_at, "summary": cur.summary}
	var rev: int = (int(cur.rev) if cur != null else 0) + 1
	saves[str(slot)] = {"rev": rev, "data": (a.p_data as Dictionary).duplicate(true),
		"summary": str(a.get("p_summary", "")).left(60), "saved_at": now(), "request_id": rid}
	return {"ok": true, "rev": rev, "saved_at": now()}

func _fn_save_delete(a: Dictionary) -> Dictionary:
	var had: bool = _saves().erase(str(int(a.get("p_slot", 0))))
	return {"ok": true, "deleted": 1 if had else 0}

func _fn_delete_account(_a: Dictionary) -> Dictionary:
	var uid: String = me()
	_on_delete_user(uid)
	db.users.erase(uid)
	session = {}
	return {"ok": true}

func _fn_transfer_create(_a: Dictionary) -> Dictionary:
	profile_of(me())
	var c: String = ""
	for i: int in 12:
		c += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	_user()["transfer"] = {"hash": transfer_hash(c), "at": now()}
	return {"code": c, "valid_days": 7}

static func transfer_hash(code: String) -> String:
	var clean: String = ""
	for ch: String in code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			clean += ch
	return clean.sha256_text()

func _fn_transfer_claim(a: Dictionary) -> Dictionary:
	var u: Dictionary = _user()
	var tries: Array = u.get("transfer_tries", []).filter(func(t: Variant) -> bool: return now() - int(t) < 3600)
	if tries.size() >= 10:
		return {"ok": false, "error": "too_many_tries"}
	tries.append(now())
	u["transfer_tries"] = tries
	var h: String = transfer_hash(str(a.get("p_code", "")))
	var old: String = ""
	for uid: String in db.users:
		var t: Variant = db.users[uid].get("transfer")
		if t is Dictionary and str(t.hash) == h and now() - int(t.at) < 7 * 86400:
			old = uid
	if old.is_empty() or old == me():
		return {"ok": false, "error": "bad_code"}
	var moved: Dictionary = db.users[old]
	moved.erase("transfer")
	_move_account(old, me())
	db.users[me()] = moved
	db.users.erase(old)
	return {"ok": true}

# --- Together functions (20261101000002_online_together.sql) -------------------------------

func _table(key: String, empty: Variant) -> Variant:
	if not db.has(key):
		db[key] = empty
	return db[key]

static func pair_key(x: String, y: String) -> String:
	return "%s|%s" % [x, y] if x < y else "%s|%s" % [y, x]

func _friendship(x: String, y: String) -> Variant:
	return (_table("friendships", {}) as Dictionary).get(pair_key(x, y))

func is_friend(x: String, y: String) -> bool:
	var f: Variant = _friendship(x, y)
	return f != null and str(f.status) == "accepted"

func is_blocked(x: String, y: String) -> bool:
	for b: Variant in _table("blocks", []):
		if (b[0] == x and b[1] == y) or (b[0] == y and b[1] == x):
			return true
	return false

func _social(uid: String) -> bool:
	return db.users.has(uid) and bool(profile_of(uid).get("social", true))

func _rate_ok(kind: String, max_per_hour: int) -> bool:
	var rate: Dictionary = _table("rate", {})
	var key: String = me() + "|" + kind
	var times: Array = (rate.get(key, []) as Array).filter(func(t: Variant) -> bool: return now() - int(t) < 3600)
	if times.size() >= max_per_hour:
		rate[key] = times
		return false
	times.append(now())
	rate[key] = times
	return true

func _today() -> String:
	return Time.get_date_string_from_unix_time(now())

func _week() -> String:
	return WeeklyChallenge.week_key(now())

static func level_for(points: int) -> int:
	return 5 if points >= 100 else 4 if points >= 60 else 3 if points >= 30 else 2 if points >= 10 else 1

static func _fail(e: String) -> Dictionary:
	return {"ok": false, "error": e}

func _add_points(x: String, y: String, n: int) -> void:
	var f: Variant = _friendship(x, y)
	if f != null and str(f.status) == "accepted":
		f.points = mini(int(f.points) + n, 100000)

func _accepted_count(uid: String) -> int:
	var n: int = 0
	for f: Dictionary in (_table("friendships", {}) as Dictionary).values():
		if str(f.status) == "accepted" and (f.a == uid or f.b == uid):
			n += 1
	return n

func _new_mail(to: String, kind: String, phrase: int = 0) -> Dictionary:
	var id: int = int(db.get("next_mail_id", 1))
	db["next_mail_id"] = id + 1
	var m: Dictionary = {"id": id, "sender": me(), "recipient": to, "kind": kind, "phrase": phrase, "item": "",
		"place": str(profile_of(me()).place), "opened": false, "opened_at": 0, "at": now()}
	(_table("mail", []) as Array).append(m)
	return m

func _sent_today(to: String, kind: String) -> bool:
	for m: Dictionary in _table("mail", []):
		if m.sender == me() and m.recipient == to and m.kind == kind and Time.get_date_string_from_unix_time(int(m.at)) == _today():
			return true
	return false

func _fn_friend_request(a: Dictionary) -> Dictionary:
	var u: String = me()
	profile_of(u)
	if not _social(u):
		return _fail("social_off")
	if not _rate_ok("friend", 20):
		return _fail("slow_down")
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == u or is_blocked(u, t) or not _social(t):
		return _fail("no_such_code")
	var f: Variant = _friendship(u, t)
	if f != null and str(f.status) == "accepted":
		return {"ok": true, "status": "accepted"}
	var lim: int = int(db.config.get("friend_limit", 100))
	if _accepted_count(u) >= lim or _accepted_count(t) >= lim:
		return _fail("full")
	if f != null and f.requested_by == t:
		f.status = "accepted"
		return {"ok": true, "status": "accepted"}
	if f == null:
		db.friendships[pair_key(u, t)] = {"a": u if u < t else t, "b": t if u < t else u, "status": "pending",
			"requested_by": u, "points": 0}
	return {"ok": true, "status": "pending"}

func _fn_friend_respond(a: Dictionary) -> Dictionary:
	var u: String = me()
	var t: String = uid_for_code(str(a.get("p_code", "")))
	var f: Variant = _friendship(u, t)
	if t.is_empty():
		return _fail("no_such_code")
	if f != null and str(f.status) == "pending":
		if bool(a.get("p_accept", false)):
			if f.requested_by == t:
				f.status = "accepted"
		else:
			db.friendships.erase(pair_key(u, t))
	return {"ok": true}

func _fn_friend_remove(a: Dictionary) -> Dictionary:
	(_table("friendships", {}) as Dictionary).erase(pair_key(me(), uid_for_code(str(a.get("p_code", "")))))
	return {"ok": true}

func _fn_block(a: Dictionary) -> Dictionary:
	var u: String = me()
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == u:
		return _fail("no_such_code")
	if not is_blocked(u, t) or not (_table("blocks", []) as Array).has([u, t]):
		(_table("blocks", []) as Array).append([u, t])
	(_table("friendships", {}) as Dictionary).erase(pair_key(u, t))
	db.mail = (_table("mail", []) as Array).filter(func(m: Dictionary) -> bool: return not (m.sender == t and m.recipient == u))
	return {"ok": true}

func _fn_unblock(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	db.blocks = (_table("blocks", []) as Array).filter(func(b: Variant) -> bool: return not (b[0] == me() and b[1] == t))
	return {"ok": true}

func _fn_report(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == me():
		return _fail("no_such_code")
	if not _rate_ok("report", 10):
		return _fail("slow_down")
	(_table("reports", []) as Array).append({"reporter": me(), "target": t, "target_name": profile_of(t).name,
		"reason": clampi(int(a.get("p_reason", 3)), 0, 3), "at": now()})
	return {"ok": true}

func _fn_set_social(a: Dictionary) -> Dictionary:
	profile_of(me()).social = bool(a.get("p_on", true))
	return {"ok": true, "social": profile_of(me()).social}

func _fn_friends_list(_a: Dictionary) -> Dictionary:
	var u: String = me()
	profile_of(u)
	var friends: Array = []
	var incoming: Array = []
	var outgoing: Array = []
	for f: Dictionary in (_table("friendships", {}) as Dictionary).values():
		if f.a != u and f.b != u:
			continue
		var other: String = f.b if f.a == u else f.a
		var p: Dictionary = profile_of(other)
		if str(f.status) == "accepted":
			friends.append({"code": p.code, "name": p.name, "color": p.color, "favorite": p.favorite, "card": p.card,
				"place": p.place, "online": now() - int(p.last_seen) < ONLINE_WINDOW, "last_seen": int(p.last_seen),
				"points": f.points, "level": level_for(int(f.points)), "has_team": not (p.get("team", []) as Array).is_empty(),
				"gift_sent": _sent_today(other, "gift")})
		elif f.requested_by == u:
			outgoing.append({"code": p.code, "name": p.name})
		else:
			incoming.append({"code": p.code, "name": p.name})
	friends.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.last_seen) > int(y.last_seen))
	var blocked: Array = []
	for b: Variant in _table("blocks", []):
		if b[0] == u and db.users.has(b[1]):
			blocked.append({"code": profile_of(b[1]).code, "name": profile_of(b[1]).name})
	return {"friends": friends, "incoming": incoming, "outgoing": outgoing, "blocked": blocked}

func _can_reach(t: String) -> bool:
	return not t.is_empty() and is_friend(me(), t) and not is_blocked(me(), t) and _social(me()) and _social(t)

func _fn_mail_send(a: Dictionary) -> Dictionary:
	var kind: String = str(a.get("p_kind", ""))
	if not kind in ["phrase", "wave", "thanks"]:
		return _fail("bad_kind")
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if not _can_reach(t):
		return _fail("not_friends")
	var phrase: int = int(a.get("p_phrase", -1))
	if phrase < 0 or phrase > 31:
		return _fail("bad_phrase")
	if not _rate_ok("mail", 30):
		return _fail("slow_down")
	_new_mail(t, kind, phrase)
	return {"ok": true}

func _fn_gift_send(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if not _can_reach(t):
		return _fail("not_friends")
	if _sent_today(t, "gift"):
		return _fail("already_today")
	_new_mail(t, "gift")
	_add_points(me(), t, 1)
	return {"ok": true}

func _fn_mail_list(_a: Dictionary) -> Array:
	var u: String = me()
	db.mail = (_table("mail", []) as Array).filter(func(m: Dictionary) -> bool: return not (m.recipient == u and now() - int(m.at) > 30 * 86400))
	var mine: Array = (db.mail as Array).filter(func(m: Dictionary) -> bool: return m.recipient == u and db.users.has(m.sender))
	mine.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.at) > int(y.at) or (int(x.at) == int(y.at) and int(x.id) > int(y.id)))
	var out: Array = []
	for m: Dictionary in mine.slice(0, 50):
		var p: Dictionary = profile_of(m.sender)
		out.append({"id": m.id, "kind": m.kind, "phrase": m.phrase, "item": m.item, "place": m.place, "opened": m.opened,
			"at": m.at, "code": p.code, "name": p.name})
	return out

func _mail_by_id(id: int) -> Variant:
	for m: Dictionary in _table("mail", []):
		if int(m.id) == id and m.recipient == me():
			return m
	return null

## Rolls an item from a weighted table like the server (weights out of their sum).
func roll_gift(table: Array) -> String:
	var total: int = 0
	for e: Dictionary in table:
		total += int(e.w)
	var roll: int = rng.randi_range(0, maxi(total - 1, 0))
	var acc: int = 0
	for e: Dictionary in table:
		acc += int(e.w)
		if roll < acc:
			return str(e.item)
	return "tonic"

func _fn_gift_open(a: Dictionary) -> Dictionary:
	var m: Variant = _mail_by_id(int(a.get("p_id", 0)))
	if m == null or str(m.kind) != "gift":
		return _fail("no_such_gift")
	if bool(m.opened):
		return {"ok": true, "item": m.item, "again": true}
	var opened_today: int = 0
	for x: Dictionary in _table("mail", []):
		if x.recipient == me() and x.kind == "gift" and bool(x.opened) and Time.get_date_string_from_unix_time(int(x.opened_at)) == _today():
			opened_today += 1
	if opened_today >= int(db.config.get("gift_open_limit", 10)):
		return _fail("limit_today")
	m.item = roll_gift(db.config.gift_table)
	m.opened = true
	m.opened_at = now()
	return {"ok": true, "item": m.item}

func _fn_mail_open(a: Dictionary) -> Dictionary:
	var m: Variant = _mail_by_id(int(a.get("p_id", 0)))
	if m == null or str(m.kind) == "gift":
		return {"ok": false}
	m.opened = true
	return {"ok": true}

func _fn_team_set(a: Dictionary) -> Dictionary:
	var given: Variant = a.get("p_team")
	if not given is Array:
		return _fail("bad_team")
	var clean: Array = []
	for s: Variant in (given as Array).slice(0, 6):
		var d: Dictionary = s if s is Dictionary else {}
		var moves: Array = []
		var mv_list: Variant = d.get("moves", [])
		for mv: Variant in (mv_list as Array if mv_list is Array else []).slice(0, 4):
			moves.append(_keep(str(mv), " '-").left(24))
		var lvl: Variant = d.get("level", 1)
		clean.append({"species": _keep(str(d.get("species", "")), "").left(20),
			"level": clampi(int(lvl) if (lvl is int or lvl is float) else 1, 1, 100), "moves": moves})
	profile_of(me())["team"] = clean
	return {"ok": true, "size": clean.size()}

static func _keep(text: String, extra: String) -> String:
	var out: String = ""
	for ch: String in text:
		if extra.contains(ch) or ch.to_upper() != ch.to_lower() or ch.is_valid_int():
			out += ch
	return out

func _fn_friend_team(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or not is_friend(me(), t):
		return _fail("not_friends")
	var p: Dictionary = profile_of(t)
	return {"ok": true, "name": p.name, "color": p.color, "team": (p.get("team", []) as Array).duplicate(true)}

func _fn_echo_report(a: Dictionary) -> Dictionary:
	var kind: String = str(a.get("p_kind", ""))
	var pts: int = 3 if kind == "echo" else 2 if kind == "duel" else 0
	if pts == 0:
		return _fail("bad_kind")
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or not is_friend(me(), t):
		return _fail("not_friends")
	if _sent_today(t, kind):
		return {"ok": true, "points": 0}
	if _social(t) and not is_blocked(me(), t):
		_new_mail(t, kind, 1 if bool(a.get("p_won", false)) else 0)
	_add_points(me(), t, pts)
	return {"ok": true, "points": pts}

func _goal() -> Dictionary:
	var goals: Dictionary = _table("goals", {})
	var w: String = _week()
	if not goals.has(w):
		var rot: Array = db.config.goal_rotation
		var week_no: int = int(w.split("-W")[1])
		var pick: Dictionary = rot[week_no % rot.size()]
		goals[w] = {"week": w, "kind": str(pick.kind), "target": int(pick.target), "total": 0}
	return goals[w]

func _contrib(g: Dictionary) -> Dictionary:
	var c: Dictionary = _table("contrib", {})
	var key: String = "%s|%s" % [g.week, me()]
	if not c.has(key):
		c[key] = {"amount": 0, "claimed": 0}
	return c[key]

func _goal_json(g: Dictionary) -> Dictionary:
	var c: Dictionary = _contrib(g)
	return {"week": g.week, "kind": g.kind, "target": g.target, "total": g.total, "mine": c.amount, "claimed": c.claimed,
		"rewards": db.config.goal_rewards, "online_now": online_now()}

func _fn_community_get(_a: Dictionary) -> Dictionary:
	return _goal_json(_goal())

func _fn_community_add(a: Dictionary) -> Dictionary:
	var g: Dictionary = _goal()
	var amount: int = int(a.get("p_amount", 0))
	if str(a.get("p_kind", "")) == str(g.kind) and amount > 0:
		var c: Dictionary = _contrib(g)
		var n: int = mini(mini(amount, 5), maxi(int(db.config.get("goal_user_cap", 500)) - int(c.amount), 0))
		c.amount = int(c.amount) + n
		g.total = int(g.total) + n
	return _goal_json(g)

func _fn_community_claim(a: Dictionary) -> Dictionary:
	var tier: int = int(a.get("p_tier", 0))
	if tier < 1 or tier > 4:
		return _fail("bad_tier")
	var g: Dictionary = _goal()
	var c: Dictionary = _contrib(g)
	if int(c.amount) <= 0:
		return _fail("not_helped")
	if int(g.total) * 4 < int(g.target) * tier:
		return _fail("not_reached")
	var bit: int = 1 << (tier - 1)
	if int(c.claimed) & bit != 0:
		return _fail("claimed")
	c.claimed = int(c.claimed) | bit
	return {"ok": true, "item": str(db.config.goal_rewards[tier - 1])}

func _fn_weekly_submit(a: Dictionary) -> Dictionary:
	if str(a.get("p_week", "")) != _week():
		return _fail("wrong_week")
	var score: int = int(a.get("p_score", -1))
	if score < 0 or score > 400:
		return _fail("implausible")
	var scores: Dictionary = _table("scores", {})
	var key: String = "%s|%s" % [_week(), me()]
	var cur: Variant = scores.get(key)
	if cur == null or score > int(cur.score):
		scores[key] = {"week": _week(), "uid": me(), "score": score, "at": now()}
	return {"ok": true}

func _fn_weekly_board(a: Dictionary) -> Dictionary:
	var u: String = me()
	var friends_only: bool = bool(a.get("p_friends", true))
	var rows: Array = []
	for r: Dictionary in (_table("scores", {}) as Dictionary).values():
		if r.week == _week() and db.users.has(r.uid) and (not friends_only or r.uid == u or is_friend(u, r.uid)):
			rows.append(r)
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.score) > int(y.score) or (int(x.score) == int(y.score) and int(x.at) < int(y.at)))
	var out: Array = []
	var rank: int = 0
	var last_score: int = -1
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if int(r.score) != last_score:
			rank = i + 1
			last_score = int(r.score)
		if rank <= 20 or r.uid == u:
			out.append({"rank": rank, "score": r.score, "me": r.uid == u,
				"name": profile_of(r.uid).name if (r.uid == u or is_friend(u, r.uid)) else ""})
	return {"week": _week(), "rows": out}

## Moves every row of [param old] to [param new] (transfer code).
func _move_account(old: String, new: String) -> void:
	_on_delete_user(new)
	var fs: Dictionary = _table("friendships", {})
	for key: String in fs.keys():
		var f: Dictionary = fs[key]
		if f.a == old or f.b == old:
			fs.erase(key)
			var other: String = f.b if f.a == old else f.a
			f.a = new if new < other else other
			f.b = other if new < other else new
			if f.requested_by == old:
				f.requested_by = new
			fs[pair_key(new, other)] = f
	for b: Variant in _table("blocks", []):
		for i: int in 2:
			if b[i] == old:
				b[i] = new
	for m: Dictionary in _table("mail", []):
		if m.sender == old:
			m.sender = new
		if m.recipient == old:
			m.recipient = new
	for table: String in ["contrib", "scores"]:
		var t: Dictionary = _table(table, {})
		for key: String in t.keys():
			if key.ends_with("|" + old):
				var row: Variant = t[key]
				t.erase(key)
				if row is Dictionary and row.has("uid"):
					row.uid = new
				t[key.trim_suffix(old) + new] = row

## Removes a deleted player from every table (the SQL does this with ON DELETE CASCADE).
func _on_delete_user(uid: String) -> void:
	var fs: Dictionary = _table("friendships", {})
	for key: String in fs.keys():
		if fs[key].a == uid or fs[key].b == uid:
			fs.erase(key)
	db.blocks = (_table("blocks", []) as Array).filter(func(b: Variant) -> bool: return b[0] != uid and b[1] != uid)
	db.mail = (_table("mail", []) as Array).filter(func(m: Dictionary) -> bool: return m.sender != uid and m.recipient != uid)
	for table: String in ["contrib", "scores"]:
		var t: Dictionary = _table(table, {})
		for key: String in t.keys():
			if key.ends_with("|" + uid):
				t.erase(key)
