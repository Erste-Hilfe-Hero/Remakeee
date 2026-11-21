class_name LocalTradeGifts
extends RefCounted
## Trading and gifting between friends (Online 100, area 5) in the local stand-in server, with the
## same rules as supabase/migrations/20261112000050_trade_gifts.sql: trades per day and the trade
## history, the wish list, two gifts a day from friendship level 3, greeting cards with a Spirling
## motif, thanks for a gift and lending a Spirling. tests/unit/test_trade_gifts.gd checks it.

const CONFIG_PATH: String = "res://data/trade_gifts.json"
const DEFAULTS: Dictionary = {"trades_per_day": 5, "history_days": 30, "gifts_per_day": 1, "gifts_per_day_close": 2,
	"close_level": 3, "wish_max": 3, "cards_per_day": 10, "thanks_points": 2, "lend_min_level": 3, "lend_hours": 48,
	"lends_per_day": 3, "borrow_max": 1}
const LEND_KINDS: Array[String] = ["raid", "live_duel"]

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef
var _trade_confirm: Callable
var _friends_list: Callable
var _mail_list: Callable

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	return v if v is Dictionary else {}

static func install(backend: LocalBackend) -> LocalTradeGifts:
	var s := LocalTradeGifts.new()
	s._bref = weakref(backend)
	s._trade_confirm = backend._fns["trade_confirm"]
	s._friends_list = backend._fns["friends_list"]
	s._mail_list = backend._fns["mail_list"]
	for fn: String in ["trade_confirm", "trade_history", "wish_set", "wish_get", "gift_send", "friends_list", "card_send",
			"gift_thank", "mail_list", "lend_offer", "lend_list", "lend_use", "lend_end"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("trade_gifts", s)
	return s

## server_config.trade_gifts (data/trade_gifts.json), with the migration's defaults.
func cfg(key: String) -> int:
	var v: Variant = b.db.config.get("trade_gifts")
	if not v is Dictionary:
		v = config()
		b.db.config["trade_gifts"] = v
	var x: Variant = (v as Dictionary).get(key, DEFAULTS.get(key, 0))
	return int(x) if (x is int or x is float) else int(DEFAULTS.get(key, 0))

func _day(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix)

# --- 42, 50: trades per day and history --------------------------------------------------------

func _trades_today(uid: String) -> int:
	var n: int = 0
	for r: Dictionary in b._table("trade_log", []):
		if r.user_id == uid and _day(int(r.at)) == b._today():
			n += 1
	return n

static func mons_summary(mons: Variant) -> Array:
	var out: Array = []
	for m: Variant in (mons if mons is Array else []):
		if m is Dictionary:
			out.append({"species": str(m.get("species", "")), "level": int(m.get("level", 1)), "origin_era": int(m.get("origin_era", 1))})
	return out

func _fn_trade_confirm(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var id: String = str(int(a.get("p_trade", 0)))
	var m: Variant = b._trade_side(id, u)
	var other: String = b._trade_other(id, u)
	var o: Variant = b._trade_side(id, other) if not other.is_empty() else null
	# Same order as the SQL: the earlier checks first, the day limit only right before confirming.
	var probe: bool = b._trade_check(u).is_empty() and m != null and o != null
	if probe and b._trade_open_side(id, u) != null and b._trade_pair(u, other).is_empty():
		var seen: Variant = b._trade_offer(a.get("p_theirs"))
		var seen_mons: Array = []
		for x: Variant in (a.get("p_their_mons") if a.get("p_their_mons") is Array else []):
			seen_mons.append(str(x))
		seen_mons.sort()
		var same: bool = o.items == (seen if seen != null else {}) and LocalBackend.mon_uids(o.get("mons", [])) == seen_mons
		var empty: bool = (m.items as Dictionary).is_empty() and (o.items as Dictionary).is_empty() \
			and (m.get("mons", []) as Array).is_empty() and (o.get("mons", []) as Array).is_empty()
		if same and not empty:
			if _trades_today(u) >= cfg("trades_per_day"):
				return LocalBackend._fail("day_limit")
			if bool(o.confirmed) and _trades_today(other) >= cfg("trades_per_day"):
				return LocalBackend._fail("their_day_limit")
	var gave: Dictionary = (m.items as Dictionary).duplicate() if m != null else {}
	var gave_mons: Array = mons_summary(m.get("mons", [])) if m != null else []
	var r: Dictionary = _trade_confirm.call(a)
	if bool(r.get("done", false)):
		var got: Dictionary = (o.items as Dictionary).duplicate()
		var got_mons: Array = mons_summary(o.get("mons", []))
		var rows: Array = b._table("trade_log", [])
		rows.append({"user_id": u, "partner": other, "gave": gave, "got": got, "gave_mons": gave_mons, "got_mons": got_mons, "at": b.now()})
		rows.append({"user_id": other, "partner": u, "gave": got, "got": gave, "gave_mons": got_mons, "got_mons": gave_mons, "at": b.now()})
	return r

func _fn_trade_history(_a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var keep: int = b.now() - cfg("history_days") * 86400
	b.db["trade_log"] = (b._table("trade_log", []) as Array).filter(func(r: Dictionary) -> bool:
		return not (r.user_id == u and int(r.at) < keep))
	var rows: Array = []
	for r: Dictionary in b.db.trade_log:
		if r.user_id != u:
			continue
		var p: String = str(r.get("partner", ""))
		var named: bool = not p.is_empty() and b.db.users.has(p) and not b.is_blocked(u, p)
		rows.push_front({"at": r.at, "name": b.profile_of(p).name if named else null, "gave": r.gave, "got": r.got,
			"gave_mons": r.gave_mons, "got_mons": r.got_mons})
	return {"ok": true, "today": _trades_today(u), "per_day": cfg("trades_per_day"), "rows": rows}

# --- 46: wish list ---------------------------------------------------------------------------

func wishable() -> Array:
	var out: Array = []
	for e: Dictionary in b.db.config.get("gift_table", []):
		if not out.has(str(e.item)):
			out.append(str(e.item))
	for id: Variant in b.trade_items():
		if not out.has(str(id)):
			out.append(str(id))
	return out

func _fn_wish_set(a: Dictionary) -> Dictionary:
	var items: Variant = a.get("p_items")
	if not items is Array or (items as Array).size() > cfg("wish_max"):
		return LocalBackend._fail("bad_wish")
	var ok: Array = wishable()
	var clean: Array = []
	for x: Variant in items:
		if not x is String or not ok.has(x) or clean.has(x):
			return LocalBackend._fail("bad_wish")
		clean.append(x)
	b.profile_of(b.me())["wishes"] = clean
	return {"ok": true, "wishes": clean.duplicate()}

func _fn_wish_get(_a: Dictionary) -> Dictionary:
	return {"ok": true, "wishes": (b.profile_of(b.me()).get("wishes", []) as Array).duplicate(), "items": wishable(),
		"max": cfg("wish_max")}

# --- 47: two gifts a day from friendship level 3 ---------------------------------------------

func gifts_left(u: String, t: String) -> int:
	var f: Variant = b._friendship(u, t)
	var pts: int = int(f.points) if f != null and str(f.status) == "accepted" else 0
	var lim: int = cfg("gifts_per_day_close") if LocalBackend.level_for(pts) >= cfg("close_level") else cfg("gifts_per_day")
	var sent: int = 0
	for m: Dictionary in b._table("mail", []):
		if m.sender == u and m.recipient == t and m.kind == "gift" and _day(int(m.at)) == b._today():
			sent += 1
	return maxi(0, lim - sent)

func _fn_gift_send(a: Dictionary) -> Dictionary:
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not b._can_reach(t):
		return LocalBackend._fail("not_friends")
	if gifts_left(b.me(), t) <= 0:
		return LocalBackend._fail("already_today")
	var gift: Dictionary = b._new_mail(t, "gift")
	var card: Variant = b.profile_of(b.me()).get("card", {})
	gift["motif"] = str(card.get("motif", "")) if card is Dictionary else ""
	b._add_points(b.me(), t, 1)
	return {"ok": true, "left": gifts_left(b.me(), t)}

func _fn_friends_list(a: Dictionary) -> Dictionary:
	var r: Dictionary = _friends_list.call(a)
	for f: Dictionary in r.friends:
		var t: String = b.uid_for_code(str(f.code))
		f["wishes"] = (b.profile_of(t).get("wishes", []) as Array).duplicate()
		f["gifts_left"] = gifts_left(b.me(), t)
		f["gift_sent"] = int(f.gifts_left) == 0
	return r

# --- 48, 49: greeting cards with a Spirling motif, thanks for a gift --------------------------

## True when a Spirling of [param species] is in the team or storage of one of [param uid]'s saves.
func has_species(uid: String, species: String) -> bool:
	var saves: Variant = (b.db.users.get(uid, {}) as Dictionary).get("saves", {})
	if not saves is Dictionary:
		return false
	for sv: Variant in (saves as Dictionary).values():
		var data: Dictionary = sv.get("data", {}) if sv is Dictionary and sv.get("data") is Dictionary else {}
		for key: String in ["party", "storage"]:
			for m: Variant in (data.get(key) if data.get(key) is Array else []):
				if m is Dictionary and str(m.get("species", "")) == species:
					return true
	return false

func _fn_card_send(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not b._can_reach(t):
		return LocalBackend._fail("not_friends")
	if not b.phrase_ok("post", int(a.get("p_phrase", -1))):
		return LocalBackend._fail("bad_phrase")
	var species: String = str(a.get("p_species", ""))
	var re := RegEx.create_from_string("^[A-Za-z0-9]{1,20}$")
	if re.search(species) == null or not has_species(u, species):
		return LocalBackend._fail("no_species")
	var today: int = 0
	for m: Dictionary in b._table("mail", []):
		if m.sender == u and m.kind == "card" and _day(int(m.at)) == b._today():
			today += 1
	if today >= cfg("cards_per_day"):
		return LocalBackend._fail("cards_today")
	if not b._rate_ok("mail", 30):
		return LocalBackend._fail("slow_down")
	var m: Dictionary = b._new_mail(t, "card", int(a.get("p_phrase", 0)))
	m["species"] = species
	return {"ok": true}

func _fn_gift_thank(a: Dictionary) -> Dictionary:
	var m: Variant = b._mail_by_id(int(a.get("p_id", 0)))
	if m == null or str(m.kind) != "gift":
		return LocalBackend._fail("no_such_gift")
	if not bool(m.opened):
		return LocalBackend._fail("open_first")
	if bool(m.get("thanked", false)):
		return LocalBackend._fail("already")
	if not b._can_reach(str(m.sender)):
		return LocalBackend._fail("not_friends")
	m["thanked"] = true
	b._new_mail(str(m.sender), "thanks", 1)
	b._add_points(b.me(), str(m.sender), cfg("thanks_points"))
	return {"ok": true, "points": cfg("thanks_points")}

func _fn_mail_list(a: Dictionary) -> Array:
	var out: Array = _mail_list.call(a)
	for row: Dictionary in out:
		var m: Variant = b._mail_by_id(int(row.id))
		row["species"] = str(m.get("species", "")) if m != null else ""
		row["thanked"] = bool(m.get("thanked", false)) if m != null else false
	return out

# --- 45: lending a Spirling for one raid or one live duel -------------------------------------

func _loans() -> Dictionary:
	var loans: Dictionary = b._table("spirling_loans", {})
	for id: String in loans.keys():
		if int(loans[id].ends_at) < b.now():
			loans.erase(id)
	return loans

func _lend_pair(x: String, y: String) -> String:
	if x.is_empty() or y.is_empty() or x == y or not b.db.users.has(y) or b.is_blocked(x, y) or not b._social(y):
		return "not_friends"
	var f: Variant = b._friendship(x, y)
	if f == null or str(f.status) != "accepted":
		return "not_friends"
	if LocalBackend.level_for(int(f.points)) < cfg("lend_min_level"):
		return "friend_level"
	return ""

## The copy that travels: no nickname, box, favourite mark or Keepsake, its own uid.
static func loan_copy(m: Dictionary) -> Dictionary:
	var c: Dictionary = m.duplicate(true)
	c.erase("held")
	c = LocalBackend.trade_mon_clean(c)
	c["uid"] = "loan_" + str(m.get("uid", ""))
	return c

func _fn_lend_offer(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	if not b.flag_on("lend", 2147483647):
		return LocalBackend._fail("feature_off")
	if not b._social(u):
		return LocalBackend._fail("social_off")
	if b.cheat_held(u):
		return LocalBackend._fail("under_review")
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	var why: String = _lend_pair(u, t)
	if not why.is_empty():
		return LocalBackend._fail(why)
	var loans: Dictionary = _loans()
	var sv: Variant = b._saves().get(str(int(a.get("p_slot", 0))))
	if sv == null:
		return LocalBackend._fail("no_save")
	var all: Array = (sv.data.get("party", []) as Array) + (sv.data.get("storage", []) as Array)
	var uid: String = str(a.get("p_uid", ""))
	var i: int = LocalBackend._mon_index(all, uid)
	if i < 0:
		return LocalBackend._fail("no_spirling")
	var probe: Dictionary = (all[i] as Dictionary).duplicate()
	probe.erase("held")
	probe.erase("favorite")
	why = LocalBackend.trade_mon_why(probe)
	if not why.is_empty():
		return LocalBackend._fail(why)
	var today: int = 0
	var held: int = 0
	for l: Dictionary in loans.values():
		if l.lender == u and l.src_uid == uid and l.state == "lent":
			return LocalBackend._fail("already_lent")
		if l.lender == u and _day(int(l.created_at)) == b._today():
			today += 1
		if l.borrower == t and l.state == "lent":
			held += 1
	if today >= cfg("lends_per_day"):
		return LocalBackend._fail("lends_today")
	if held >= cfg("borrow_max"):
		return LocalBackend._fail("friend_has_one")
	var id: int = b._next_id("loan")
	loans[str(id)] = {"lender": u, "borrower": t, "mon": loan_copy(all[i]), "src_uid": uid, "state": "lent", "used_for": null,
		"created_at": b.now(), "ends_at": b.now() + cfg("lend_hours") * 3600}
	return {"ok": true, "loan": id}

func _loan_row(id: String, l: Dictionary, other: String) -> Dictionary:
	return {"id": int(id), "state": l.state, "used_for": l.used_for, "ends_at": l.ends_at, "mon": (l.mon as Dictionary).duplicate(true),
		"name": b.profile_of(other).name if b.db.users.has(other) and not b.is_blocked(b.me(), other) else null}

func _fn_lend_list(_a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var lent: Array = []
	var borrowed: Array = []
	var loans: Dictionary = _loans()
	var ids: Array = loans.keys()
	ids.sort_custom(func(x: String, y: String) -> bool: return int(x) > int(y))
	for id: String in ids:
		var l: Dictionary = loans[id]
		if l.lender == u:
			lent.append(_loan_row(id, l, l.borrower))
		elif l.borrower == u and not b.is_blocked(u, l.lender):
			borrowed.append(_loan_row(id, l, l.lender))
	return {"ok": true, "lent": lent, "borrowed": borrowed}

func _fn_lend_use(a: Dictionary) -> Dictionary:
	if not b.flag_on("lend", 2147483647):
		return LocalBackend._fail("feature_off")
	if not LEND_KINDS.has(str(a.get("p_kind", ""))):
		return LocalBackend._fail("bad_kind")
	var l: Variant = _loans().get(str(int(a.get("p_loan", 0))))
	if l == null or l.borrower != b.me() or b.is_blocked(b.me(), l.lender):
		return LocalBackend._fail("no_such_loan")
	if l.state != "lent":
		return LocalBackend._fail("used")
	l.state = "used"
	l.used_for = str(a.p_kind)
	return {"ok": true, "mon": (l.mon as Dictionary).duplicate(true)}

func _fn_lend_end(a: Dictionary) -> Dictionary:
	var loans: Dictionary = _loans()
	var id: String = str(int(a.get("p_loan", 0)))
	var l: Variant = loans.get(id)
	if l == null or (l.lender != b.me() and l.borrower != b.me()) or l.state != "lent":
		return LocalBackend._fail("no_such_loan")
	loans.erase(id)
	return {"ok": true}
