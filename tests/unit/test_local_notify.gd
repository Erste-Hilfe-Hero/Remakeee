extends GutTest
## Plan Chimora 100, item 76: opt-in local notifications. The rules run on a fake clock (unix
## times and a time zone offset passed in), the runtime on a fake plugin.

const PATH: String = "user://test_local_notify.json"
## 2026-11-21 00:00 UTC.
const MIDNIGHT: int = 1795219200
const H: int = 3600

class FakePlugin extends RefCounted:
	signal notify_event(json: String)
	var scheduled: Array = []
	var cancels: int = 0
	var asks: int = 0

	func notify_schedule(id: int, title: String, body: String, delay: int) -> void:
		scheduled.append({"id": id, "title": title, "body": body, "delay": delay})

	func notify_cancel_all() -> void:
		cancels += 1
		scheduled.clear()

	func notify_request_permission() -> void:
		asks += 1

var _fake: FakePlugin
var _was_in_game: bool

func before_all() -> void:
	Database.load_all()
	_was_in_game = GameState.in_game

func before_each() -> void:
	Online.clock_offset = 0
	LocalNotify.path = PATH
	LocalNotify.reset_for_tests()
	_fake = FakePlugin.new()
	LocalNotify.plugin_override = null

func after_each() -> void:
	LocalNotify.plugin_override = null
	LocalNotify.reset_for_tests()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)

func after_all() -> void:
	LocalNotify.path = LocalNotify.PATH
	LocalNotify._loaded = false
	LocalNotify.state = {}
	GameState.in_game = _was_in_game
	Loc.set_language("en")

func test_midnight_constant_is_right() -> void:
	assert_eq(Time.get_datetime_string_from_unix_time(MIDNIGHT), "2026-11-21T00:00:00")

func test_quiet_hours_move_to_nine() -> void:
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 10 * H, 0), MIDNIGHT + 10 * H, "10:00 stays")
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 20 * H + 3599, 0), MIDNIGHT + 20 * H + 3599, "20:59 stays")
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 21 * H, 0), MIDNIGHT + 33 * H, "21:00 -> 09:00 next day")
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 23 * H, 0), MIDNIGHT + 33 * H)
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 3 * H, 0), MIDNIGHT + 9 * H, "03:00 -> 09:00 the same day")
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 9 * H - 1, 0), MIDNIGHT + 9 * H)
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 9 * H, 0), MIDNIGHT + 9 * H, "09:00 is allowed")

func test_quiet_hours_use_local_time() -> void:
	# UTC+1: 20:30 UTC is 21:30 local, so the note waits until 09:00 local = 08:00 UTC.
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 20 * H + 1800, H), MIDNIGHT + 32 * H)
	# UTC-5: 13:00 UTC is 08:00 local -> 09:00 local = 14:00 UTC.
	assert_eq(LocalNotify.outside_quiet(MIDNIGHT + 13 * H, -5 * H), MIDNIGHT + 14 * H)

func test_off_by_default_plans_nothing() -> void:
	var st: Dictionary = {}
	assert_eq(LocalNotify.plan(st, MIDNIGHT + 10 * H, 0, {"at": MIDNIGHT + 14 * H, "name": "Kindlop"}, true).size(), 0)
	assert_false(LocalNotify.is_enabled())

func test_trip_note_at_the_trip_end_or_after_the_night() -> void:
	var st: Dictionary = {"enabled": true}
	var now: int = MIDNIGHT + 10 * H
	var p: Array[Dictionary] = LocalNotify.plan(st, now, 0, {"at": MIDNIGHT + 14 * H, "name": "Kindlop"}, false)
	assert_eq(p.size(), 1)
	assert_eq(str(p[0].kind), LocalNotify.KIND_TRIP)
	assert_eq(int(p[0].delay), 4 * H, "a 4 h trip ends in 4 h")
	assert_eq(LocalNotify.body_for(p[0]), "Kindlop is back from the roaming trip.")
	p = LocalNotify.plan(st, MIDNIGHT + 12 * H, 0, {"at": MIDNIGHT + 24 * H, "name": "Kindlop"}, false)
	assert_eq(int(p[0].at), MIDNIGHT + 33 * H, "a 12 h trip ending at midnight waits until 09:00")
	assert_eq(LocalNotify.plan(st, now, 0, {"at": now - 1, "name": "Kindlop"}, false).size(), 0, "a trip already home needs no note")
	assert_eq(LocalNotify.plan(st, now, 0, {}, false).size(), 0)

func test_find_note_next_morning_only_once_known() -> void:
	var st: Dictionary = {"enabled": true}
	var now: int = MIDNIGHT + 15 * H
	assert_eq(LocalNotify.plan(st, now, 0, {}, false).size(), 0, "not before the player met a Find of the Day")
	var p: Array[Dictionary] = LocalNotify.plan(st, now, 0, {}, true)
	assert_eq(p.size(), 1)
	assert_eq(str(p[0].kind), LocalNotify.KIND_FIND)
	assert_eq(int(p[0].at), MIDNIGHT + 33 * H, "the new find at midnight is announced at 09:00")
	assert_eq(LocalNotify.body_for(p[0]), LocalNotify.FIND_TEXT)

func test_at_most_one_note_per_kind_and_day() -> void:
	var st: Dictionary = {"enabled": true}
	var bias: int = 0
	var p: Array[Dictionary] = LocalNotify.plan(st, MIDNIGHT + 8 * H, bias, {"at": MIDNIGHT + 12 * H, "name": "A"}, false)
	LocalNotify.note_scheduled(st, p, bias)
	# The app opens at 13:00: the 12:00 note has shown.
	LocalNotify.note_open(st, MIDNIGHT + 13 * H)
	assert_eq(str(st.last_day[LocalNotify.KIND_TRIP]), "2026-11-21")
	assert_eq((st.scheduled as Array).size(), 0)
	# A second trip back at 16:00 the same day waits for the next morning.
	p = LocalNotify.plan(st, MIDNIGHT + 13 * H, bias, {"at": MIDNIGHT + 16 * H, "name": "B"}, false)
	assert_eq(int(p[0].at), MIDNIGHT + 33 * H)
	# The other kind still may show today.
	assert_false((st.last_day as Dictionary).has(LocalNotify.KIND_FIND))

func test_a_note_cancelled_before_its_time_does_not_count() -> void:
	var st: Dictionary = {"enabled": true}
	var p: Array[Dictionary] = LocalNotify.plan(st, MIDNIGHT + 8 * H, 0, {"at": MIDNIGHT + 12 * H, "name": "A"}, false)
	LocalNotify.note_scheduled(st, p, 0)
	LocalNotify.note_open(st, MIDNIGHT + 11 * H)
	assert_false((st.last_day as Dictionary).has(LocalNotify.KIND_TRIP))
	p = LocalNotify.plan(st, MIDNIGHT + 11 * H, 0, {"at": MIDNIGHT + 12 * H, "name": "A"}, false)
	assert_eq(int(p[0].at), MIDNIGHT + 12 * H)

func test_never_more_than_one_note_per_kind_at_a_time() -> void:
	var st: Dictionary = {"enabled": true}
	var p: Array[Dictionary] = LocalNotify.plan(st, MIDNIGHT + 10 * H, 0, {"at": MIDNIGHT + 14 * H, "name": "A"}, true)
	var kinds: Array = p.map(func(e: Dictionary) -> String: return str(e.kind))
	assert_eq(kinds, [LocalNotify.KIND_TRIP, LocalNotify.KIND_FIND])
	assert_eq(LocalNotify.KINDS, [LocalNotify.KIND_TRIP, LocalNotify.KIND_FIND] as Array[String], "only trips and the Find of the Day")

func test_ask_once_and_only_where_notes_exist() -> void:
	var st: Dictionary = {}
	assert_false(LocalNotify.should_ask(st, false), "desktop, web, builds without the plugin: never asked")
	assert_true(LocalNotify.should_ask(st, true))
	LocalNotify.set_answer(st, false)
	assert_false(LocalNotify.should_ask(st, true), "asked once, also after a no")
	assert_false(bool(st.enabled))

func test_no_plugin_is_a_quiet_no_op() -> void:
	assert_null(LocalNotify.plugin())
	assert_false(LocalNotify.available())
	LocalNotify.app_opened()
	LocalNotify.app_left()
	LocalNotify.request_permission()
	var keys: Array = MenuHost.settings_rows("game").map(func(r: Array) -> String: return str(r[0]))
	assert_does_not_have(keys, "notify", "no settings row where notes cannot show")

func test_toggle_asks_the_phone_and_a_refusal_turns_it_off() -> void:
	LocalNotify.plugin_override = _fake
	LocalNotify.toggle()
	assert_true(LocalNotify.is_enabled())
	assert_eq(_fake.asks, 1, "turning on brings the phone's permission prompt")
	_fake.notify_event.emit(JSON.stringify({"kind": "permission", "granted": false}))
	assert_false(LocalNotify.is_enabled(), "a refused permission shows as Off")
	LocalNotify.toggle()
	_fake.notify_event.emit(JSON.stringify({"kind": "permission", "granted": true}))
	assert_true(LocalNotify.is_enabled())
	LocalNotify.toggle()
	assert_false(LocalNotify.is_enabled())
	assert_gt(_fake.cancels, 0, "off cancels what was planned")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_false(bool((raw as Dictionary).enabled), "stored on this device")

func test_leaving_schedules_and_opening_cancels() -> void:
	LocalNotify.plugin_override = _fake
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	GameState.in_game = true
	var s := Spirling.new(Database.species("Kindlop"), 10)
	if s.uid == "":
		s.uid = "notify-test"
	GameState.storage.append(s)
	assert_true(Expeditions.send(s, 4))
	LocalNotify.app_left()
	assert_eq(_fake.scheduled.size(), 0, "off by default: nothing planned")
	LocalNotify.set_answer(LocalNotify.state, true)
	GameState.flags["daily_find_2026-11-20"] = true
	LocalNotify.app_left()
	assert_eq(_fake.scheduled.size(), 2)
	var trip: Dictionary = _fake.scheduled[0]
	assert_eq(int(trip.id), LocalNotify.IDS[LocalNotify.KIND_TRIP])
	assert_eq(str(trip.title), "Chimora")
	assert_string_contains(str(trip.body), s.display_name())
	assert_gte(int(trip.delay), 4 * H - 5, "not before the trip is home")
	assert_eq(int(_fake.scheduled[1].id), LocalNotify.IDS[LocalNotify.KIND_FIND])
	assert_eq((LocalNotify.state.scheduled as Array).size(), 2)
	LocalNotify.app_opened()
	assert_eq(_fake.scheduled.size(), 0, "opening the app cancels every planned note")
	assert_eq((LocalNotify.state.scheduled as Array).size(), 0)

func test_settings_row_with_plugin_fits_every_language() -> void:
	LocalNotify.plugin_override = _fake
	GameState.in_game = false
	var row: Array = []
	for r: Array in MenuHost.settings_rows("game"):
		if str(r[0]) == "notify":
			row = r
	assert_eq(str(row[1]), "Notifications: Off")
	for lang: String in Loc.LANGUAGES:
		Loc.set_language(lang)
		for t: String in ["Notifications: On", "Notifications: Off"]:
			var shown: String = Loc.t(t)
			if lang != "en":
				assert_ne(shown, t, "%s has a translation for %s" % [lang, t])
			var w: float = PixelFont.get_font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x
			assert_lte(w, 108.0, "%s row too wide (%d px): %s" % [lang, int(w), shown])
		# The question is a list title, which wraps (screenshots in production/qa/evidence/c100-notify/).
		for t: String in [LocalNotify.TRIP_TEXT, LocalNotify.FIND_TEXT, LocalNotify.ASK_TEXT, LocalNotify.ASK_QUESTION, LocalNotify.PRIVACY_LINE]:
			if lang != "en":
				assert_ne(Loc.t(t), t, "%s translates %s" % [lang, t])
	Loc.set_language("en")

func test_texts_are_neutral() -> void:
	# All ages: no note urges anything, least of all buying.
	var shop := RegEx.create_from_string("(?i)(buy|shop|offer|sale|deal|coins?|gems?|€|\\$|hurry|now!|don't miss|last chance)")
	for lang: String in ["en", "de"]:
		Loc.set_language(lang)
		for t: String in [LocalNotify.TRIP_TEXT, LocalNotify.FIND_TEXT]:
			assert_null(shop.search(Loc.t(t)), "%s: %s" % [lang, Loc.t(t)])
	Loc.set_language("en")
