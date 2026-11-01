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

## Where the fake server keeps its data between runs ("" = memory only, as in tests).
var store_path: String = ""
## {"users": {uid: user}, "config": {...}}; a user holds "profile" and "saves".
var db: Dictionary = {"users": {}, "config": {"min_version": 1, "motd": ""}}
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
			"transfer_create", "transfer_claim"]:
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
		if not db.get("config") is Dictionary:
			db["config"] = {"min_version": 1, "motd": ""}

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
	if not save_ok(a.get("p_data")):
		return {"ok": false, "error": "implausible"}
	var saves: Dictionary = _saves()
	var cur: Variant = saves.get(str(slot))
	if cur != null and int(cur.rev) != int(a.get("p_base_rev", 0)) and not bool(a.get("p_force", false)):
		return {"ok": false, "conflict": true, "rev": cur.rev, "saved_at": cur.saved_at, "summary": cur.summary}
	var rev: int = (int(cur.rev) if cur != null else 0) + 1
	saves[str(slot)] = {"rev": rev, "data": (a.p_data as Dictionary).duplicate(true),
		"summary": str(a.get("p_summary", "")).left(60), "saved_at": now()}
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

## Later parts move their own rows from [param old] to [param new] here.
func _move_account(_old: String, _new: String) -> void:
	pass

## Later parts remove a deleted player from their own tables here.
func _on_delete_user(_uid: String) -> void:
	pass
