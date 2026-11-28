class_name ReviewAsk
extends RefCounted
## The store's own rating sheet (plan Chimora 100, items 74-75): iOS AppStore.requestReview through
## ChimoraStoreKit, Android Play In-App Review through ChimoraReview (plugins/chimora_review).
## Asked straight after a won Warden, rival or boss battle, a sealed Rift or a great bond (a first
## legend, Gleam or ancient kind, 1.3.2), never in battle, never for a kids_locked account, never
## in the first 10 minutes of the first session, once per app version, at most 3 times in 365 days.
## No own question before it and nothing given for a rating (App Review Guideline 5.6.1, Play policy):
## the store sheet itself is all the player sees, and the store may still decide not to show it.

const PATH: String = "user://review_ask.json"
const FIRST_SESSION_SECONDS: int = 600
const MAX_PER_YEAR: int = 3
const YEAR_SECONDS: int = 365 * 86400
const IOS_SINGLETON: String = "ChimoraStoreKit"
const ANDROID_SINGLETON: String = "ChimoraReview"

## State of this install: {"sessions", "session_start", "asked_version", "asked_at": [unix]}.
static var state: Dictionary = {}
static var _loaded: bool = false

## A battle worth a rating moment: a Warden or boss, the rival (a team picked against the starter),
## or the Rift sealed by it.
static func is_highlight(def: Dictionary, sealed: bool) -> bool:
	return sealed or def.has("warden") or def.has("boss") or def.has("team_by_starter")

## Journey record of the great bonds already made: kind -> true.
const GREAT_KEY: String = "great_bonds"
## The rarest tier of wild Spirlings (SpirlingData.rarity).
const RAREST: String = "ancient"

## What makes [param s] a great bond (1.3.2): "legend" (a First Voice or legend), "gleam", "ancient"
## (the rarest tier), or "".
static func great_bond_kind(s: Spirling) -> String:
	if s == null or s.data == null:
		return ""
	if not FirstVoices.entry(s.data.species_name).is_empty():
		return "legend"
	if s.gleam:
		return "gleam"
	if s.data.rarity == RAREST:
		return "ancient"
	return ""

## True when [param s] is the journey's first great bond of its kind; marks the kind in
## [param records], so only the first legend, the first Gleam and the first ancient count.
static func note_great_bond(s: Spirling, records: Dictionary) -> bool:
	var kind: String = great_bond_kind(s)
	if kind.is_empty():
		return false
	var seen: Variant = records.get(GREAT_KEY, {})
	if not seen is Dictionary:
		seen = {}
	if bool((seen as Dictionary).get(kind, false)):
		return false
	(seen as Dictionary)[kind] = true
	records[GREAT_KEY] = seen
	return true

## Counts one start of the app at [param now] (unix seconds).
static func note_session(st: Dictionary, now: int) -> void:
	st["sessions"] = int(st.get("sessions", 0)) + 1
	st["session_start"] = now

## Whether the store sheet may be asked for now. [param kids_locked]: an account under 13
## (Billing.kids_locked) is never asked.
static func may_ask(st: Dictionary, now: int, version: String, in_battle: bool, kids_locked: bool = false) -> bool:
	if in_battle or kids_locked:
		return false
	if int(st.get("sessions", 0)) <= 1 and now - int(st.get("session_start", now)) < FIRST_SESSION_SECONDS:
		return false
	if str(st.get("asked_version", "")) == version:
		return false
	return recent_asks(st, now).size() < MAX_PER_YEAR

## Ask times within the last 365 days.
static func recent_asks(st: Dictionary, now: int) -> Array[int]:
	var out: Array[int] = []
	for t: Variant in st.get("asked_at", []):
		if now - int(t) < YEAR_SECONDS:
			out.append(int(t))
	return out

static func note_asked(st: Dictionary, now: int, version: String) -> void:
	var kept: Array[int] = recent_asks(st, now)
	kept.append(now)
	st["asked_at"] = kept
	st["asked_version"] = version

# --- Runtime ------------------------------------------------------------------------------

## Called once per app start (Online._ready).
static func start_session() -> void:
	_load()
	note_session(state, int(Time.get_unix_time_from_system()))
	_store()

## After a won battle: asks the store when [param highlight] and every rule above allows it.
## Returns true when the store was asked.
static func after_win(highlight: bool, plugin: Object = null) -> bool:
	if not highlight:
		return false
	_load()
	var now: int = int(Time.get_unix_time_from_system())
	if not may_ask(state, now, Online.CLIENT_VERSION_NAME, Online.in_battle, Billing.kids_locked()):
		return false
	var p: Object = plugin if plugin != null else store_plugin()
	if p == null or not p.has_method("request_review"):
		return false
	p.call("request_review")
	note_asked(state, now, Online.CLIENT_VERSION_NAME)
	_store()
	return true

## The platform's review plugin, or null (desktop, web, builds without the plugin).
static func store_plugin() -> Object:
	for s: String in [IOS_SINGLETON, ANDROID_SINGLETON]:
		if Engine.has_singleton(s):
			return Engine.get_singleton(s)
	return null

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PATH):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if raw is Dictionary:
			state = raw

static func _store() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state))
