class_name LocalNotify
extends RefCounted
## Opt-in phone notes (plan Chimora 100, item 76, Ali's "Ja" of 2026-11-21): scheduled on this
## device only, no push server, no third-party SDK, nothing leaves the phone. Only two kinds: a
## roaming trip is over (Expeditions) and a new Find of the Day is waiting (DailyFind). The day's
## tasks are never announced (plan 3500, tests/unit/test_endgame_p3a.gd).
## Off by default. The game asks once, in its own words, when the first trip starts; only a yes
## brings the phone's permission prompt. Settings > Game turns it off (and on) again.
## Rules: at most one note per kind and day, none from QUIET_FROM to QUIET_TO local time (moved to
## QUIET_TO), everything scheduled is cancelled when the app opens and planned anew when it goes
## to the background. Texts are neutral and never mention the shop.
## Native side: Android plugin ChimoraNotify (plugins/chimora_notify, AlarmManager + NotificationCompat),
## iOS ChimoraStoreKit.notify_* (plugins/chimora_storekit/ios/ChimoraNotify.swift,
## UNUserNotificationCenter). Without either (desktop, web, tests) every call is a no-op.

const PATH: String = "user://notify.json"
const QUIET_FROM: int = 21
const QUIET_TO: int = 9
const DAY: int = 86400
const KIND_TRIP: String = "trip"
const KIND_FIND: String = "find"
const KINDS: Array[String] = [KIND_TRIP, KIND_FIND]
## Fixed note ids per kind: a new plan replaces the old note of the same kind.
const IDS: Dictionary = {KIND_TRIP: 1, KIND_FIND: 2}
const ANDROID_SINGLETON: String = "ChimoraNotify"
const IOS_SINGLETON: String = "ChimoraStoreKit"

const TITLE: String = "Chimora"
const TRIP_TEXT: String = "%s is back from the roaming trip."
const FIND_TEXT: String = "A new Find of the Day is waiting in Veydal."
const ASK_TEXT: String = "Chimora can send a short note on this phone when a roaming trip is over or a new Find of the Day is waiting. Never at night, at most one a day each. You can turn it off any time in Settings."
const ASK_QUESTION: String = "Turn on notifications?"
const PRIVACY_LINE: String = "Notifications are off unless you turn them on. They are planned on this phone only; nothing about them is sent anywhere."

## {"enabled": bool, "asked": bool, "scheduled": [{"kind", "at", "day"}], "last_day": {kind: "YYYY-MM-DD"}}
static var state: Dictionary = {}
static var _loaded: bool = false
static var path: String = PATH
## Tests and screenshot tools put a fake plugin here.
static var plugin_override: Object = null

# --- Pure rules ---------------------------------------------------------------------------

## Local calendar day of unix time [param at] with the time zone offset [param bias] (seconds).
static func day_of(at: int, bias: int) -> String:
	return Time.get_date_string_from_unix_time(at + bias)

## Seconds since local midnight.
static func _since_midnight(at: int, bias: int) -> int:
	return posmod(at + bias, DAY)

## [param at], or the next QUIET_TO o'clock when [param at] falls in the quiet hours.
static func outside_quiet(at: int, bias: int) -> int:
	var sod: int = _since_midnight(at, bias)
	var hour: int = sod / 3600
	if hour >= QUIET_FROM:
		return at - sod + DAY + QUIET_TO * 3600
	if hour < QUIET_TO:
		return at - sod + QUIET_TO * 3600
	return at

## When a note of [param kind] due at [param at] may show: outside the quiet hours and not on a
## day that already had one of this kind (then QUIET_TO o'clock the day after).
static func fire_time(st: Dictionary, kind: String, at: int, bias: int) -> int:
	var t: int = outside_quiet(at, bias)
	var last: Dictionary = st.get("last_day", {}) if st.get("last_day") is Dictionary else {}
	if day_of(t, bias) == str(last.get(kind, "")):
		t = t - _since_midnight(t, bias) + DAY + QUIET_TO * 3600
	return t

## The notes to schedule when the app leaves the foreground at [param now]: [{"kind", "at",
## "delay", "name"}]. [param trip] is the next trip still under way ({"at": end, "name"}) or {};
## [param find_known] is true once the player met a Find of the Day (so the note makes sense).
static func plan(st: Dictionary, now: int, bias: int, trip: Dictionary, find_known: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not bool(st.get("enabled", false)):
		return out
	if not trip.is_empty() and int(trip.get("at", 0)) > now:
		var t: int = fire_time(st, KIND_TRIP, int(trip.at), bias)
		out.append({"kind": KIND_TRIP, "at": t, "delay": t - now, "name": str(trip.get("name", ""))})
	if find_known:
		var midnight: int = now - _since_midnight(now, bias) + DAY
		var f: int = fire_time(st, KIND_FIND, midnight, bias)
		out.append({"kind": KIND_FIND, "at": f, "delay": f - now, "name": ""})
	return out

## Remembers what was scheduled.
static func note_scheduled(st: Dictionary, entries: Array[Dictionary], bias: int) -> void:
	var list: Array = []
	for e: Dictionary in entries:
		list.append({"kind": e.kind, "at": int(e.at), "day": day_of(int(e.at), bias)})
	st["scheduled"] = list

## The app opened at [param now]: notes whose time has passed have shown, so their day counts;
## all others are cancelled.
static func note_open(st: Dictionary, now: int) -> void:
	var last: Dictionary = st.get("last_day", {}) if st.get("last_day") is Dictionary else {}
	for e: Variant in st.get("scheduled", []) if st.get("scheduled") is Array else []:
		if e is Dictionary and int((e as Dictionary).get("at", 0)) <= now:
			last[str(e.kind)] = str(e.get("day", ""))
	st["last_day"] = last
	st["scheduled"] = []

## Ask once, and only where notes can be shown at all.
static func should_ask(st: Dictionary, available: bool) -> bool:
	return available and not bool(st.get("asked", false))

static func set_answer(st: Dictionary, yes: bool) -> void:
	st["asked"] = true
	st["enabled"] = yes

## The player-facing text of a planned note (English key, translated).
static func body_for(e: Dictionary) -> String:
	if str(e.kind) == KIND_TRIP:
		return Loc.t(TRIP_TEXT) % str(e.get("name", ""))
	return Loc.t(FIND_TEXT)

## The next trip still under way: {"at": end in server time, "name"}, or {}.
static func next_trip() -> Dictionary:
	var best: Dictionary = {}
	for t: Dictionary in Expeditions.trips():
		var left: int = Expeditions.seconds_left(t)
		if left <= 0:
			continue
		var at: int = Online.unix_now() + left
		if best.is_empty() or at < int(best.at):
			var who: String = ""
			for s: Spirling in GameState.storage:
				if s.uid == str(t.uid):
					who = s.display_name()
			best = {"at": at, "name": who}
	return best

## True once any Find of the Day was met in this journey.
static func find_known(flags: Dictionary) -> bool:
	for k: Variant in flags:
		if str(k).begins_with("daily_find_") and bool(flags[k]):
			return true
	return false

# --- Runtime ------------------------------------------------------------------------------

## The platform's notification plugin, or null (desktop, web, builds without it).
static func plugin() -> Object:
	if plugin_override != null:
		return plugin_override
	for s: String in [ANDROID_SINGLETON, IOS_SINGLETON]:
		if Engine.has_singleton(s):
			var p: Object = Engine.get_singleton(s)
			if p.has_method("notify_schedule"):
				return p
	return null

static func available() -> bool:
	return plugin() != null

static func is_enabled() -> bool:
	_load()
	return bool(state.get("enabled", false))

## App start and every return from the background: cancel what was planned.
static func app_opened() -> void:
	_load()
	var p: Object = plugin()
	if p != null:
		p.call("notify_cancel_all")
	note_open(state, Online.unix_now())
	_store()

## The app goes to the background: plan the notes anew.
static func app_left() -> void:
	_load()
	var p: Object = plugin()
	if p == null or not bool(state.get("enabled", false)):
		return
	p.call("notify_cancel_all")
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var trip: Dictionary = next_trip() if GameState.in_game else {}
	var entries: Array[Dictionary] = plan(state, Online.unix_now(), bias, trip, GameState.in_game and find_known(GameState.flags))
	for e: Dictionary in entries:
		p.call("notify_schedule", int(IDS[e.kind]), Loc.t(TITLE), body_for(e), int(e.delay))
	note_scheduled(state, entries, bias)
	_store()

## The one question, asked at a natural moment (the first roaming trip sets off).
static func offer(menu: MenuHost) -> void:
	_load()
	if not should_ask(state, available()):
		return
	await menu.info(ASK_TEXT)
	var yes: bool = await menu.confirm(ASK_QUESTION)
	set_answer(state, yes)
	_store()
	if yes:
		request_permission()

## Settings toggle: off cancels everything; on asks the phone for permission.
static func toggle() -> void:
	_load()
	var on: bool = not bool(state.get("enabled", false))
	set_answer(state, on)
	_store()
	var p: Object = plugin()
	if p == null:
		return
	if on:
		request_permission()
	else:
		p.call("notify_cancel_all")

static func request_permission() -> void:
	var p: Object = plugin()
	if p == null:
		return
	if p.has_signal("notify_event") and not p.is_connected("notify_event", _on_event):
		p.connect("notify_event", _on_event)
	p.call("notify_request_permission")

## {"kind": "permission", "granted": bool} from the plugin: a refused permission turns it off.
static func _on_event(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if d is Dictionary and str(d.get("kind", "")) == "permission" and not bool(d.get("granted", false)):
		_load()
		state["enabled"] = false
		_store()

static func reset_for_tests() -> void:
	state = {}
	_loaded = true

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(path):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary:
			state = raw

static func _store() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state))
