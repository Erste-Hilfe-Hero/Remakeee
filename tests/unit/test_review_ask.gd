extends GutTest
## Plan Chimora 100, items 74-75: when the store's own rating sheet may be asked for. Pure rules
## with a fake clock (unix seconds), plus after_win with a stand-in plugin.

const T0: int = 1_800_000_000
const DAY: int = 86400

var _old_state: Dictionary
var _old_loaded: bool
var _old_billing: Dictionary

class FakeStore extends Object:
	var asked: int = 0
	func request_review() -> void:
		asked += 1

func before_each() -> void:
	_old_state = ReviewAsk.state.duplicate(true)
	_old_loaded = ReviewAsk._loaded
	_old_billing = Billing.state.duplicate(true)

func after_each() -> void:
	ReviewAsk.state = _old_state
	ReviewAsk._loaded = _old_loaded
	Online.in_battle = false
	Billing.state = _old_billing

func _fresh(now: int) -> Dictionary:
	var st: Dictionary = {}
	ReviewAsk.note_session(st, now)
	return st

func test_never_in_the_first_ten_minutes_of_the_first_session() -> void:
	var st: Dictionary = _fresh(T0)
	assert_false(ReviewAsk.may_ask(st, T0, "1.2.0", false))
	assert_false(ReviewAsk.may_ask(st, T0 + ReviewAsk.FIRST_SESSION_SECONDS - 1, "1.2.0", false), "9:59 is still too early")
	assert_true(ReviewAsk.may_ask(st, T0 + ReviewAsk.FIRST_SESSION_SECONDS, "1.2.0", false), "from 10:00 on")

func test_a_later_session_may_ask_at_once() -> void:
	var st: Dictionary = _fresh(T0)
	ReviewAsk.note_session(st, T0 + 3600)
	assert_eq(int(st.sessions), 2)
	assert_true(ReviewAsk.may_ask(st, T0 + 3601, "1.2.0", false))

func test_never_during_a_battle() -> void:
	var st: Dictionary = _fresh(T0)
	assert_false(ReviewAsk.may_ask(st, T0 + DAY, "1.2.0", true))

func test_once_per_app_version() -> void:
	var st: Dictionary = _fresh(T0)
	ReviewAsk.note_asked(st, T0 + DAY, "1.2.0")
	assert_false(ReviewAsk.may_ask(st, T0 + 2 * DAY, "1.2.0", false), "same version: never again")
	assert_true(ReviewAsk.may_ask(st, T0 + 2 * DAY, "1.3.0", false), "a new version may ask")

func test_at_most_three_times_in_365_days() -> void:
	var st: Dictionary = _fresh(T0)
	ReviewAsk.note_asked(st, T0 + DAY, "1.0.0")
	ReviewAsk.note_asked(st, T0 + 30 * DAY, "1.1.0")
	ReviewAsk.note_asked(st, T0 + 60 * DAY, "1.2.0")
	assert_false(ReviewAsk.may_ask(st, T0 + 90 * DAY, "1.3.0", false), "fourth in the year")
	assert_false(ReviewAsk.may_ask(st, T0 + DAY + ReviewAsk.YEAR_SECONDS - 1, "1.3.0", false))
	assert_true(ReviewAsk.may_ask(st, T0 + DAY + ReviewAsk.YEAR_SECONDS, "1.3.0", false), "the first ask is a year old")
	ReviewAsk.note_asked(st, T0 + DAY + ReviewAsk.YEAR_SECONDS, "1.3.0")
	assert_eq((st.asked_at as Array).size(), 3, "asks older than a year are dropped")

func test_only_warden_rival_boss_or_seal_wins_count() -> void:
	assert_true(ReviewAsk.is_highlight({"warden": "tide"}, false))
	assert_true(ReviewAsk.is_highlight({"boss": "heart"}, false))
	assert_true(ReviewAsk.is_highlight({"team_by_starter": {}}, false), "the rival picks against the starter")
	assert_true(ReviewAsk.is_highlight({}, true), "a sealed Rift")
	assert_false(ReviewAsk.is_highlight({"trainer": "Hiker", "team": []}, false), "a plain Wayfarer")

func test_after_win_asks_the_store_once_and_never_for_plain_wins() -> void:
	var store := FakeStore.new()
	ReviewAsk._loaded = true
	# A second session, so the clock of this machine does not matter.
	ReviewAsk.state = {"sessions": 2, "session_start": 0}
	assert_false(ReviewAsk.after_win(false, store), "plain win")
	Online.in_battle = true
	assert_false(ReviewAsk.after_win(true, store), "battle screen still up")
	Online.in_battle = false
	assert_true(ReviewAsk.after_win(true, store))
	assert_false(ReviewAsk.after_win(true, store), "same version")
	assert_eq(store.asked, 1)
	assert_eq(str(ReviewAsk.state.asked_version), Online.CLIENT_VERSION_NAME)
	store.free()

func test_no_plugin_means_nothing_is_counted() -> void:
	ReviewAsk._loaded = true
	ReviewAsk.state = {"sessions": 2, "session_start": 0}
	var bare := Object.new()
	assert_false(ReviewAsk.after_win(true, bare))
	assert_false(ReviewAsk.state.has("asked_version"), "a build without the plugin keeps its one ask")
	bare.free()

## Kids rule: an account under 13 (kids_locked) never sees the rating sheet, also not after a
## Warden win or a great bond (both go through after_win).
func test_never_for_a_kids_locked_account() -> void:
	var st: Dictionary = {"sessions": 2, "session_start": 0}
	assert_true(ReviewAsk.may_ask(st, T0, "1.2.0", false, false))
	assert_false(ReviewAsk.may_ask(st, T0, "1.2.0", false, true), "kids_locked")
	var store := FakeStore.new()
	ReviewAsk._loaded = true
	ReviewAsk.state = {"sessions": 2, "session_start": 0}
	Billing.state["band"] = 10
	assert_true(Billing.kids_locked())
	assert_false(ReviewAsk.after_win(true, store), "a highlight win of a kids_locked account")
	assert_eq(store.asked, 0)
	assert_false(ReviewAsk.state.has("asked_version"), "nothing counted")
	Billing.state["band"] = 18
	assert_true(ReviewAsk.after_win(true, store), "an adult account is asked")
	assert_eq(store.asked, 1)
	store.free()

## Apple 5.6.1 and Play policy: no own question in front of the store sheet, nothing paid for it.
func test_no_pre_prompt_and_no_reward() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/online/ReviewAsk.gd")
	for bad: String in ["MenuHost", "confirm(", "pick_strings", "give_item", "add_item", "money"]:
		assert_false(src.contains(bad), "ReviewAsk must not use %s" % bad)
