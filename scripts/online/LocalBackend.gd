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
	"party_max": 5, "level_max": 60, "duel_ring": 50, "save_schema_max": 1, "battle_submit_limit": 60,
	"league_fair_ring": 50, "league_season_days": 42, "league_closing_minutes": 30, "league_search_start": 100,
	"league_search_step": 50, "league_search_max": 400, "league_match_minutes": 30, "league_ai": 2,
	"league_fair_blocked_sources": [],
	"max_money_per_min": 5000, "save_time_slack": 300, "start_money": 3000, "cheat_flag_limit": 3, "cheat_flag_days": 7,
	"data_export_limit": 5,
	"save_server_keys": ["league", "leagues", "raid", "raids", "trades", "bund", "premium", "gems", "shards"],
}
const BATTLE_KINDS: Array[String] = ["echo_duel", "league_fair", "league_open", "raid", "live_duel"]
## Same rows as public.feature_flags (20261110000001_online_rules.sql): all off at first.
const DEFAULT_FLAGS: Dictionary = {
	"league_fair": {"enabled": true, "min_version": 1}, "league_open": {"enabled": true, "min_version": 1},
	"live_duel": {"enabled": false, "min_version": 1}, "trade": {"enabled": false, "min_version": 1},
	"bund": {"enabled": false, "min_version": 1}, "raid": {"enabled": false, "min_version": 1},
}

## Where the fake server keeps its data between runs ("" = memory only, as in tests).
var store_path: String = ""
## {"users": {uid: user}, "config": {...}}; a user holds "profile" and "saves".
var db: Dictionary = {"users": {}, "config": DEFAULT_CONFIG.duplicate(true), "flags": DEFAULT_FLAGS.duplicate(true)}
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
			"community_get", "community_add", "community_claim", "weekly_submit", "weekly_board",
			"battle_submit", "battle_status", "league_info", "league_join", "league_find", "data_export"]:
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
		var flags: Dictionary = DEFAULT_FLAGS.duplicate(true)
		if db.get("flags") is Dictionary:
			flags.merge(db.flags, true)
		db["flags"] = flags

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
		u["profile"] = {"code": _new_code(), "name": "Wanderer", "color": 0, "favorite": "", "card": {},
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
	var fallback: String = "Wanderer " + code.right(4)
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

## Whole-number config value, like public._config_int.
func config_int(key: String, fallback: int) -> int:
	var v: Variant = db.config.get(key, fallback)
	return int(v) if (v is int or v is float) else fallback

## Like public._flag_on: the feature is on for this client version.
func flag_on(key: String, version: int) -> bool:
	var f: Variant = db.flags.get(key)
	return f is Dictionary and bool(f.get("enabled", false)) and version >= int(f.get("min_version", 1))

## Like public._save_ok: real game limits (team of party_max, Ring 1..level_max).
static func save_ok(d: Variant, party_max: int = 5, level_max: int = 60) -> bool:
	if not d is Dictionary:
		return false
	if JSON.stringify(d).length() > 400000:
		return false
	var party: Variant = d.get("party", [])
	var storage: Variant = d.get("storage", [])
	if not party is Array or not storage is Array or (party as Array).size() > party_max:
		return false
	var money: Variant = d.get("money", 0)
	if not (money is int or money is float) or float(money) < 0 or float(money) > 9999999:
		return false
	for s: Variant in (party as Array) + (storage as Array):
		if s is Dictionary:
			var lvl: Variant = s.get("level", 1)
			if not (lvl is int or lvl is float) or float(lvl) < 1 or float(lvl) > level_max:
				return false
	return true

## Like public._save_schema_ok: a whole number from 1 to save_schema_max.
## JSON numbers come back as floats in Godot, so 1.0 counts as whole.
static func save_schema_ok(d: Variant, schema_max: int = 1) -> bool:
	if not d is Dictionary:
		return false
	var v: Variant = (d as Dictionary).get("schema")
	if not (v is int or v is float):
		return false
	return float(v) == floorf(float(v)) and float(v) >= 1 and float(v) <= schema_max

# --- Core functions (20261101000001_online_core.sql) ---------------------------------------

func _fn_hello(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	p.last_seen = now()
	return {"profile": profile_json(p), "server_time": now(),
		"update_required": int(a.get("p_version", 0)) < int(db.config.get("min_version", 1)),
		"motd": str(db.config.get("motd", "")), "online_now": online_now(),
		"flags": active_flags(int(a.get("p_version", 0)))}

## Like hello's "flags": the feature keys that are on for [param version], sorted (item 2675).
func active_flags(version: int) -> Array:
	var out: Array = []
	for key: String in db.flags:
		if flag_on(key, version):
			out.append(key)
	out.sort()
	return out

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
	if not save_schema_ok(a.get("p_data"), config_int("save_schema_max", 1)):
		return {"ok": false, "error": "schema"}
	if not save_ok(a.get("p_data"), config_int("party_max", 5), config_int("level_max", 60)):
		return {"ok": false, "error": "implausible"}
	var data: Dictionary = (a.p_data as Dictionary).duplicate(true)
	# Values the server keeps itself are dropped (item 2924).
	for k: Variant in db.config.get("save_server_keys", []):
		data.erase(str(k))
	var saves: Dictionary = _saves()
	var cur: Variant = saves.get(str(slot))
	var rid: String = str(a.get("p_request_id", "")).left(64) if a.get("p_request_id") != null else ""
	# The same upload again after a lost answer is already stored (plan item 3658).
	if cur != null and not rid.is_empty() and str(cur.get("request_id", "")) == rid:
		return {"ok": true, "rev": cur.rev, "saved_at": cur.saved_at, "repeat": true}
	if cur != null and int(cur.rev) != int(a.get("p_base_rev", 0)) and not bool(a.get("p_force", false)):
		return {"ok": false, "conflict": true, "rev": cur.rev, "saved_at": cur.saved_at, "summary": cur.summary}
	var why: String = save_cheat(cur.data if cur != null else null, int(cur.saved_at) if cur != null else 0, data)
	if not why.is_empty():
		var flags: Array = _user().get_or_add("cheat_flags", [])
		# The game tries again at the next save; the same refusal counts once per 10 minutes.
		if not flags.any(func(f: Dictionary) -> bool: return int(f.slot) == slot and f.reason == why and int(f.at) > now() - 600):
			flags.append({"slot": slot, "reason": why, "at": now()})
		return {"ok": false, "error": "refused", "reason": why}
	var rev: int = (int(cur.rev) if cur != null else 0) + 1
	saves[str(slot)] = {"rev": rev, "data": data,
		"summary": str(a.get("p_summary", "")).left(60), "saved_at": now(), "request_id": rid}
	return {"ok": true, "rev": rev, "saved_at": now()}

## Like public._save_cheat (items 2921-2923): why a new save is refused, or "".
func save_cheat(old: Variant, old_at: int, d: Dictionary) -> String:
	var old_pt: float = 0.0
	var new_pt: float = float(d.get("play_time", 0)) if d.get("play_time") is float or d.get("play_time") is int else 0.0
	var old_money: float = config_int("start_money", 3000)
	var new_money: float = float(d.get("money", 0)) if d.get("money") is float or d.get("money") is int else 0.0
	if old is Dictionary and (old.get("play_time") is float or old.get("play_time") is int):
		old_pt = float(old.play_time)
		if new_pt >= old_pt:
			old_money = maxf(float(old.get("money", 0)) if old.get("money") is float or old.get("money") is int else 0.0, 0.0)
			if new_pt - old_pt > (now() - old_at) + config_int("save_time_slack", 300):
				return "play_time_fast"
		else:
			old_pt = 0.0
	var played_min: float = maxf(ceilf((new_pt - old_pt) / 60.0), 1.0)
	if new_money - old_money > config_int("max_money_per_min", 5000) * played_min:
		return "money_fast"
	var mons: Array = []
	for k: String in ["party", "storage", "sanctuary"]:
		if d.get(k) is Array:
			mons.append_array(d[k])
	for m: Variant in mons:
		if not m is Dictionary:
			continue
		var sp: String = str(m.get("species", "")) if m.get("species") != null else ""
		if not sp.is_empty() and Database.species(sp) == null:
			return "unknown_species"
	for m: Variant in mons:
		if m is Dictionary and m.get("moves") is Array:
			for mv: Variant in m.moves:
				if mv != null and not str(mv).is_empty() and Database.move(str(mv)) == null:
					return "unknown_move"
	var items: Array = []
	for m: Variant in mons:
		if m is Dictionary and m.get("held") != null:
			items.append(str(m.held))
	if d.get("inventory") is Dictionary:
		items.append_array((d.inventory as Dictionary).keys())
	for it: Variant in items:
		if not str(it).is_empty() and Database.item(str(it)).is_empty():
			return "unknown_item"
	return ""

## Like public._cheat_held (item 2925): enough refused saves lately, and Ali has not cleared it.
func cheat_held(uid: String) -> bool:
	var u: Dictionary = db.users.get(uid, {})
	var since: int = maxi(now() - config_int("cheat_flag_days", 7) * 86400, int(u.get("cheat_cleared_at", 0)))
	var n: int = 0
	for f: Dictionary in u.get("cheat_flags", []):
		if int(f.at) > since:
			n += 1
	return n >= config_int("cheat_flag_limit", 3)

func _fn_save_delete(a: Dictionary) -> Dictionary:
	var had: bool = _saves().erase(str(int(a.get("p_slot", 0))))
	return {"ok": true, "deleted": 1 if had else 0}

func _fn_delete_account(_a: Dictionary) -> Dictionary:
	var uid: String = me()
	_on_delete_user(uid)
	_purge(uid)
	db.users.erase(uid)
	session = {}
	return {"ok": true}

## Tables of [member db] that hold rows of players (everything but accounts and settings).
func _shared_tables() -> Array[String]:
	var out: Array[String] = []
	for name: String in db.keys():
		if not ["users", "config", "flags"].has(name) and (db[name] is Dictionary or db[name] is Array):
			out.append(name)
	out.sort()
	return out

## True when [param v] (or the row key [param key]) carries the account id [param uid].
func _mentions(v: Variant, uid: String, key: String = "") -> bool:
	if not key.is_empty() and (key == uid or key.split("|").has(uid)):
		return true
	if v is String:
		return v == uid
	if v is Array:
		return (v as Array).any(func(x: Variant) -> bool: return _mentions(x, uid))
	if v is Dictionary:
		for k: Variant in v:
			if _mentions(v[k], uid, str(k)):
				return true
	return false

## Like public._export_row: the player's id reads "you", other players' ids "another player".
func _mask(v: Variant, uid: String) -> Variant:
	if v is String:
		return "you" if v == uid else ("another player" if db.users.has(v) else v)
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _mask(x, uid))
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in v:
			out[_mask_key(str(k), uid)] = _mask(v[k], uid)
		return out
	return v

func _mask_key(k: String, uid: String) -> String:
	var parts: PackedStringArray = k.split("|")
	for i: int in parts.size():
		parts[i] = str(_mask(parts[i], uid))
	return "|".join(parts)

## Like public.data_export (item 2972): every row that carries the account, other players hidden.
func _fn_data_export(_a: Dictionary) -> Dictionary:
	var uid: String = me()
	profile_of(uid)
	if not _rate_ok("data_export", config_int("data_export_limit", 5)):
		return _fail("slow_down")
	var tables: Dictionary = {"account": _mask(db.users[uid], uid)}
	for name: String in _shared_tables():
		var rows: Array = []
		var t: Variant = db[name]
		if t is Dictionary:
			for k: Variant in t:
				if _mentions(t[k], uid, str(k)):
					rows.append({"key": _mask_key(str(k), uid), "row": _mask(t[k], uid)})
		else:
			for row: Variant in t:
				if _mentions(row, uid):
					rows.append(_mask(row, uid))
		tables[name] = rows
	return {"ok": true, "exported_at": now(), "format": 1, "tables": tables}

## Like the end of public.delete_account (2973): no row anywhere still carries the account.
func _purge(uid: String) -> void:
	for name: String in _shared_tables():
		var t: Variant = db[name]
		if t is Dictionary:
			for k: Variant in (t as Dictionary).keys():
				if _mentions(t[k], uid, str(k)):
					t.erase(k)
		else:
			db[name] = (t as Array).filter(func(row: Variant) -> bool: return not _mentions(row, uid))

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
	var level_max: int = config_int("level_max", 60)
	for s: Variant in (given as Array).slice(0, config_int("party_max", 5)):
		var d: Dictionary = s if s is Dictionary else {}
		var moves: Array = []
		var mv_list: Variant = d.get("moves", [])
		for mv: Variant in (mv_list as Array if mv_list is Array else []).slice(0, 4):
			moves.append(_keep(str(mv), " '-").left(24))
		var lvl: Variant = d.get("level", 1)
		clean.append({"species": _keep(str(d.get("species", "")), "").left(20),
			"level": clampi(int(lvl) if (lvl is int or lvl is float) else 1, 1, level_max), "moves": moves})
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
	return {"ok": true, "name": p.name, "color": p.color, "team": (p.get("team", []) as Array).duplicate(true),
		"duel_ring": clampi(config_int("duel_ring", 50), 1, config_int("level_max", 60))}

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
	var battles: Dictionary = _table("battles", {})
	for key: String in battles.keys():
		if battles[key].user == uid:
			battles.erase(key)
	for table: String in ["league_fair", "league_open"]:
		var t: Dictionary = _table(table, {})
		for key: String in t.keys():
			if key.ends_with("|" + uid):
				t.erase(key)
	var matches: Dictionary = _table("league_matches", {})
	for key: String in matches.keys():
		if matches[key].user == uid:
			matches.erase(key)

# --- Battle referee (20261110000002_referee.sql) --------------------------------------------

## Like public.battle_submit. The local stand-in has no queue: the referee runs at once,
## with the same code as server/referee/ (BattleReferee), unless [member referee_waits] is set.
func _fn_battle_submit(a: Dictionary) -> Dictionary:
	var kind: String = str(a.get("p_kind", ""))
	if not BATTLE_KINDS.has(kind):
		return _fail("bad_kind")
	var replay: Variant = a.get("p_replay")
	var claim: Variant = a.get("p_claim")
	if not replay is Dictionary or not claim is Dictionary or not (replay as Dictionary).get("teams") is Array \
			or JSON.stringify(replay).length() > 200000 or JSON.stringify(claim).length() > 4000:
		return _fail("bad_battle")
	var inputs: Variant = (replay as Dictionary).get("inputs", [])
	if not inputs is Array or (inputs as Array).size() > BattleReferee.MAX_INPUTS:
		return _fail("bad_battle")
	if not _rate_ok("battle", config_int("battle_submit_limit", 60)):
		return _fail("slow_down")
	var c: Dictionary = (claim as Dictionary).duplicate(true)
	c.erase("expect")
	var lm: Dictionary = {}
	if kind == "league_fair" or kind == "league_open":
		var mv: Variant = (_table("league_matches", {}) as Dictionary).get(str(a.get("p_ref", "")))
		if not mv is Dictionary or mv.user != me() or mv.league != kind.substr(7):
			return _fail("no_such_match")
		lm = mv
		if lm.state != "open" or now() - int(lm.created_at) > 60 * config_int("league_match_minutes", 30):
			return _fail("match_closed")
		c["expect"] = _league_expect(lm)
	var battles: Dictionary = _table("battles", {})
	var id: int = int(db.get("battle_seq", 0)) + 1
	db["battle_seq"] = id
	var row: Dictionary = {"user": me(), "kind": kind, "ref": str(a.get("p_ref", "")).left(40), "status": "pending"}
	battles[str(id)] = row
	if not lm.is_empty():
		lm.state = "submitted"
		lm.battle_id = id
		lm.rated = bool(lm.rated) and league_state(league_season()) == "running"
	if referee_waits:
		row["queued"] = {"replay": (replay as Dictionary).duplicate(true), "claim": c}
	else:
		_decide(id, BattleReferee.check(replay, c))
	return {"ok": true, "battle_id": id, "status": "pending"}

## Tests: battles stay "pending" until [method referee_run] (like the real queue).
var referee_waits: bool = false

## Decides every waiting battle, like one run of server/referee/run.sh.
func referee_run() -> int:
	var n: int = 0
	for key: String in (_table("battles", {}) as Dictionary):
		var row: Dictionary = db.battles[key]
		if row.has("queued"):
			var q: Dictionary = row.queued
			row.erase("queued")
			_decide(int(key), BattleReferee.check(q.replay, q.claim))
			n += 1
	return n

## Like the battle_results trigger: the state, then league ratings.
func _decide(id: int, result: Dictionary) -> void:
	var row: Dictionary = db.battles[str(id)]
	row.status = str(result.verdict)
	if row.kind == "league_fair" or row.kind == "league_open":
		for key: String in (_table("league_matches", {}) as Dictionary):
			var m: Dictionary = db.league_matches[key]
			if int(m.get("battle_id", -1)) == id and m.state == "submitted":
				if row.status == "ok":
					_league_apply(m, result.detail)
				else:
					m.state = "done"
					m.rated = false

func _fn_battle_status(a: Dictionary) -> Dictionary:
	var row: Variant = (_table("battles", {}) as Dictionary).get(str(int(a.get("p_battle_id", -1))))
	if not row is Dictionary or row.user != me():
		return _fail("no_such_battle")
	return {"ok": true, "status": row.status}

## Like public._battle_ok: leagues, raids and weekly scores only count "ok" battles.
func battle_ok(battle_id: int) -> bool:
	var row: Variant = (_table("battles", {}) as Dictionary).get(str(battle_id))
	return row is Dictionary and row.status == "ok"

# --- Leagues (20261110000003_league.sql) ----------------------------------------------------

## Like public._league_season: the season of now, started by itself after the last one.
func league_season() -> Dictionary:
	var seasons: Array = _table("league_seasons", [])
	for i: int in range(seasons.size() - 1, -1, -1):
		var sn: Dictionary = seasons[i]
		if now() >= int(sn.starts_at) and now() < int(sn.ends_at):
			return sn
	var day: int = now() - now() % 86400
	var sn: Dictionary = {"id": seasons.size() + 1, "starts_at": day,
		"ends_at": day + 86400 * config_int("league_season_days", 42), "rules_version": 1, "state": "running"}
	seasons.append(sn)
	return sn

## "running", "closing" (last 30 minutes) or "paused".
func league_state(sn: Dictionary) -> String:
	if sn.state == "paused":
		return "paused"
	if now() >= int(sn.ends_at) - 60 * config_int("league_closing_minutes", 30):
		return "closing"
	return "running"

func league_entry(league: String, season: int, uid: String) -> Variant:
	return (_table("league_" + league, {}) as Dictionary).get("%d|%s" % [season, uid])

func _league_check(league: String) -> String:
	if league != LeagueRules.FAIR and league != LeagueRules.OPEN:
		return "bad_league"
	if not flag_on("league_" + league, 2147483647):
		return "feature_off"
	if not session.is_empty() and db.users.has(me()) and cheat_held(me()):
		return "under_review"
	return ""

func _fn_league_info(a: Dictionary) -> Dictionary:
	var league: String = str(a.get("p_league", ""))
	var err: String = _league_check(league)
	if not err.is_empty():
		return _fail(err)
	profile_of(me())
	var sn: Dictionary = league_season()
	var e: Variant = league_entry(league, int(sn.id), me())
	return {"ok": true, "season": sn.id, "ends_at": sn.ends_at, "state": league_state(sn), "rules_version": sn.rules_version,
		"ring": config_int("league_fair_ring", 50) if league == LeagueRules.FAIR else config_int("level_max", 60),
		"joined": e != null, "team": (e.team as Array).duplicate(true) if e != null else [],
		"tier": LeagueRules.tier(float(e.rating)) if e != null else null,
		"games": int(e.games) if e != null else 0, "wins": int(e.wins) if e != null else 0}

func _fn_league_join(a: Dictionary) -> Dictionary:
	var league: String = str(a.get("p_league", ""))
	var err: String = _league_check(league)
	if not err.is_empty():
		return _fail(err)
	var sn: Dictionary = league_season()
	if league_state(sn) == "paused":
		return _fail("season_paused")
	if not _rate_ok("league_join", 30):
		return _fail("slow_down")
	var saved: Array = profile_of(me()).get("team", [])
	var built: Dictionary = LeagueRules.build_team(saved, league, a.get("p_pick"), config_int("league_fair_ring", 50), config_int("level_max", 60))
	if built.has("error"):
		return _fail(str(built.error))
	var key: String = "%d|%s" % [int(sn.id), me()]
	var t: Dictionary = _table("league_" + league, {})
	if not t.has(key):
		t[key] = {"rating": Glicko.START_RATING, "rd": Glicko.START_RD, "vol": Glicko.START_VOL, "games": 0, "wins": 0}
	t[key].team = built.team
	return {"ok": true, "team": (built.team as Array).duplicate(true)}

func _fn_league_find(a: Dictionary) -> Dictionary:
	var league: String = str(a.get("p_league", ""))
	var err: String = _league_check(league)
	if not err.is_empty():
		return _fail(err)
	var sn: Dictionary = league_season()
	if league_state(sn) == "paused":
		return _fail("season_paused")
	var mine: Variant = league_entry(league, int(sn.id), me())
	if mine == null:
		return _fail("not_joined")
	if not _rate_ok("league_find", 240):
		return _fail("slow_down")
	var waited: int = maxi(0, int(a.get("p_waited", 0)))
	var span: float = minf(config_int("league_search_start", 100) + config_int("league_search_step", 50) * floorf(waited / 10.0),
		config_int("league_search_max", 400))
	var best: String = ""
	var best_d: float = INF
	var t: Dictionary = _table("league_" + league, {})
	for key: String in t:
		var parts: PackedStringArray = key.split("|")
		if int(parts[0]) != int(sn.id) or parts[1] == me() or is_blocked(me(), parts[1]):
			continue
		var d: float = absf(float(t[key].rating) - float(mine.rating))
		if d <= span and d < best_d:
			best = parts[1]
			best_d = d
	if best.is_empty():
		return {"ok": true, "found": false, "range": span}
	var matches: Dictionary = _table("league_matches", {})
	for key: String in matches:
		if matches[key].user == me() and matches[key].state == "open":
			matches[key].state = "expired"
	var opp: Dictionary = t["%d|%s" % [int(sn.id), best]]
	var id: int = int(db.get("league_match_seq", 0)) + 1
	db["league_match_seq"] = id
	var teams: Array = [(mine.team as Array).duplicate(true), (opp.team as Array).duplicate(true)]
	var rated: bool = league_state(sn) == "running"
	matches[str(id)] = {"league": league, "season": int(sn.id), "user": me(), "opponent": best, "seed": rng.randi() & 0x7fffffff,
		"teams": teams, "created_at": now(), "state": "open", "rated": rated}
	return {"ok": true, "found": true, "match_id": id, "seed": matches[str(id)].seed, "teams": teams.duplicate(true),
		"ai": config_int("league_ai", 2), "opponent_tier": LeagueRules.tier(float(opp.rating)), "range": span, "rated": rated}

func _league_expect(m: Dictionary) -> Dictionary:
	return {"seed": m.seed, "teams": (m.teams as Array).duplicate(true), "ai": config_int("league_ai", 2), "wild": false,
		"front": [1, 1], "items_allowed": false}

## Like public._league_apply: only the player who fought is rated.
func _league_apply(m: Dictionary, detail: Variant) -> void:
	var score: float = 1.0 if detail is Dictionary and str(detail.get("winner", "")) == "player" else 0.0
	m.state = "done"
	m.score = score
	if not bool(m.rated):
		return
	var e: Variant = league_entry(m.league, int(m.season), m.user)
	if e == null:
		return
	var o: Variant = league_entry(m.league, int(m.season), str(m.opponent))
	var nr: Dictionary = Glicko.rate(float(e.rating), float(e.rd), float(e.vol),
		float(o.rating) if o != null else Glicko.START_RATING, float(o.rd) if o != null else Glicko.START_RD, score)
	e.rating = nr.rating
	e.rd = nr.rd
	e.vol = nr.vol
	e.games = int(e.games) + 1
	e.wins = int(e.wins) + int(score)
