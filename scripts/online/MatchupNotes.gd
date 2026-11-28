class_name MatchupNotes
extends RefCounted
## KAMPF_PLAN_1000 item 107: matchup notes by Lantern Mail. A Wayfarer sends a friend what they
## learned about matchups (GameState.known_matchups, "element:species" -> multiplier); the friend
## opens the mail and keeps the notes they did not have yet. One notes mail per friend and day;
## the pair gets friendship points for it. Same rules as
## supabase/migrations/20261114120260_matchup_notes.sql, which the local stand-in server mirrors here.

const CONFIG_PATH: String = "res://data/matchup_notes.json"
const DEFAULTS: Dictionary = {"max_notes": 30, "per_friend_per_day": 1, "points": 1}
const MIN_MULT: float = 0.25
const MAX_MULT: float = 4.0

static var _cfg: Dictionary = {}

static func cfg(key: String) -> int:
	if _cfg.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_cfg = v if v is Dictionary else {}
	return int(_cfg.get(key, DEFAULTS.get(key, 0)))

## True when [param key] -> [param mult] is a note the server takes ("<element>:<Species>", 0.25..4).
static func valid_note(key: String, mult: Variant) -> bool:
	var re := RegEx.create_from_string("^[0-9]{1,2}:[A-Za-z0-9]{1,20}$")
	if re.search(key) == null or not (mult is float or mult is int):
		return false
	return float(mult) >= MIN_MULT and float(mult) <= MAX_MULT and int(key.get_slice(":", 0)) < Elements.E.size()

## The notes to send from [param known]: at most [param limit], the strong and weak matchups
## first (they teach the most), then in key order, so the same journey always sends the same.
static func pick(known: Dictionary, limit: int) -> Dictionary:
	var keys: Array = known.keys().filter(func(k: Variant) -> bool: return valid_note(str(k), known[k]))
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ia: bool = is_equal_approx(float(known[a]), 1.0)
		var ib: bool = is_equal_approx(float(known[b]), 1.0)
		return str(a) < str(b) if ia == ib else ib)
	var out: Dictionary = {}
	for k: Variant in keys.slice(0, maxi(0, limit)):
		out[str(k)] = float(known[k])
	return out

## Adds the notes of [param notes] that [param known] lacks; returns how many were new.
## A matchup the player saw for themself is never overwritten.
static func learn(known: Dictionary, notes: Dictionary) -> int:
	var n: int = 0
	for k: Variant in notes:
		if valid_note(str(k), notes[k]) and not known.has(str(k)):
			known[str(k)] = float(notes[k])
			n += 1
	return n

# --- Local stand-in server -----------------------------------------------------------------------

var b: LocalBackend:
	get:
		return _bref.get_ref() if _bref != null else null
var _bref: WeakRef

static func install(backend: LocalBackend) -> MatchupNotes:
	var s := MatchupNotes.new()
	s._bref = weakref(backend)
	for fn: String in ["notes_send", "notes_open"]:
		backend._fns[fn] = Callable(s, "_fn_" + fn)
	backend.set_meta("matchup_notes", s)
	return s

static func _valid_all(notes: Variant) -> bool:
	if not notes is Dictionary or (notes as Dictionary).is_empty() or (notes as Dictionary).size() > cfg("max_notes"):
		return false
	for k: Variant in notes:
		if not valid_note(str(k), notes[k]):
			return false
	return true

func _fn_notes_send(a: Dictionary) -> Dictionary:
	var u: String = b.me()
	var t: String = b.uid_for_code(str(a.get("p_code", "")))
	if not b._can_reach(t):
		return LocalBackend._fail("not_friends")
	var notes: Variant = a.get("p_notes")
	if not _valid_all(notes):
		return LocalBackend._fail("bad_notes")
	var today: int = 0
	for m: Dictionary in b._table("mail", []):
		if m.sender == u and m.recipient == t and m.kind == "notes" and Time.get_date_string_from_unix_time(int(m.at)) == b._today():
			today += 1
	if today >= cfg("per_friend_per_day"):
		return LocalBackend._fail("already_today")
	if not b._rate_ok("mail", 30):
		return LocalBackend._fail("slow_down")
	var m: Dictionary = b._new_mail(t, "notes")
	m["notes"] = (notes as Dictionary).duplicate()
	b._add_points(u, t, cfg("points"))
	return {"ok": true, "points": cfg("points")}

func _fn_notes_open(a: Dictionary) -> Dictionary:
	var m: Variant = b._mail_by_id(int(a.get("p_id", 0)))
	if m == null or str(m.kind) != "notes":
		return LocalBackend._fail("no_such_mail")
	m.opened = true
	m.opened_at = b.now()
	return {"ok": true, "notes": (m.get("notes", {}) as Dictionary).duplicate()}
