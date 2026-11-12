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
	"party_max": 5, "level_max": 60, "save_level_max": 9999, "duel_ring": 50, "save_schema_max": 1, "battle_submit_limit": 60,
	"league_fair_ring": 50, "league_season_days": 42, "league_closing_minutes": 30, "league_search_start": 100,
	"league_search_step": 50, "league_search_max": 400, "league_match_minutes": 30, "league_ai": 2,
	"league_fair_blocked_sources": [],
	"max_money_per_min": 5000, "save_time_slack": 300, "start_money": 3000, "cheat_flag_limit": 3, "cheat_flag_days": 7,
	"data_export_limit": 5,
	"raid_guardians": ["Leviarch", "Calderox", "Cairnhold", "Verdantusk", "Tempestrel", "Solmantle", "Obsidroth"],
	"raid_rewards": [{"item": "max_tonic", "count": 2, "w": 3}, {"item": "revival_leaf", "count": 2, "w": 3},
		{"item": "strong_tonic", "count": 5, "w": 3}, {"item": "keen_lens", "count": 1, "w": 1}, {"item": "swift_feather", "count": 1, "w": 1}],
	"trade_min_level": 3, "trade_min_days": 7, "trade_max_open": 5, "trade_max_kinds": 6, "trade_max_count": 99, "trade_days": 7,
	"save_server_keys": ["league", "leagues", "raid", "raids", "trades", "bund", "premium", "gems", "shards"],
	"trade_max_spirlings": 3, "board_rows": 20,
	"daily_gift_table": [{"item": "tonic", "w": 30}, {"item": "remedy", "w": 20}, {"item": "strong_tonic", "w": 15},
		{"item": "spark_drop", "w": 10}, {"item": "cooling_gel", "w": 5}, {"item": "dry_towel", "w": 5},
		{"item": "wake_bell", "w": 5}, {"item": "power_brew", "w": 2}, {"item": "guard_brew", "w": 2},
		{"item": "focus_brew", "w": 2}, {"item": "dash_brew", "w": 2}, {"item": "revival_leaf", "w": 2}],
}
const BATTLE_KINDS: Array[String] = ["echo_duel", "league_fair", "league_open", "raid", "live_duel", "rift"]
## Same rows as public.feature_flags (20261110000001_online_rules.sql): all off at first.
const DEFAULT_FLAGS: Dictionary = {
	"league_fair": {"enabled": true, "min_version": 1}, "league_open": {"enabled": true, "min_version": 1},
	"live_duel": {"enabled": false, "min_version": 1}, "trade": {"enabled": false, "min_version": 1},
	"bund": {"enabled": false, "min_version": 1}, "raid": {"enabled": false, "min_version": 1},
	"trade_spirling": {"enabled": false, "min_version": 1}, "rift_board": {"enabled": false, "min_version": 1},
	"league_board": {"enabled": false, "min_version": 1}, "daily_gift": {"enabled": false, "min_version": 1},
	"lend": {"enabled": false, "min_version": 1},
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
			"battle_submit", "battle_status", "league_info", "league_join", "league_find", "data_export",
			"report_in", "notices_list", "notice_read", "appeal", "platform_set",
			"bund_create", "bund_info", "bund_invite", "bund_request", "bund_answer", "bund_admit", "bund_kick", "bund_role",
			"bund_leave", "bund_dissolve", "bund_keep", "raid_open", "raid_list", "raid_start", "raid_claim",
			"trade_open", "trade_list", "trade_put", "trade_confirm", "trade_cancel", "trade_collect",
			"trade_put_spirlings", "rift_board", "league_board", "daily_gift_state", "daily_gift_claim", "league_reward",
			"live_invite", "live_list", "live_answer", "live_pick", "live_move", "live_state", "live_emote", "live_forfeit",
			"live_finish", "live_rematch", "raid_board",
			"bund_stats", "bund_settings", "bund_search", "bund_join", "bund_donate", "bund_goal_claim", "bund_board",
			"save_history_list", "save_restore", "session_claim", "action_once", "live_content_get"]:
		_fns[fn] = Callable(self, "_fn_" + fn)
	# Shop functions (20261110000020_shop.sql) live in their own file.
	LocalShop.install(self)
	# Planned maintenance (Online 100 point 95, 20261112230010_maintenance.sql).
	_fns["maintenance_info"] = Callable(self, "_fn_maintenance_info")
	# Trading and gifting, Online 100 area 5 (20261112000050_trade_gifts.sql).
	LocalTradeGifts.install(self)
	# Online events (20261112000070_online_events.sql) live in their own file too.
	LocalOnlineEvents.install(self)

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
	# Like the trigger saves_device: a changed save from an older device fails (plan item 3010).
	if name in SAVE_WRITERS and other_device():
		return fail("other_device")
	var r: Variant = _fns[name].call(args)
	_save()
	return ok(r)

## Like public.action_once (plan item 3011): a small action whose id was seen in the last 2 days
## counts once.
func _fn_action_once(a: Dictionary) -> Dictionary:
	var id: String = str(a.get("p_id", "")).left(40)
	if id.length() < 8:
		return _fail("bad_id")
	var done: Dictionary = _user().get_or_add("actions_done", {})
	for k: String in done.keys():
		if int(done[k]) < now() - 2 * 86400:
			done.erase(k)
	if done.has(id):
		return {"ok": true, "repeat": true}
	var args: Dictionary = a.get("p_args", {}) if a.get("p_args") is Dictionary else {}
	var r: Variant
	if str(a.get("p_fn", "")) == "mail_send" and str(args.get("p_kind", "")) in ["phrase", "wave", "thanks"]:
		r = _fn_mail_send({"p_code": args.get("p_code"), "p_kind": args.get("p_kind"), "p_phrase": int(args.get("p_phrase", 0))})
	elif str(a.get("p_fn", "")) == "community_add":
		r = _fn_community_add({"p_kind": args.get("p_kind"), "p_amount": int(args.get("p_amount", 0))})
	else:
		return _fail("bad_action")
	if not (r is Dictionary and str((r as Dictionary).get("error", "")) == "slow_down"):
		done[id] = now()
	return r

## Functions that change a stored save (the server checks them in a trigger on saves).
const SAVE_WRITERS: Array[String] = ["save_put", "save_restore", "trade_put", "trade_collect", "trade_put_spirlings",
	"daily_gift_claim", "league_reward", "bund_donate", "bund_goal_claim", "event_claim", "event_reward"]

## Like public._other_device: this device's token is not the newest one of the account.
func other_device() -> bool:
	var t: String = str(profile_of(me()).get("session_token", ""))
	return not t.is_empty() and not device_token.is_empty() and t != device_token

func _fn_session_claim(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	var cur: String = str(p.get("session_token", ""))
	var t: String = str(a.get("p_token", "")).left(64) if a.get("p_token") != null else ""
	if not t.is_empty() and not cur.is_empty() and cur != t:
		return _fail("other_device")
	if t.is_empty() or cur.is_empty():
		t = "%08x%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()]
		p["session_token"] = t
	return {"ok": true, "token": t}

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
	# At most 3 digits and no web address, so nobody passes on a phone number (item 2878).
	var digits: int = 0
	for ch: String in n:
		if ch >= "0" and ch <= "9":
			digits += 1
	var squashed: String = n.to_lower().replace(" ", "")
	if digits > 3 or squashed.contains("www") or squashed.contains("http"):
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
		"card": p.card, "place": p.place, "social": p.social, "platform": str(p.get("platform", "app"))}

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

## The account's shop unlocks (entitlements), key -> count.
func _unlocks(uid: String) -> Dictionary:
	var shop: Variant = (db.users.get(uid, {}) as Dictionary).get("shop", {})
	var u: Variant = shop.get("unlocks", {}) if shop is Dictionary else {}
	return u if u is Dictionary else {}

## Like public._party_max: one more with the shop's sixth team slot (plan area 10).
func party_max_of(uid: String) -> int:
	var shop: Variant = (db.users.get(uid, {}) as Dictionary).get("shop", {})
	var unlocks: Variant = shop.get("unlocks", {}) if shop is Dictionary else {}
	return config_int("party_max", 5) + (1 if unlocks is Dictionary and int(unlocks.get("team_slot_6", 0)) > 0 else 0)

## Like public._save_ok: real game limits (team of party_max, Ring 1..save_level_max). Spirlings
## have no top ring, so save_level_max is only a sanity bound (Spirling.LEVEL_SANITY, 9999)
## against garbage; level_max (60) stays the echo team, league and duel ring.
static func save_ok(d: Variant, party_max: int = 5, level_max: int = Spirling.LEVEL_SANITY) -> bool:
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

## Like public.live_content_get: the local stand-in has no patches, the bundled one is used.
func _fn_live_content_get(_a: Dictionary) -> Dictionary:
	return {"version": 0}

## Like hello's "flags": the feature keys that are on for [param version], sorted (item 2675).
func active_flags(version: int) -> Array:
	var out: Array = []
	for key: String in db.flags:
		if flag_on(key, version):
			out.append(key)
	out.sort()
	return out

## Like public.platform_set (item 3765).
func _fn_platform_set(a: Dictionary) -> Dictionary:
	var plat: String = str(a.get("p_platform", ""))
	if not plat in ["app", "web"]:
		return {"ok": false, "error": "bad_platform"}
	profile_of(me())["platform"] = plat
	return {"ok": true, "platform": plat}

func _fn_profile_set(a: Dictionary) -> Dictionary:
	var p: Dictionary = profile_of(me())
	var card: Dictionary = {}
	var given: Variant = a.get("p_card", {})
	if given is Dictionary:
		for k: String in ["seals", "seen", "bonded", "hours", "achievements"]:
			var v: Variant = given.get(k)
			if v is int or v is float:
				card[k] = clampi(int(v), 0, 99999)
		# A bought profile frame only with its unlock (20261110000024_shop_card_frames.sql).
		var fr: Variant = given.get("frame")
		if fr is String and fr in FriendsMenu.CARD_FRAMES and int(_unlocks(me()).get("card_frame_" + fr, 0)) > 0:
			card["frame"] = fr
		# A bought greeting card motif for gifts (20261110000025_shop_gift_cards.sql).
		var mo: Variant = given.get("motif")
		if mo is String and FriendsMenu.GIFT_CARDS.has(mo) and int(_unlocks(me()).get("gift_card_" + mo, 0)) > 0:
			card["motif"] = mo
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
	return {"server_time": now(), "online_now": online_now(), "other_device": other_device()}

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
	if not save_ok(a.get("p_data"), party_max_of(me()), config_int("save_level_max", Spirling.LEVEL_SANITY)):
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
	keep_history(slot, cur, data)
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
		if not ["users", "config", "flags", "next_ids"].has(name) and (db[name] is Dictionary or db[name] is Array):
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
		f["accepted_at"] = now()
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
				f["accepted_at"] = now()
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
	return _fn_report_in({"p_code": a.get("p_code", ""), "p_reason": a.get("p_reason", 3), "p_context": "friends"})

const REPORT_CONTEXTS: Array[String] = ["friends", "card", "duel", "trade", "bund", "raid", "board", "league"]
const MOD_ACTIONS: Array[String] = ["name_reset", "warning", "league_block", "none"]

## Like public.report_in (items 2895, 2916): a report from anywhere, answered with its number.
func _fn_report_in(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == me():
		return _fail("no_such_code")
	var ctx: String = str(a.get("p_context", ""))
	if not REPORT_CONTEXTS.has(ctx):
		return _fail("bad_context")
	if not _rate_ok("report", 10):
		return _fail("slow_down")
	var id: int = _next_id("report")
	var obj: String = str(a.get("p_object", "") if a.get("p_object") != null else "").left(40)
	(_table("reports", []) as Array).append({"id": id, "reporter": me(), "target": t, "target_name": profile_of(t).name,
		"reason": clampi(int(a.get("p_reason", 3)), 0, 3), "context": ctx, "object_id": obj, "status": "open",
		"action": "", "at": now()})
	return {"ok": true, "report_id": id}

func _next_id(kind: String) -> int:
	var ids: Dictionary = _table("next_ids", {})
	ids[kind] = int(ids.get(kind, 0)) + 1
	return int(ids[kind])

## Every rule is in section 4 of the terms ("Verhaltensregeln"), like public._mod_reason_rule.
static func mod_reason_rule(_reason: int) -> String:
	return "4"

func _notice(uid: String, kind: String, report_id: int, body: Dictionary) -> void:
	if not db.users.has(uid):
		return
	(_table("notices", []) as Array).append({"id": _next_id("notice"), "user_id": uid, "kind": kind,
		"report_id": report_id, "body": body, "at": now(), "read": false})

## Like public.moderation_decide (items 2896, 2898): only Ali calls it, from the console.
func moderation_decide(report_id: int, upheld: bool, action: String = "warning") -> Dictionary:
	var act: String = action if upheld else "none"
	if not MOD_ACTIONS.has(act):
		return _fail("bad_action")
	var r: Dictionary = {}
	for row: Dictionary in _table("reports", []):
		if int(row.get("id", 0)) == report_id:
			r = row
	if r.is_empty():
		return _fail("no_such_report")
	if r.status != "open":
		return _fail("decided")
	r.status = "upheld" if upheld else "rejected"
	r.action = act
	r.decided_at = now()
	if upheld:
		if act == "name_reset":
			var p: Dictionary = profile_of(r.target)
			p.name = "Wanderer " + str(p.code).right(4)
		elif act == "league_block" and db.users.has(r.target):
			var flags: Array = (db.users[r.target] as Dictionary).get_or_add("cheat_flags", [])
			for i: int in config_int("cheat_flag_limit", 3):
				flags.append({"slot": 0, "reason": "moderation", "at": now()})
		_notice(r.target, "decision", report_id, {"action": act, "reason": r.reason, "rule": mod_reason_rule(int(r.reason)),
			"context": r.context, "automated": false, "appeal_until": now() + 183 * 86400})
	if not str(r.get("reporter", "")).is_empty():
		_notice(r.reporter, "report_result", report_id, {"upheld": upheld})
	return {"ok": true}

func _fn_notices_list(_a: Dictionary) -> Dictionary:
	var out: Array = []
	for n: Dictionary in _table("notices", []):
		if n.user_id != me():
			continue
		var ap: Dictionary = _appeal_of(int(n.id))
		out.push_front({"id": n.id, "kind": n.kind, "report_id": n.report_id, "body": n.body, "at": n.at, "read": n.read,
			"appealed": not ap.is_empty(), "appeal": ap.get("status")})
	return {"ok": true, "notices": out}

func _appeal_of(notice_id: int) -> Dictionary:
	for ap: Dictionary in _table("appeals", []):
		if int(ap.notice_id) == notice_id:
			return ap
	return {}

func _fn_notice_read(a: Dictionary) -> Dictionary:
	for n: Dictionary in _table("notices", []):
		if int(n.id) == int(a.get("p_id", 0)) and n.user_id == me():
			n.read = true
	return {"ok": true}

## Like public.appeal (item 2897): once per decision, within 6 months.
func _fn_appeal(a: Dictionary) -> Dictionary:
	var n: Dictionary = {}
	for row: Dictionary in _table("notices", []):
		if int(row.id) == int(a.get("p_notice", 0)) and row.user_id == me():
			n = row
	if n.is_empty() or n.kind != "decision":
		return _fail("no_such_notice")
	if int(n.at) < now() - 183 * 86400:
		return _fail("too_late")
	if not _appeal_of(int(n.id)).is_empty():
		return _fail("appealed")
	var id: int = _next_id("appeal")
	(_table("appeals", []) as Array).append({"id": id, "notice_id": n.id, "user_id": me(),
		"reason": clampi(int(a.get("p_reason", 2)), 0, 2), "status": "open", "at": now()})
	return {"ok": true, "appeal_id": id}

## Like public.appeal_answer: Ali keeps or lifts the measure.
func appeal_answer(appeal_id: int, changed: bool) -> Dictionary:
	var ap: Dictionary = {}
	for row: Dictionary in _table("appeals", []):
		if int(row.id) == appeal_id:
			ap = row
	if ap.is_empty():
		return _fail("no_such_appeal")
	ap.status = "changed" if changed else "kept"
	var n: Dictionary = {}
	for row: Dictionary in _table("notices", []):
		if int(row.id) == int(ap.notice_id):
			n = row
	if changed and str(n.body.get("action", "")) == "league_block" and db.users.has(ap.user_id):
		db.users[ap.user_id].cheat_cleared_at = now()
	_notice(ap.user_id, "appeal_answer", int(n.get("report_id", 0)), {"changed": changed})
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
	if phrase < 0 or phrase > 31 or (kind == "phrase" and not phrase_ok("post", phrase)):
		return _fail("bad_phrase")
	if not _rate_ok("mail", 30):
		return _fail("slow_down")
	_new_mail(t, kind, phrase)
	return {"ok": true}

## Like public._phrase_ok: phrase number [param n] may be used in [param context] (item 2877).
func phrase_ok(context: String, n: int) -> bool:
	var lists: Variant = db.config.get("phrases_allowed", Phrases.CONTEXTS)
	return lists is Dictionary and ((lists as Dictionary).get(context, []) as Array).has(n)

func _fn_gift_send(a: Dictionary) -> Dictionary:
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if not _can_reach(t):
		return _fail("not_friends")
	if _sent_today(t, "gift"):
		return _fail("already_today")
	var gift: Dictionary = _new_mail(t, "gift")
	var card: Variant = profile_of(me()).get("card", {})
	gift["motif"] = str(card.get("motif", "")) if card is Dictionary else ""
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
			"at": m.at, "code": p.code, "name": p.name, "motif": str(m.get("motif", ""))})
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
	# Like the SQL community_add: the step also counts for running festivals.
	if has_meta("online_events"):
		(get_meta("online_events") as LocalOnlineEvents).on_contribute(me(), str(a.get("p_kind", "")), amount)
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
	db.rift_runs = (_table("rift_runs", []) as Array).filter(func(r: Dictionary) -> bool: return r.u != uid)

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
	var rift_rounds: int = 0
	if kind == "rift":
		if not flag_on("rift_board", 2147483647):
			return _fail("feature_off")
		var ref: String = str(a.get("p_ref", ""))
		var re := RegEx.create_from_string("^[a-z_]{1,24}$")
		if re.search(ref) == null or not known_rifts().has(ref):
			return _fail("no_such_rift")
		var rounds: Variant = (claim as Dictionary).get("rounds")
		if str((claim as Dictionary).get("winner", "")) != "player" or not (rounds is int or rounds is float) \
				or float(rounds) < 1 or float(rounds) > 400:
			return _fail("bad_battle")
		rift_rounds = int(rounds)
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
	var ra: Dictionary = {}
	if kind == "raid":
		var av: Variant = (_table("raid_attempts", {}) as Dictionary).get(str(a.get("p_ref", "")))
		if not av is Dictionary or av.user != me():
			return _fail("no_such_attempt")
		ra = av
		if ra.state != "open" or now() - int(ra.created_at) > 1800:
			return _fail("attempt_closed")
		c["expect"] = _raid_expect(ra)
	var battles: Dictionary = _table("battles", {})
	var id: int = int(db.get("battle_seq", 0)) + 1
	db["battle_seq"] = id
	var row: Dictionary = {"user": me(), "kind": kind, "ref": str(a.get("p_ref", "")).left(40), "status": "pending"}
	battles[str(id)] = row
	if not lm.is_empty():
		lm.state = "submitted"
		lm.battle_id = id
		lm.rated = bool(lm.rated) and league_state(league_season()) == "running"
	if not ra.is_empty():
		ra.state = "submitted"
		ra.battle_id = id
	if kind == "rift":
		(_table("rift_runs", []) as Array).append({"battle_id": id, "u": me(), "week": _week(), "rift": str(a.get("p_ref", "")),
			"v": rift_rounds, "at": now()})
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
	elif row.kind == "raid":
		_raid_apply(id, row.status == "ok", result.detail)

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
		"games": int(e.games) if e != null else 0, "wins": int(e.wins) if e != null else 0,
		"rank": LeagueRules.rank(ranks_cfg(), float(e.rating), int(e.games)) if e != null else -1,
		"placement_left": maxi(0, int(ranks_cfg().get("placement_games", 5)) - int(e.games)) if e != null else int(ranks_cfg().get("placement_games", 5)),
		"shield": int(e.get("shield", 0)) if e != null else 0,
		"reward_ready": _league_reward_due(league) >= 0, "titles": (_user().get("league_awards", []) as Array).duplicate(true)}

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
	var quits: int = 0
	var last: int = 0
	var grace: int = int(ranks_cfg().get("quit_grace", 30))
	for m: Dictionary in (_table("league_matches", {}) as Dictionary).values():
		if m.user == me() and m.state == "expired" and now() - int(m.created_at) < 86400 \
				and int(m.get("expired_at", 0)) - int(m.created_at) >= grace:
			quits += 1
			last = maxi(last, int(m.expired_at))
	var wait: int = LeagueRules.quit_wait(ranks_cfg(), quits, now() - last)
	if wait > 0:
		var f: Dictionary = _fail("quit_wait")
		f["wait"] = wait
		return f
	var waited: int = maxi(0, int(a.get("p_waited", 0)))
	var span: float = minf(config_int("league_search_start", 100) + config_int("league_search_step", 50) * floorf(waited / 10.0),
		config_int("league_search_max", 400))
	var best: String = ""
	var best_d: float = INF
	var t: Dictionary = _table("league_" + league, {})
	var echo_after: int = int(ranks_cfg().get("echo_after", 45))
	for key: String in t:
		var parts: PackedStringArray = key.split("|")
		if int(parts[0]) != int(sn.id) or parts[1] == me() or is_blocked(me(), parts[1]):
			continue
		var d: float = absf(float(t[key].rating) - float(mine.rating))
		if (d <= span or waited >= echo_after) and d < best_d:
			best = parts[1]
			best_d = d
	if best.is_empty() and waited < echo_after:
		return {"ok": true, "found": false, "range": span}
	var matches: Dictionary = _table("league_matches", {})
	for key: String in matches:
		if matches[key].user == me() and matches[key].state == "open":
			matches[key].state = "expired"
			matches[key].expired_at = now()
	# Nobody at all after echo_after seconds: the player's own team as an echo, not rated (point 18).
	var opp: Dictionary = t["%d|%s" % [int(sn.id), best]] if not best.is_empty() else {"team": mine.team, "rating": mine.rating}
	var id: int = int(db.get("league_match_seq", 0)) + 1
	db["league_match_seq"] = id
	var teams: Array = [(mine.team as Array).duplicate(true), (opp.team as Array).duplicate(true)]
	var rated: bool = league_state(sn) == "running" and not best.is_empty()
	matches[str(id)] = {"league": league, "season": int(sn.id), "user": me(), "opponent": best, "seed": rng.randi() & 0x7fffffff,
		"teams": teams, "created_at": now(), "state": "open", "rated": rated}
	return {"ok": true, "found": true, "match_id": id, "seed": matches[str(id)].seed, "teams": teams.duplicate(true),
		"ai": config_int("league_ai", 2), "opponent_tier": LeagueRules.tier(float(opp.rating)), "range": span, "rated": rated,
		"echo": best_d > span or best.is_empty()}

func _league_expect(m: Dictionary) -> Dictionary:
	return {"seed": m.seed, "teams": (m.teams as Array).duplicate(true), "ai": config_int("league_ai", 2), "wild": false,
		"front": [1, 1], "items_allowed": false, "seals": seals_of(str(m.user)) if str(m.league) == LeagueRules.OPEN else [0, 0, 0],
		"amulets": amulets_of(str(m.user)) if str(m.league) == LeagueRules.OPEN else [0, 0, 0]}

## Seal tiers [power, guard, speed] of [param uid] from the shop unlocks (like public._shop_seals).
func seals_of(uid: String) -> Array:
	var out: Array = []
	var unlocks: Dictionary = LocalShop.of(self)._shop(uid).unlocks if LocalShop.of(self) != null else {}
	for k: String in ShopEffects.SEAL_KINDS:
		out.append(ShopEffects.clamp_tier(k, int(unlocks.get(k, 0))))
	return out

## Amulet tiers [crit, ward, shield] of [param uid] (like public._shop_amulets).
func amulets_of(uid: String) -> Array:
	var out: Array = []
	var unlocks: Dictionary = LocalShop.of(self)._shop(uid).unlocks if LocalShop.of(self) != null else {}
	for k: String in ShopEffects.AMULET_KINDS:
		out.append(ShopEffects.clamp_tier(k, int(unlocks.get(k, 0))))
	return out

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
	var sh: Dictionary = LeagueRules.after_battle(ranks_cfg(), float(e.rating), float(nr.rating), int(e.games) + 1, int(e.get("shield", 0)))
	e.rating = sh.rating
	e.shield = sh.shield
	e.rd = nr.rd
	e.vol = nr.vol
	e.games = int(e.games) + 1
	e.wins = int(e.wins) + int(score)

## server_config.league_ranks (data/league_ranks.json).
func ranks_cfg() -> Dictionary:
	var v: Variant = db.config.get("league_ranks")
	if not v is Dictionary:
		v = LeagueRules.ranks_config()
		db.config["league_ranks"] = v
	return v

## Like public._league_reward_due: the final rank of the last finished season, or -1 when there is
## none or it was claimed.
func _league_reward_due(league: String) -> int:
	var sn: Dictionary = league_season()
	var prev: int = int(sn.id) - 1
	if prev < 1:
		return -1
	for aw: Dictionary in _user().get("league_awards", []):
		if int(aw.season) == prev and aw.league == league:
			return -1
	var e: Variant = league_entry(league, prev, me())
	return LeagueRules.rank(ranks_cfg(), float(e.rating), int(e.games)) if e != null else -1

## Season reward and title (points 13, 19): items into the bag, the title and frame kept online.
func _fn_league_reward(a: Dictionary) -> Dictionary:
	var league: String = str(a.get("p_league", ""))
	var err: String = _league_check(league)
	if not err.is_empty():
		return _fail(err)
	var r: int = _league_reward_due(league)
	if r < 0:
		return _fail("no_reward")
	var rw: Dictionary = LeagueRules.reward(ranks_cfg(), r)
	var res: Dictionary = _trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {str(rw.item): int(rw.count)})
	if not bool(res.ok):
		return res
	var season: int = int(league_season().id) - 1
	var title: String = LeagueRules.rank_id(ranks_cfg(), r)
	(_user().get_or_add("league_awards", []) as Array).append({"season": season, "league": league, "rank": r, "title": title})
	return {"ok": true, "rev": res.rev, "item": rw.item, "count": rw.count, "rank": r, "title": title,
		"frame": "season_%d_%s" % [season, title], "bag": {str(rw.item): int(rw.count)}}

# --- Bunds (plan area 7, items 2817-2821, 2842, 2900), like 20261110000010_bunds.sql ---

func _members() -> Dictionary:
	return _table("bund_members", {})

func _bund_of(uid: String) -> String:
	var m: Variant = _members().get(uid)
	return str(m.bund) if m is Dictionary else ""

func _bund_role(uid: String) -> String:
	var m: Variant = _members().get(uid)
	return str(m.role) if m is Dictionary else ""

func _bund_list(b: String) -> Array:
	var out: Array = []
	for uid: String in _members():
		if str(_members()[uid].bund) == b:
			out.append(uid)
	out.sort_custom(func(x: String, y: String) -> bool: return int(_members()[x].joined) < int(_members()[y].joined))
	return out

func _bund_fix(b: String) -> void:
	var ids: Array = _bund_list(b)
	if ids.is_empty():
		(_table("bunds", {}) as Dictionary).erase(b)
		db.bund_invites = (_table("bund_invites", []) as Array).filter(func(i: Dictionary) -> bool: return str(i.bund) != b)
		return
	if not ids.any(func(x: String) -> bool: return _bund_role(x) == "leader"):
		var next: String = ids[0]
		for x: String in ids:
			if _bund_role(x) == "helper":
				next = x
				break
		_members()[next].role = "leader"
	if ids.size() < 3:
		db.bunds[b].dissolve_at = 0

func _bund_check(uid: String) -> String:
	if not flag_on("bund", 2147483647):
		return "feature_off"
	if not _social(uid):
		return "social_off"
	return ""

func _invite_of(b: String, uid: String, kind: String) -> int:
	var list: Array = _table("bund_invites", [])
	for i: int in list.size():
		if str(list[i].bund) == b and list[i].user == uid and (kind.is_empty() or list[i].kind == kind):
			return i
	return -1

func _bund_join(b: String, uid: String, role: String) -> String:
	if not _bund_of(uid).is_empty():
		return "in_bund"
	if _bund_list(b).size() >= config_int("bund_max", 30):
		return "full"
	_members()[uid] = {"bund": b, "role": role, "joined": now() * 1000 + _members().size()}
	db.bund_invites = (_table("bund_invites", []) as Array).filter(func(i: Dictionary) -> bool: return i.user != uid)
	return ""

func _fn_bund_create(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var n: int = config_int("bund_words", 120)
	var x: int = int(a.get("p_a", -1))
	var y: int = int(a.get("p_b", -1))
	if x < 0 or x >= n or y < 0 or y >= n:
		return _fail("bad_name")
	if not _bund_of(u).is_empty():
		return _fail("in_bund")
	if not _rate_ok("bund_create", 3):
		return _fail("slow_down")
	var b: String = str(_next_id("bund"))
	(_table("bunds", {}) as Dictionary)[b] = {"name": [x, y], "dissolve_at": 0, "created": now()}
	_bund_join(b, u, "leader")
	return {"ok": true, "bund": int(b)}

func _fn_bund_info(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var bund: Variant = null
	var b: String = _bund_of(u)
	if not b.is_empty():
		_bund_fix(b)
		var r: String = _bund_role(u)
		var members: Array = []
		for role: String in ["leader", "helper", "member"]:
			for x: String in _bund_list(b):
				if _bund_role(x) == role:
					var p: Dictionary = profile_of(x)
					members.append({"name": p.name, "code": p.code, "role": role, "me": x == u,
						"online": int(p.get("last_seen", 0)) > now() - 300})
		var pending: Array = []
		if r in ["leader", "helper"]:
			for i: Dictionary in _table("bund_invites", []):
				if str(i.bund) == b:
					pending.append({"kind": i.kind, "name": profile_of(i.user).name, "code": profile_of(i.user).code})
		var row: Dictionary = db.bunds[b]
		bund = {"id": int(b), "name": row.name, "role": r, "dissolve_at": row.dissolve_at if int(row.dissolve_at) > 0 else null,
			"members": members, "pending": pending}
	var invites: Array = []
	for i: Dictionary in _table("bund_invites", []):
		if i.user == u and i.kind == "invite" and db.bunds.has(str(i.bund)):
			invites.append({"bund": int(i.bund), "name": db.bunds[str(i.bund)].name, "by": profile_of(i.by).name,
				"size": _bund_list(str(i.bund)).size()})
	return {"ok": true, "bund": bund, "invites": invites}

func _fn_bund_invite(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty() or not _bund_role(u) in ["leader", "helper"]:
		return _fail("not_allowed")
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if t.is_empty() or t == u or is_blocked(u, t) or not _social(t):
		return _fail("no_such_code")
	if not _bund_of(t).is_empty():
		return _fail("in_bund")
	if not _rate_ok("bund_invite", 30):
		return _fail("slow_down")
	if _invite_of(b, t, "request") >= 0:
		e = _bund_join(b, t, "member")
		return _fail(e) if not e.is_empty() else {"ok": true, "joined": true}
	if _invite_of(b, t, "") < 0:
		(_table("bund_invites", []) as Array).append({"bund": b, "user": t, "kind": "invite", "by": u, "at": now()})
	return {"ok": true, "joined": false}

func _fn_bund_request(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var t: String = uid_for_code(str(a.get("p_code", "")))
	var b: String = _bund_of(t) if not t.is_empty() else ""
	if t.is_empty() or t == u or is_blocked(u, t) or not _social(t) or b.is_empty():
		return _fail("no_such_bund")
	if not _bund_of(u).is_empty():
		return _fail("in_bund")
	if _bund_list(b).any(func(x: String) -> bool: return is_blocked(u, x)):
		return _fail("no_such_bund")
	if not _rate_ok("bund_request", 10):
		return _fail("slow_down")
	if _invite_of(b, u, "invite") >= 0:
		e = _bund_join(b, u, "member")
		return _fail(e) if not e.is_empty() else {"ok": true, "joined": true}
	if _invite_of(b, u, "") < 0:
		(_table("bund_invites", []) as Array).append({"bund": b, "user": u, "kind": "request", "by": u, "at": now()})
	return {"ok": true, "joined": false}

func _fn_bund_answer(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = str(int(a.get("p_bund", 0)))
	var i: int = _invite_of(b, u, "invite")
	if i < 0:
		return _fail("no_such_invite")
	if not bool(a.get("p_accept", false)):
		(db.bund_invites as Array).remove_at(i)
		return {"ok": true, "joined": false}
	e = _bund_join(b, u, "member")
	return _fail(e) if not e.is_empty() else {"ok": true, "joined": true}

func _fn_bund_admit(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty() or not _bund_role(u) in ["leader", "helper"]:
		return _fail("not_allowed")
	var t: String = uid_for_code(str(a.get("p_code", "")))
	var i: int = _invite_of(b, t, "request") if not t.is_empty() else -1
	if i < 0:
		return _fail("no_such_request")
	if not bool(a.get("p_accept", false)):
		(db.bund_invites as Array).remove_at(i)
		return {"ok": true, "joined": false}
	e = _bund_join(b, t, "member")
	return _fail(e) if not e.is_empty() else {"ok": true, "joined": true}

func _fn_bund_kick(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if b.is_empty() or t.is_empty() or t == u or _bund_of(t) != b:
		return _fail("no_such_member")
	var mine: String = _bund_role(u)
	if not (mine == "leader" or (mine == "helper" and _bund_role(t) == "member")):
		return _fail("not_allowed")
	_members().erase(t)
	_bund_fix(b)
	return {"ok": true}

func _fn_bund_role(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var role: String = str(a.get("p_role", ""))
	if not role in ["leader", "helper", "member"]:
		return _fail("bad_role")
	var b: String = _bund_of(u)
	var t: String = uid_for_code(str(a.get("p_code", "")))
	if b.is_empty() or t.is_empty() or t == u or _bund_of(t) != b:
		return _fail("no_such_member")
	if _bund_role(u) != "leader":
		return _fail("not_allowed")
	if role == "leader":
		_members()[u].role = "helper"
	_members()[t].role = role
	return {"ok": true}

func _fn_bund_leave(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var b: String = _bund_of(u)
	if b.is_empty():
		return _fail("no_bund")
	_members().erase(u)
	_bund_fix(b)
	return {"ok": true}

func _fn_bund_dissolve(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty() or _bund_role(u) != "leader":
		return _fail("not_allowed")
	var row: Dictionary = db.bunds[b]
	if _bund_list(b).size() >= 3:
		if int(row.dissolve_at) <= 0:
			row.dissolve_at = now() + 86400
			return {"ok": true, "dissolved": false, "confirm_from": row.dissolve_at}
		if int(row.dissolve_at) > now():
			return {"ok": true, "dissolved": false, "confirm_from": row.dissolve_at}
	for x: String in _bund_list(b):
		_members().erase(x)
	_bund_fix(b)
	return {"ok": true, "dissolved": true}

func _fn_bund_keep(_a: Dictionary) -> Dictionary:
	var u: String = me()
	if _bund_role(u) != "leader":
		return _fail("not_allowed")
	db.bunds[_bund_of(u)].dissolve_at = 0
	return {"ok": true}

# --- Raid Rifts (plan area 7, items 2847-2851, 2871), like 20261110000011_raids.sql ---

func _raid_check(uid: String) -> String:
	if not flag_on("raid", 2147483647):
		return "feature_off"
	if not _social(uid):
		return "social_off"
	if cheat_held(uid):
		return "under_review"
	return ""

## 2 players 100 %, 3 players 140 %, 4 players 175 % of raid_base (item 2850).
func raid_hp(players: int) -> int:
	var pct: int = 100 if players == 2 else (140 if players == 3 else 175)
	return config_int("raid_base", 1200) * pct / 100

func _raid_expect(at: Dictionary) -> Dictionary:
	return {"seed": at.seed, "teams": (at.teams as Array).duplicate(true), "ai": config_int("league_ai", 2), "wild": false,
		"front": [1, 1], "items_allowed": false, "round_limit": config_int("raid_rounds", 10), "seals": seals_of(str(at.user)),
		"amulets": amulets_of(str(at.user))}

## Members of raid [param r] as uid -> row. Rows live under "raid|uid", so deleting an account
## removes only that player's row (like the SQL table).
func _raid_members(r: String) -> Dictionary:
	var out: Dictionary = {}
	var t: Dictionary = _table("raid_members", {})
	for key: String in t:
		if key.begins_with(r + "|"):
			out[key.substr(r.length() + 1)] = t[key]
	return out

func _day_start() -> int:
	return now() - now() % 86400

func _raid_tries_used(r: String, uid: String) -> int:
	var n: int = 0
	for at: Dictionary in (_table("raid_attempts", {}) as Dictionary).values():
		if str(at.raid) == r and at.user == uid and int(at.created_at) >= _day_start():
			n += 1
	return n

func _fn_raid_open(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _raid_check(u)
	if not e.is_empty():
		return _fail(e)
	var codes: Variant = a.get("p_codes")
	if not codes is Array or (codes as Array).size() < 1 or (codes as Array).size() > 3:
		return _fail("bad_party")
	var who: Array = [u]
	for c: Variant in codes:
		var t: String = uid_for_code(str(c))
		var same_bund: bool = not _bund_of(u).is_empty() and _bund_of(u) == _bund_of(t)
		var f: Variant = _friendship(u, t) if not t.is_empty() else null
		var friends: bool = f != null and str(f.status) == "accepted"
		if t.is_empty() or who.has(t) or is_blocked(u, t) or not _social(t) or not (friends or same_bund):
			return _fail("no_such_code")
		who.append(t)
	if not _rate_ok("raid_open", 6):
		return _fail("slow_down")
	var rc: Dictionary = raid_cfg()
	var tier: Variant = a.get("p_tier", 1)
	if not RaidRules.tier_ok(rc, tier):
		return _fail("bad_tier")
	var pool: Array = (db.config.get("raid_guardians", []) as Array).filter(func(g: Variant) -> bool: return Database.species(str(g)) != null)
	var legs: Array = (rc.get("legendaries", []) as Array).filter(func(g: Variant) -> bool: return Database.species(str(g)) != null)
	var cfg2: Dictionary = rc.duplicate()
	cfg2["legendaries"] = legs
	var g: Dictionary = RaidRules.guardian(cfg2, pool, RaidRules.week_index(now()), rng.randi() % 100)
	if g.is_empty():
		return _fail("no_guardian")
	var id: String = str(_next_id("raid"))
	var hp: int = RaidRules.hp(rc, raid_hp(who.size()), int(tier), bool(g.legendary))
	(_table("raids", {}) as Dictionary)[id] = {"guardian": g.guardian, "level": int(rc.tiers[int(tier)].level),
		"players": who.size(), "hp_total": hp, "hp_left": hp, "created_at": now(), "tier": int(tier), "legendary": g.legendary,
		"closes_at": now() + 3600 * config_int("raid_hours", 48), "won_at": 0, "reward": null}
	for x: String in who:
		(_table("raid_members", {}) as Dictionary)["%s|%s" % [id, x]] = {"damage": 0, "claimed": false}
	return {"ok": true, "raid": int(id), "guardian": g.guardian, "tier": int(tier), "legendary": g.legendary, "hp": hp}

## server_config.raid_rules (data/raid_rules.json).
func raid_cfg() -> Dictionary:
	var v: Variant = db.config.get("raid_rules")
	if not v is Dictionary:
		v = RaidRules.config()
		db.config["raid_rules"] = v
	return v

## Like public.raid_board: the fastest won Rifts (point 29), without names.
func _fn_raid_board(_a: Dictionary) -> Dictionary:
	var e: String = _raid_check(me())
	if not e.is_empty():
		return _fail(e)
	var rows: Array = []
	for r: Dictionary in (_table("raids", {}) as Dictionary).values():
		if int(r.won_at) > 0:
			rows.append({"guardian": r.guardian, "tier": int(r.get("tier", 1)), "players": int(r.players),
				"seconds": int(r.won_at) - int(r.created_at)})
	rows.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.seconds) < int(q.seconds))
	return {"ok": true, "rows": rows.slice(0, int(raid_cfg().get("board_rows", 10)))}

func _raid_qualifies(r: Dictionary, damage: int) -> bool:
	return int(r.won_at) > 0 and damage * 100 >= int(r.hp_total) * config_int("raid_share_min", 5)

func _fn_raid_list(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _raid_check(u)
	if not e.is_empty():
		return _fail(e)
	var tries: int = config_int("raid_tries", 3)
	var out: Array = []
	var raids: Dictionary = _table("raids", {})
	for id: String in raids:
		var r: Dictionary = raids[id]
		var mem: Dictionary = _raid_members(id)
		if not mem.has(u) or int(r.created_at) < now() - 7 * 86400:
			continue
		var members: Array = []
		for x: String in mem:
			members.append({"name": profile_of(x).name if db.users.has(x) else "?", "damage": mem[x].damage, "me": x == u})
		members.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.damage) > int(q.damage))
		out.push_front({"id": int(id), "guardian": r.guardian, "level": r.level, "players": r.players, "hp_total": r.hp_total,
			"hp_left": r.hp_left, "closes_at": r.closes_at, "open": int(r.hp_left) > 0 and int(r.closes_at) > now(),
			"won": int(r.won_at) > 0, "tries_left": maxi(0, tries - _raid_tries_used(id, u)),
			"reward": r.reward if _raid_qualifies(r, int(mem[u].damage)) else null, "claimed": mem[u].claimed, "members": members})
	return {"ok": true, "rewards": (db.config.get("raid_rewards", []) as Array).duplicate(true), "tries": tries,
		"share_min": config_int("raid_share_min", 5), "rounds": config_int("raid_rounds", 10), "raids": out}

func _fn_raid_start(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _raid_check(u)
	if not e.is_empty():
		return _fail(e)
	var id: String = str(int(a.get("p_raid", 0)))
	var r: Variant = (_table("raids", {}) as Dictionary).get(id)
	if not r is Dictionary or not _raid_members(id).has(u):
		return _fail("no_such_raid")
	if int(r.hp_left) <= 0 or int(r.closes_at) <= now():
		return _fail("raid_closed")
	if _raid_tries_used(id, u) >= config_int("raid_tries", 3):
		return _fail("no_tries")
	var built: Dictionary = LeagueRules.build_team(profile_of(u).get("team", []), LeagueRules.FAIR, a.get("p_pick"),
		config_int("league_fair_ring", 50), config_int("level_max", 60))
	if built.has("error"):
		return _fail(str(built.error))
	var attempts: Dictionary = _table("raid_attempts", {})
	for at: Dictionary in attempts.values():
		if at.user == u and at.state == "open":
			at.state = "expired"
	var moves: Array = []
	for md: MoveData in Database.species(str(r.guardian)).default_moves(int(r.level), 4):
		moves.append(md.move_name)
	var aid: String = str(_next_id("raid_attempt"))
	attempts[aid] = {"raid": id, "user": u, "seed": rng.randi() & 0x7fffffff, "state": "open", "damage": 0, "created_at": now(),
		"teams": [built.team, [{"species": r.guardian, "level": r.level, "moves": moves}]]}
	var out: Dictionary = _raid_expect(attempts[aid])
	out.merge({"ok": true, "attempt_id": int(aid)})
	return out

func _fn_raid_claim(a: Dictionary) -> Dictionary:
	var u: String = me()
	var id: String = str(int(a.get("p_raid", 0)))
	var r: Variant = (_table("raids", {}) as Dictionary).get(id)
	var mem: Dictionary = _raid_members(id)
	if not r is Dictionary or not mem.has(u):
		return _fail("no_such_raid")
	if not _raid_qualifies(r, int(mem[u].damage)):
		return _fail("no_reward")
	if bool(mem[u].claimed):
		return _fail("claimed")
	mem[u].claimed = true
	var best: int = 0
	for x: String in mem:
		best = maxi(best, int(mem[x].damage))
	var top: bool = int(mem[u].damage) == best
	return {"ok": true, "item": r.reward.item, "count": RaidRules.reward_count(raid_cfg(), int(r.reward.get("count", 1)), top), "top": top}

## Like public._raid_apply: checked damage comes off the guardian, never below zero.
func _raid_apply(battle_id: int, ok: bool, detail: Variant) -> void:
	for at: Dictionary in (_table("raid_attempts", {}) as Dictionary).values():
		if int(at.get("battle_id", -1)) != battle_id or at.state != "submitted":
			continue
		at.state = "done"
		var r: Dictionary = db.raids[str(at.raid)]
		var dealt: int = int(detail.get("foe_damage", 0)) if ok and detail is Dictionary else 0
		var d: int = clampi(dealt, 0, int(r.hp_left))
		at.damage = d
		if d == 0:
			return
		var mem: Dictionary = _raid_members(str(at.raid))
		if mem.has(at.user):
			mem[at.user].damage = int(mem[at.user].damage) + d
		r.hp_left = int(r.hp_left) - d
		if int(r.hp_left) == 0:
			r.won_at = now()
			var tbl: Array = db.config.get("raid_rewards", [])
			var total: int = 0
			for x: Dictionary in tbl:
				total += int(x.w)
			if total > 0:
				var roll: int = rng.randi() % total
				for x: Dictionary in tbl:
					roll -= int(x.w)
					if roll < 0:
						r.reward = {"item": x.item, "count": int(x.get("count", 1))}
						break
		return

# --- Trading (plan area 7, items 2791-2795, 2900), like 20261110000012_trades.sql ---------------
# db.trades: {id: {state, created_at, closes_at}}; db.trade_sides: {"id|uid": {items, confirmed,
# receive, collected}}. The server is the trustee: offers leave the stored save's bag at once.

## Items with "tradeable": true in data/items.json (the server keeps the same list in trade_items).
func trade_items() -> Array:
	var given: Variant = db.config.get("trade_items")
	if given is Array:
		return given
	Database.load_all()
	var out: Array = []
	for id: String in Database.items:
		if bool((Database.items[id] as Dictionary).get("tradeable", false)):
			out.append(id)
	return out

func _trade_check(uid: String) -> String:
	if not flag_on("trade", 2147483647):
		return "feature_off"
	if not _social(uid):
		return "social_off"
	if cheat_held(uid):
		return "under_review"
	return ""

func _trade_pair(x: String, y: String) -> String:
	if x.is_empty() or y.is_empty() or x == y or not db.users.has(y) or is_blocked(x, y) or not _social(y):
		return "no_such_code"
	var f: Variant = _friendship(x, y)
	if f == null or str(f.status) != "accepted":
		return "no_such_code"
	if level_for(int(f.points)) < config_int("trade_min_level", 3):
		return "friend_level"
	if int(f.get("accepted_at", 0)) > now() - config_int("trade_min_days", 7) * 86400:
		return "too_new"
	return ""

## A clean offer {item: count}, or null when it breaks a rule.
func _trade_offer(p: Variant) -> Variant:
	if not p is Dictionary or (p as Dictionary).size() > config_int("trade_max_kinds", 6):
		return null
	var ok: Array = trade_items()
	var out: Dictionary = {}
	for k: Variant in p:
		var v: Variant = p[k]
		if not (v is int or v is float) or not ok.has(str(k)) or float(v) != floorf(float(v)):
			return null
		var n: int = int(v)
		if n < 0 or n > config_int("trade_max_count", 99):
			return null
		if n > 0:
			out[str(k)] = n
	return out

func _trade_bag(slot: int, rev: int, delta: Dictionary) -> Dictionary:
	var r: Dictionary = _trade_save(slot, rev, delta, [], [])
	r.erase("took")
	return r

## Like public._trade_save: changes the bag by [param delta], takes the Spirlings with the uids
## [param take] out of team or storage and adds [param give] to storage. Nothing changes on a failure.
func _trade_save(slot: int, rev: int, delta: Dictionary, take: Array, give: Array) -> Dictionary:
	var sv: Variant = _saves().get(str(slot))
	if sv == null:
		return _fail("no_save")
	if int(sv.rev) != rev:
		return _fail("sync_first")
	var inv: Dictionary = (sv.data.get("inventory", {}) as Dictionary).duplicate() if sv.data.get("inventory") is Dictionary else {}
	for k: String in delta:
		var n: int = int(inv.get(k, 0)) + int(delta[k])
		if n < 0:
			return _fail("not_enough")
		if n == 0:
			inv.erase(k)
		else:
			inv[k] = n
	var party: Array = (sv.data.get("party") as Array).duplicate(true) if sv.data.get("party") is Array else []
	var store: Array = (sv.data.get("storage") as Array).duplicate(true) if sv.data.get("storage") is Array else []
	var took: Array = []
	for id: Variant in take:
		var i: int = _mon_index(party, str(id))
		if i >= 0:
			took.append(party.pop_at(i))
			continue
		i = _mon_index(store, str(id))
		if i < 0:
			return _fail("no_spirling")
		took.append(store.pop_at(i))
	if party.is_empty() and not take.is_empty():
		return _fail("last_one")
	store.append_array(give.duplicate(true))
	keep_history(slot, sv, {"changed": true})
	sv.data["inventory"] = inv
	if not take.is_empty() or not give.is_empty():
		sv.data["party"] = party
		sv.data["storage"] = store
	sv.rev = int(sv.rev) + 1
	sv.saved_at = now()
	sv.erase("request_id")
	return {"ok": true, "rev": sv.rev, "took": took}

static func _mon_index(list: Array, uid: String) -> int:
	for i: int in list.size():
		if list[i] is Dictionary and str(list[i].get("uid", "")) == uid:
			return i
	return -1

## Like public._trade_mon_why: why Spirling [param m] cannot be traded, or "".
static func trade_mon_why(m: Variant) -> String:
	if not m is Dictionary or str(m.get("uid", "")).is_empty() or str(m.get("species", "")).is_empty():
		return "no_spirling"
	if not str(m.get("held", "")).is_empty():
		return "holds_item"
	if gleam_boosted(m) or bool(m.get("core", false)) or (m.get("crystal") is Dictionary and not (m.crystal as Dictionary).is_empty()):
		return "shop_boosted"
	if bool(m.get("favorite", false)):
		return "favorite"
	return ""

## Like public._gleam_boosted: the shop's +10 % Gleam. A wild Gleam (gleam_boost false) trades;
## saves from before wild Gleams have only "gleam", which then always came from the shop.
static func gleam_boosted(m: Dictionary) -> bool:
	return bool(m.get("gleam_boost", false)) if m.has("gleam_boost") else bool(m.get("gleam", false))

## Like public._trade_mon_clean: the origin era stays (1 for older saves), no nickname, box or mark.
static func trade_mon_clean(m: Dictionary) -> Dictionary:
	var out: Dictionary = m.duplicate(true)
	for k: String in ["nickname", "box", "favorite"]:
		out.erase(k)
	var era: Variant = m.get("origin_era")
	out["origin_era"] = int(era) if (era is int or era is float) and int(era) >= 1 and int(era) <= Spirling.MAX_ERA else 1
	return out

static func mon_uids(list: Variant) -> Array:
	var out: Array = []
	for m: Variant in (list if list is Array else []):
		if m is Dictionary:
			out.append(str(m.get("uid", "")))
	out.sort()
	return out

func _trade_side(id: String, uid: String) -> Variant:
	return (_table("trade_sides", {}) as Dictionary).get("%s|%s" % [id, uid])

## The other side's account id, or "" once that account is gone.
func _trade_other(id: String, uid: String) -> String:
	for k: String in _table("trade_sides", {}):
		var parts: PackedStringArray = k.split("|")
		if parts[0] == id and parts[1] != uid:
			return parts[1]
	return ""

func _trade_tidy() -> void:
	var trades: Dictionary = _table("trades", {})
	var sides: Dictionary = _table("trade_sides", {})
	for id: String in trades.keys():
		var t: Dictionary = trades[id]
		if t.state == "open" and int(t.closes_at) < now():
			t.state = "cancelled"
			for k: String in sides:
				if k.begins_with(id + "|"):
					sides[k].receive = sides[k].items
					sides[k].receive_mons = sides[k].get("mons", [])
		if t.state != "open":
			var waiting: bool = sides.keys().any(func(k: String) -> bool: return k.begins_with(id + "|") and not bool(sides[k].collected))
			if not waiting or now() - int(t.created_at) > 90 * 86400:
				trades.erase(id)
				for k: String in sides.keys():
					if k.begins_with(id + "|"):
						sides.erase(k)

func _fn_trade_open(a: Dictionary) -> Dictionary:
	var u: String = me()
	var t: String = uid_for_code(str(a.get("p_code", "")))
	var e: String = _trade_check(u)
	if e.is_empty():
		e = _trade_pair(u, t)
	if not e.is_empty():
		return _fail(e)
	_trade_tidy()
	var trades: Dictionary = _table("trades", {})
	var open: int = 0
	for id: String in trades:
		if trades[id].state != "open" or _trade_side(id, u) == null:
			continue
		if _trade_side(id, t) != null:
			return {"ok": true, "trade": int(id), "again": true}
		open += 1
	if open >= config_int("trade_max_open", 5):
		return _fail("too_many")
	if not _rate_ok("trade_open", 10):
		return _fail("slow_down")
	var id: String = str(_next_id("trade"))
	trades[id] = {"state": "open", "created_at": now(), "closes_at": now() + config_int("trade_days", 7) * 86400}
	for x: String in [u, t]:
		(_table("trade_sides", {}) as Dictionary)["%s|%s" % [id, x]] = {"items": {}, "mons": [], "confirmed": false, "receive": null,
			"receive_mons": null, "collected": false}
	return {"ok": true, "trade": int(id)}

func _fn_trade_list(_a: Dictionary) -> Dictionary:
	var u: String = me()
	_trade_tidy()
	var trades: Dictionary = _table("trades", {})
	var ids: Array = trades.keys().filter(func(id: String) -> bool: return _trade_side(id, u) != null)
	ids.sort_custom(func(x: String, y: String) -> bool: return int(x) > int(y))
	var out: Array = []
	for id: String in ids:
		var t: Dictionary = trades[id]
		var m: Dictionary = _trade_side(id, u)
		if t.state != "open" and bool(m.collected):
			continue
		var other: String = _trade_other(id, u)
		var o: Variant = _trade_side(id, other) if not other.is_empty() else null
		var shown: bool = not other.is_empty() and db.users.has(other) and not is_blocked(u, other)
		var p: Dictionary = profile_of(other) if shown else {}
		out.append({"id": int(id), "state": t.state, "closes_at": t.closes_at, "code": p.get("code"), "name": p.get("name"),
			"mine": (m.items as Dictionary).duplicate(), "theirs": (o.items as Dictionary).duplicate() if o != null else {},
			"mine_mons": (m.get("mons", []) as Array).duplicate(true), "theirs_mons": (o.get("mons", []) as Array).duplicate(true) if o != null else [],
			"my_ok": m.confirmed, "their_ok": o.confirmed if o != null else false,
			"collect": t.state != "open" and not bool(m.collected)})
	return {"ok": true, "trades": out, "items": trade_items(), "spirlings": flag_on("trade_spirling", 2147483647),
		"max_spirlings": config_int("trade_max_spirlings", 3)}

func _trade_open_side(id: String, u: String) -> Variant:
	var t: Variant = (_table("trades", {}) as Dictionary).get(id)
	if t == null or t.state != "open":
		return null
	return _trade_side(id, u)

func _fn_trade_put(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _trade_check(u)
	if not e.is_empty():
		return _fail(e)
	_trade_tidy()
	var id: String = str(int(a.get("p_trade", 0)))
	var m: Variant = _trade_open_side(id, u)
	if m == null:
		return _fail("no_such_trade")
	if not _trade_pair(u, _trade_other(id, u)).is_empty():
		return _fail("partner_gone")
	var offer: Variant = _trade_offer(a.get("p_items"))
	if offer == null:
		return _fail("not_tradeable")
	if not _rate_ok("trade_put", 60):
		return _fail("slow_down")
	var delta: Dictionary = {}
	var keys: Array = (m.items as Dictionary).keys()
	for k: String in offer:
		if not keys.has(k):
			keys.append(k)
	for k: String in keys:
		var d: int = int(m.items.get(k, 0)) - int(offer.get(k, 0))
		if d != 0:
			delta[k] = d
	var r: Dictionary = _trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), delta)
	if not bool(r.ok):
		return r
	m.items = offer
	for k: String in _table("trade_sides", {}):
		if k.begins_with(id + "|"):
			db.trade_sides[k].confirmed = false
	return {"ok": true, "rev": r.rev, "bag": delta}

func _fn_trade_confirm(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _trade_check(u)
	if not e.is_empty():
		return _fail(e)
	_trade_tidy()
	var id: String = str(int(a.get("p_trade", 0)))
	var m: Variant = _trade_open_side(id, u)
	if m == null:
		return _fail("no_such_trade")
	var other: String = _trade_other(id, u)
	if other.is_empty() or not _trade_pair(u, other).is_empty():
		return _fail("partner_gone")
	var o: Dictionary = _trade_side(id, other)
	var seen: Variant = _trade_offer(a.get("p_theirs"))
	var seen_mons: Array = []
	for x: Variant in (a.get("p_their_mons") if a.get("p_their_mons") is Array else []):
		seen_mons.append(str(x))
	seen_mons.sort()
	if o.items != (seen if seen != null else {}) or mon_uids(o.get("mons", [])) != seen_mons:
		return _fail("changed")
	if (m.items as Dictionary).is_empty() and (o.items as Dictionary).is_empty() \
			and (m.get("mons", []) as Array).is_empty() and (o.get("mons", []) as Array).is_empty():
		return _fail("empty")
	m.confirmed = true
	if bool(o.confirmed):
		m.receive = (o.items as Dictionary).duplicate()
		o.receive = (m.items as Dictionary).duplicate()
		m.receive_mons = (o.get("mons", []) as Array).duplicate(true)
		o.receive_mons = (m.get("mons", []) as Array).duplicate(true)
		db.trades[id].state = "done"
		return {"ok": true, "done": true}
	return {"ok": true, "done": false}

func _fn_trade_cancel(a: Dictionary) -> Dictionary:
	var u: String = me()
	var id: String = str(int(a.get("p_trade", 0)))
	if _trade_open_side(id, u) == null:
		return _fail("no_such_trade")
	for k: String in _table("trade_sides", {}):
		if k.begins_with(id + "|"):
			db.trade_sides[k].receive = (db.trade_sides[k].items as Dictionary).duplicate()
			db.trade_sides[k].receive_mons = (db.trade_sides[k].get("mons", []) as Array).duplicate(true)
	db.trades[id].state = "cancelled"
	return {"ok": true}

func _fn_trade_collect(a: Dictionary) -> Dictionary:
	var u: String = me()
	_trade_tidy()
	var id: String = str(int(a.get("p_trade", 0)))
	var t: Variant = (_table("trades", {}) as Dictionary).get(id)
	var m: Variant = _trade_side(id, u)
	if t == null or t.state == "open" or m == null:
		return _fail("no_such_trade")
	if bool(m.collected):
		return _fail("already")
	var got: Dictionary = (m.receive as Dictionary).duplicate() if m.receive is Dictionary else {}
	var mons: Array = (m.get("receive_mons") as Array).duplicate(true) if m.get("receive_mons") is Array else []
	var r: Dictionary = _trade_save(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), got, [], mons)
	if not bool(r.ok):
		return r
	m.collected = true
	_trade_tidy()
	return {"ok": true, "rev": r.rev, "bag": got, "mons": mons}

func _fn_trade_put_spirlings(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _trade_check(u)
	if not e.is_empty():
		return _fail(e)
	if not flag_on("trade_spirling", 2147483647):
		return _fail("feature_off")
	_trade_tidy()
	var id: String = str(int(a.get("p_trade", 0)))
	var m: Variant = _trade_open_side(id, u)
	if m == null:
		return _fail("no_such_trade")
	if not _trade_pair(u, _trade_other(id, u)).is_empty():
		return _fail("partner_gone")
	var want: Array = []
	var raw: Array = a.get("p_uids") if a.get("p_uids") is Array else []
	for x: Variant in raw:
		if not str(x).is_empty() and not want.has(str(x)):
			want.append(str(x))
	if want.size() != raw.size() or want.size() > config_int("trade_max_spirlings", 3):
		return _fail("too_many_spirlings")
	if not _rate_ok("trade_put", 60):
		return _fail("slow_down")
	var have: Array = mon_uids(m.get("mons", []))
	var take: Array = want.filter(func(x: String) -> bool: return not have.has(x))
	var keep: Array = []
	var back: Array = []
	for x: Dictionary in m.get("mons", []):
		(keep if want.has(str(x.uid)) else back).append(x)
	var sv: Variant = _saves().get(str(int(a.get("p_slot", 0))))
	if sv == null:
		return _fail("no_save")
	var all: Array = (sv.data.get("party", []) as Array) + (sv.data.get("storage", []) as Array)
	for x: String in take:
		var i: int = _mon_index(all, x)
		var why: String = trade_mon_why(all[i] if i >= 0 else null)
		if not why.is_empty():
			return _fail(why)
	var r: Dictionary = _trade_save(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {}, take, back)
	if not bool(r.ok):
		return r
	for x: Dictionary in r.took:
		keep.append(trade_mon_clean(x))
	m["mons"] = keep
	for k: String in _table("trade_sides", {}):
		if k.begins_with(id + "|"):
			db.trade_sides[k].confirmed = false
	return {"ok": true, "rev": r.rev, "took": take, "back": back}

# --- Weekly boards and the daily gift (20261111000002_online_step1.sql) ---------------------

## Rift ids (every "warden" in data/), like known_ids kind "rift".
static func known_rifts() -> Array:
	var out: Array = []
	var files: Array = []
	for f: String in DirAccess.get_files_at("res://data/maps"):
		files.append("res://data/maps/" + f)
	for f: String in ["story_npcs.json", "endgame.json", "puzzles.json"]:
		files.append("res://data/" + f)
	for path: String in files:
		if path.ends_with(".json"):
			_walk_wardens(JSON.parse_string(FileAccess.get_file_as_string(path)), out)
	return out

static func _walk_wardens(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if str(k) == "warden" and v[k] is String and not str(v[k]).is_empty():
				if not out.has(str(v[k])):
					out.append(str(v[k]))
			else:
				_walk_wardens(v[k], out)
	elif v is Array:
		for x: Variant in v:
			_walk_wardens(x, out)

## Like public._board_json: best first, names only for you and your friends.
func _board(rows: Array, low: bool) -> Array:
	var u: String = me()
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var vx: int = int(x.v) if low else -int(x.v)
		var vy: int = int(y.v) if low else -int(y.v)
		return vx < vy or (vx == vy and int(x.at) < int(y.at)))
	var out: Array = []
	var rank: int = 0
	var last: int = -2147483648
	for i: int in rows.size():
		var r: Dictionary = rows[i]
		if int(r.v) != last:
			rank = i + 1
			last = int(r.v)
		if rank <= config_int("board_rows", 20) or r.u == u:
			out.append({"rank": rank, "score": int(r.v), "me": r.u == u,
				"name": profile_of(r.u).name if (r.u == u or is_friend(u, r.u)) else ""})
	return out

func _fn_rift_board(a: Dictionary) -> Dictionary:
	if not flag_on("rift_board", 2147483647):
		return _fail("feature_off")
	var u: String = me()
	var rift: String = str(a.get("p_rift", ""))
	var friends_only: bool = bool(a.get("p_friends", true))
	var best: Dictionary = {}
	for r: Dictionary in _table("rift_runs", []):
		if r.week != _week() or r.rift != rift or not battle_ok(int(r.battle_id)) or not db.users.has(r.u):
			continue
		if is_blocked(u, r.u) or (friends_only and r.u != u and not is_friend(u, r.u)):
			continue
		var cur: Variant = best.get(r.u)
		if cur == null or int(r.v) < int(cur.v) or (int(r.v) == int(cur.v) and int(r.at) < int(cur.at)):
			best[r.u] = r
	return {"ok": true, "week": _week(), "rift": rift, "rows": _board(best.values(), true)}

func _fn_league_board(a: Dictionary) -> Dictionary:
	if not flag_on("league_board", 2147483647):
		return _fail("feature_off")
	var league: String = str(a.get("p_league", ""))
	if not league in ["fair", "open"]:
		return _fail("bad_league")
	var u: String = me()
	var friends_only: bool = bool(a.get("p_friends", true))
	var wins: Dictionary = {}
	for m: Dictionary in (_table("league_matches", {}) as Dictionary).values():
		if m.league != league or m.state != "done" or not bool(m.rated) or not (m.get("score") is float and float(m.score) == 1.0):
			continue
		if WeeklyChallenge.week_key(int(m.created_at)) != _week() or not db.users.has(m.user) or is_blocked(u, m.user):
			continue
		if friends_only and m.user != u and not is_friend(u, m.user):
			continue
		var w: Dictionary = wins.get_or_add(m.user, {"u": m.user, "v": 0, "at": 0})
		w.v = int(w.v) + 1
		w.at = maxi(int(w.at), int(m.created_at))
	return {"ok": true, "week": _week(), "league": league, "rows": _board(wins.values(), false)}

func _fn_daily_gift_state(_a: Dictionary) -> Dictionary:
	if not flag_on("daily_gift", 2147483647):
		return _fail("feature_off")
	return {"ok": true, "ready": str(_user().get("daily_gift_day", "")) != _today(), "table": db.config.daily_gift_table}

func _fn_daily_gift_claim(a: Dictionary) -> Dictionary:
	if not flag_on("daily_gift", 2147483647):
		return _fail("feature_off")
	if str(_user().get("daily_gift_day", "")) == _today():
		return _fail("already_today")
	var item: String = roll_gift(db.config.daily_gift_table)
	var r: Dictionary = _trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {item: 1})
	if not bool(r.ok):
		return r
	_user()["daily_gift_day"] = _today()
	return {"ok": true, "rev": r.rev, "item": item, "bag": {item: 1}}

# --- Save history (plan area 7, item 3009), like 20261110000015_save_history.sql -----------------

## Puts the stored version [param cur] of [param slot] into the history before it changes to
## [param new_data] (nothing when the data stays the same). Keeps the newest save_history_keep.
func keep_history(slot: int, cur: Variant, new_data: Dictionary) -> void:
	if cur == null or cur.data == new_data:
		return
	var hist: Array = _user().get_or_add("save_history", [])
	hist.append({"id": _next_id("save_history"), "slot": slot, "rev": int(cur.rev), "data": (cur.data as Dictionary).duplicate(true),
		"summary": str(cur.get("summary", "")), "saved_at": int(cur.get("saved_at", 0))})
	var mine: Array = hist.filter(func(h: Dictionary) -> bool: return int(h.slot) == slot)
	while mine.size() > config_int("save_history_keep", 5):
		hist.erase(mine.pop_front())

func _fn_save_history_list(a: Dictionary) -> Dictionary:
	var slot: int = int(a.get("p_slot", 0))
	var out: Array = []
	for h: Dictionary in _user().get("save_history", []):
		if int(h.slot) == slot:
			var pt: Variant = h.data.get("play_time", 0)
			out.push_front({"id": h.id, "rev": h.rev, "summary": h.summary, "saved_at": h.saved_at,
				"play_time": float(pt) if pt is float or pt is int else 0.0})
	return {"ok": true, "saves": out}

func _fn_save_restore(a: Dictionary) -> Dictionary:
	var slot: int = int(a.get("p_slot", 0))
	var found: Variant = null
	for h: Dictionary in _user().get("save_history", []):
		if int(h.id) == int(a.get("p_id", -1)) and int(h.slot) == slot:
			found = h
	var sv: Variant = _saves().get(str(slot))
	if found == null or sv == null:
		return _fail("no_such_save")
	keep_history(slot, sv, found.data)
	sv.data = (found.data as Dictionary).duplicate(true)
	sv.summary = found.summary
	sv.rev = int(sv.rev) + 1
	sv.saved_at = now()
	sv.erase("request_id")
	return {"ok": true, "rev": sv.rev}

# --- Live duels (Online 100, area 1), like 20261111000040_live_duel.sql ------------------------

## server_config.live_duel (data/live_duel.json).
func live_cfg() -> Dictionary:
	var v: Variant = db.config.get("live_duel")
	if not v is Dictionary:
		v = LiveDuel.config()
		db.config["live_duel"] = v
	return v

func _live(id: Variant) -> Variant:
	return (_table("live_duels", {}) as Dictionary).get(str(int(id)))

## 0 for the inviter, 1 for the friend, -1 for anyone else.
func _live_side(d: Dictionary) -> int:
	return 0 if d.a == me() else (1 if d.b == me() else -1)

## Like public._live_tick: invites run out, and a side that stays away longer than the turn plus
## reconnect_seconds loses (both away: the duel ends without a winner).
func _live_tick(d: Dictionary) -> void:
	var c: Dictionary = live_cfg()
	if d.state == "invited" and now() > int(d.deadline):
		d.state = "expired"
	elif (d.state == "picking" or d.state == "running") and now() > int(d.deadline) + int(c.reconnect_seconds):
		var have: Array = d.pick if d.state == "picking" else (d.moves as Dictionary).get(str(d.round), [null, null])
		var away0: bool = have[0] == null
		var away1: bool = have[1] == null
		d.state = "done"
		d.reason = "timeout"
		d.winner = -1 if away0 == away1 else (1 if away0 else 0)

func _live_out(d: Dictionary) -> Dictionary:
	var teams: Array = []
	if d.state != "invited" and d.state != "picking" and d.pick[0] != null and d.pick[1] != null:
		for side: int in 2:
			var rows: Array = []
			for i: Variant in d.pick[side]:
				rows.append((d.show[side][int(i)] as Dictionary).duplicate(true))
			teams.append(rows)
	return {"ok": true, "id": int(d.id), "side": _live_side(d), "state": d.state, "show": (d.show as Array).duplicate(true),
		"picked": [d.pick[0] != null, d.pick[1] != null], "teams": teams, "seed": d.seed, "round": d.round,
		"moves": (d.moves as Dictionary).duplicate(true), "deadline": d.deadline, "turn_seconds": int(live_cfg().turn_seconds),
		"winner": d.winner, "reason": d.reason, "emotes": (d.emotes as Array).duplicate(true)}

func _live_new(other: String) -> Dictionary:
	var c: Dictionary = live_cfg()
	var show: Array = []
	for uid: String in [me(), other]:
		var team: Array = profile_of(uid).get("team", [])
		show.append(team.slice(0, int(c.show)))
	if (show[0] as Array).size() < int(c.pick) or (show[1] as Array).size() < int(c.pick):
		return _fail("team_too_small")
	var id: int = _next_id("live_duels")
	var d: Dictionary = {"id": id, "a": me(), "b": other, "state": "invited", "show": show, "pick": [null, null],
		"seed": rng.randi() & 0x7fffffff, "round": 0, "moves": {}, "deadline": now() + 60 * int(c.invite_minutes),
		"winner": -1, "reason": "", "emotes": [], "report": [null, null]}
	_table("live_duels", {})[str(id)] = d
	return {"ok": true, "id": id}

func _fn_live_invite(a: Dictionary) -> Dictionary:
	if not flag_on("live_duel", 2147483647):
		return _fail("feature_off")
	var other: String = uid_for_code(str(a.get("p_code", "")))
	if other.is_empty() or other == me() or is_blocked(me(), other) or not is_friend(me(), other):
		return _fail("not_friends")
	if not _rate_ok("live_invite", int(live_cfg().invites_per_hour)):
		return _fail("slow_down")
	return _live_new(other)

func _fn_live_list(_a: Dictionary) -> Dictionary:
	var out: Array = []
	for d: Dictionary in (_table("live_duels", {}) as Dictionary).values():
		if _live_side(d) < 0:
			continue
		_live_tick(d)
		if d.state != "done" and d.state != "expired":
			var other: String = d.b if d.a == me() else d.a
			out.append({"id": int(d.id), "state": d.state, "side": _live_side(d), "name": str(profile_of(other).name)})
	return {"ok": true, "duels": out}

func _live_mine(a: Dictionary) -> Variant:
	var d: Variant = _live(a.get("p_id", -1))
	if d == null or _live_side(d) < 0:
		return null
	_live_tick(d)
	return d

func _fn_live_answer(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null or _live_side(d) != 1:
		return _fail("no_such_duel")
	if d.state != "invited":
		return _fail("duel_closed")
	if not bool(a.get("p_accept", false)):
		d.state = "expired"
		return {"ok": true, "state": d.state}
	d.state = "picking"
	d.deadline = now() + int(live_cfg().pick_seconds)
	return _live_out(d)

func _fn_live_pick(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	var side: int = _live_side(d)
	if d.state != "picking" or d.pick[side] != null:
		return _fail("duel_closed")
	var pick: Variant = LiveDuel.check_pick(a.get("p_pick"), (d.show[side] as Array).size(), int(live_cfg().pick))
	if pick == null:
		return _fail("bad_pick")
	d.pick[side] = pick
	if d.pick[0] != null and d.pick[1] != null:
		d.state = "running"
		d.round = 1
		d.deadline = now() + int(live_cfg().turn_seconds)
	return _live_out(d)

func _fn_live_move(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	var side: int = _live_side(d)
	if d.state != "running":
		return _fail("duel_closed")
	if int(a.get("p_round", -1)) != int(d.round):
		return _fail("wrong_round")
	var mv: Variant = a.get("p_input")
	if not mv is Dictionary or JSON.stringify(mv).length() > 400:
		return _fail("bad_input")
	var row: Array = (d.moves as Dictionary).get_or_add(str(d.round), [null, null])
	if row[side] != null:
		return _fail("already_moved")
	row[side] = mv
	if row[0] != null and row[1] != null:
		d.round = int(d.round) + 1
		d.deadline = now() + int(live_cfg().turn_seconds)
	return _live_out(d)

func _fn_live_state(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	return _live_out(d)

func _fn_live_emote(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	var n: int = int(a.get("p_emote", -1))
	if n < 0 or n >= int(live_cfg().emotes):
		return _fail("bad_emote")
	var side: int = _live_side(d)
	var used: int = 0
	for e: Dictionary in d.emotes:
		if int(e.side) == side:
			used += 1
	if used >= int(live_cfg().emote_limit):
		return _fail("slow_down")
	(d.emotes as Array).append({"side": side, "emote": n, "at": now()})
	return {"ok": true}

func _fn_live_forfeit(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	if d.state != "picking" and d.state != "running":
		return _fail("duel_closed")
	d.state = "done"
	d.reason = "forfeit"
	d.winner = 1 - _live_side(d)
	return _live_out(d)

func _fn_live_finish(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	var w: int = int(a.get("p_winner", -2))
	if d.state != "running" or w < -1 or w > 1:
		return _fail("duel_closed")
	d.report[_live_side(d)] = w
	if d.report[0] != null and d.report[1] != null:
		d.state = "done"
		d.reason = "played" if int(d.report[0]) == int(d.report[1]) else "disputed"
		d.winner = int(d.report[0]) if d.reason == "played" else -1
	return _live_out(d)

func _fn_live_rematch(a: Dictionary) -> Dictionary:
	var d: Variant = _live_mine(a)
	if d == null:
		return _fail("no_such_duel")
	if d.state != "done":
		return _fail("duel_closed")
	var other: String = d.b if d.a == me() else d.a
	if is_blocked(me(), other) or not is_friend(me(), other):
		return _fail("not_friends")
	if not _rate_ok("live_invite", int(live_cfg().invites_per_hour)):
		return _fail("slow_down")
	return _live_new(other)

# --- Bund extras (Online 100, area 4), like 20261111000060_bund_more.sql ------------------------

## server_config.bund_rules (data/bund_rules.json).
func bund_cfg() -> Dictionary:
	var v: Variant = db.config.get("bund_rules")
	if not v is Dictionary:
		v = BundRules.config()
		db.config["bund_rules"] = v
	return v

func _bund_goal(row: Dictionary) -> int:
	return int(row.get("goal_progress", 0)) if str(row.get("goal_week", "")) == _week() else 0

func _bund_active(b: String) -> int:
	var n: int = 0
	for x: String in _bund_list(b):
		if int(profile_of(x).get("last_seen", 0)) > now() - 86400 * int(bund_cfg().active_days):
			n += 1
	return n

func _fn_bund_stats(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty():
		return _fail("no_bund")
	var row: Dictionary = db.bunds[b]
	var c: Dictionary = bund_cfg()
	var claims: Array = row.get("goal_claims", [])
	return {"ok": true, "xp": int(row.get("xp", 0)), "level": BundRules.level(c, int(row.get("xp", 0))),
		"lang": str(row.get("lang", "")), "open": bool(row.get("open", false)), "goal": _bund_goal(row),
		"goal_target": int(c.goal_target), "goal_reward": (c.goal_reward as Dictionary).duplicate(),
		"goal_claimed": claims.has(_week() + "|" + u),
		"donated_today": int((_user().get("bund_donated", {}) as Dictionary).get(_today(), 0)), "donate_daily": int(c.donate_daily)}

func _fn_bund_settings(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty() or _bund_role(u) != "leader":
		return _fail("not_allowed")
	var lang: String = str(a.get("p_lang", ""))
	if not BundRules.lang_ok(bund_cfg(), lang):
		return _fail("bad_lang")
	db.bunds[b].lang = lang
	db.bunds[b].open = bool(a.get("p_open", false))
	return {"ok": true}

func _fn_bund_search(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	if not _rate_ok("bund_search", 60):
		return _fail("slow_down")
	var lang: String = str(a.get("p_lang", ""))
	var out: Array = []
	for b: String in _table("bunds", {}):
		var row: Dictionary = db.bunds[b]
		var size: int = _bund_list(b).size()
		if (not lang.is_empty() and str(row.get("lang", "")) != lang) or int(row.dissolve_at) > 0 or size >= config_int("bund_max", 30):
			continue
		if _bund_list(b).any(func(x: String) -> bool: return is_blocked(u, x)):
			continue
		out.append({"bund": int(b), "name": row.name, "lang": str(row.get("lang", "")), "open": bool(row.get("open", false)),
			"level": BundRules.level(bund_cfg(), int(row.get("xp", 0))), "size": size, "active": _bund_active(b)})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if int(p.active) != int(q.active):
			return int(p.active) > int(q.active)
		if int(p.size) != int(q.size):
			return int(p.size) > int(q.size)
		return int(p.bund) < int(q.bund))
	return {"ok": true, "bunds": out.slice(0, int(bund_cfg().search_rows))}

func _fn_bund_join(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = str(int(a.get("p_bund", -1)))
	if not _table("bunds", {}).has(b) or _bund_list(b).any(func(x: String) -> bool: return is_blocked(u, x)):
		return _fail("no_such_bund")
	if not _bund_of(u).is_empty():
		return _fail("in_bund")
	if not _rate_ok("bund_request", 10):
		return _fail("slow_down")
	if bool(db.bunds[b].get("open", false)):
		e = _bund_join(b, u, "member")
		return _fail(e) if not e.is_empty() else {"ok": true, "joined": true}
	if _invite_of(b, u, "") < 0:
		(_table("bund_invites", []) as Array).append({"bund": b, "user": u, "kind": "request", "by": u, "at": now()})
	return {"ok": true, "joined": false}

func _fn_bund_donate(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty():
		return _fail("no_bund")
	var item: String = str(a.get("p_item", ""))
	var count: int = int(a.get("p_count", 0))
	if item.is_empty() or count < 1 or count > 99:
		return _fail("bad_count")
	var done: Dictionary = _user().get_or_add("bund_donated", {})
	if int(done.get(_today(), 0)) + count > int(bund_cfg().donate_daily):
		return _fail("limit_today")
	var r: Dictionary = _trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {item: -count})
	if not bool(r.ok):
		return r
	done[_today()] = int(done.get(_today(), 0)) + count
	var row: Dictionary = db.bunds[b]
	row["xp"] = int(row.get("xp", 0)) + BundRules.donate_xp(bund_cfg(), count)
	row["goal_progress"] = _bund_goal(row) + count
	row["goal_week"] = _week()
	return {"ok": true, "rev": r.rev, "bag": {item: -count}, "xp": row.xp, "goal": _bund_goal(row)}

func _fn_bund_goal_claim(a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var b: String = _bund_of(u)
	if b.is_empty():
		return _fail("no_bund")
	var row: Dictionary = db.bunds[b]
	if _bund_goal(row) < int(bund_cfg().goal_target):
		return _fail("goal_open")
	var claims: Array = row.get_or_add("goal_claims", [])
	if claims.has(_week() + "|" + u):
		return _fail("claimed")
	var rw: Dictionary = bund_cfg().goal_reward
	var r: Dictionary = _trade_bag(int(a.get("p_slot", 0)), int(a.get("p_rev", -1)), {str(rw.item): int(rw.count)})
	if not bool(r.ok):
		return r
	claims.append(_week() + "|" + u)
	return {"ok": true, "rev": r.rev, "item": rw.item, "count": int(rw.count), "bag": {str(rw.item): int(rw.count)}}

func _fn_bund_board(_a: Dictionary) -> Dictionary:
	var u: String = me()
	var e: String = _bund_check(u)
	if not e.is_empty():
		return _fail(e)
	var rows: Array = []
	for b: String in _table("bunds", {}):
		var row: Dictionary = db.bunds[b]
		if int(row.dissolve_at) == 0:
			rows.append({"id": int(b), "name": row.name, "xp": int(row.get("xp", 0)),
				"level": BundRules.level(bund_cfg(), int(row.get("xp", 0))), "mine": _bund_of(u) == b})
	rows.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.xp) > int(q.xp) or (int(p.xp) == int(q.xp) and int(p.id) < int(q.id)))
	rows = rows.slice(0, int(bund_cfg().board_rows))
	for r: Dictionary in rows:
		r.erase("id")
	return {"ok": true, "rows": rows}

## Planned maintenance time (Online 100 point 95), 0 = none.
func _fn_maintenance_info(_a: Dictionary) -> Dictionary:
	return {"at": int(db.config.get("maintenance_at", 0))}
