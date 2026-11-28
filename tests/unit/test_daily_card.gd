extends GutTest
## The daily card (DailyBoard, DailyCard, data/daily.json): the 7-day welcome gift that never
## punishes a missed day, the Spirling of the day and its encounter weight, the weekend weather,
## the date rolls, the server cycle (local stand-in and the migration's config) and the card.

const MIGRATION: String = "res://supabase/migrations/20261128060000_daily_gift_cycle.sql"
const SAT: String = "2026-11-28"
const SUN: String = "2026-11-29"
const MON: String = "2026-11-30"
const FRI: String = "2026-11-27"

var _old_backend: OnlineBackend
var _old_state: Online.State

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Billing.state = {}

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	for m: String in ["brindlewick", "fernstair", "crowcrest", "saltmarsh"]:
		DailyTasks.note_map(m)

func after_each() -> void:
	Online.clock_offset = 0

func _day(n: int) -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-12-01T12:00:00") + n * 86400)

# --- Welcome gift ---------------------------------------------------------------------------

func test_gift_once_a_day_and_day_seven_is_bigger() -> void:
	var gifts: Array = DailyBoard.gifts()
	assert_eq(gifts.size(), 7)
	var big: Dictionary = gifts[6]
	for i: int in 6:
		var g: Dictionary = gifts[i]
		assert_lt(int(g.get("coins", 0)) + Database.item(str(g.get("item", ""))).get("price", 0) * int(g.get("count", 0)),
			int(big.get("coins", 0)) + int(Database.item(str(big.get("item", ""))).get("price", 0)) * int(big.get("count", 0)), "day 7 gives the most")
	var tonics: int = GameState.item_count("tonic")
	assert_eq(DailyBoard.take_gift(_day(0)).size(), 1)
	assert_eq(GameState.item_count("tonic"), tonics + 2, "day 1: two Tonics")
	assert_eq(DailyBoard.take_gift(_day(0)), [] as Array[String], "once a day")
	assert_true(DailyBoard.gift_taken_on(_day(0)))
	assert_false(DailyBoard.gift_open(_day(0)))

func test_missed_days_never_reset_the_cycle() -> void:
	DailyBoard.take_gift(_day(0))
	DailyBoard.take_gift(_day(1))
	assert_eq(DailyBoard.gift_step(), 2)
	# A week and a half away: the cycle goes on where it stopped, nothing is lost.
	assert_true(DailyBoard.gift_open(_day(12)))
	var lines: Array[String] = DailyBoard.take_gift(_day(12))
	assert_string_contains(lines[0], "day 3 of 7")
	assert_eq(DailyBoard.gifts_taken(), 3)

func test_seven_gifts_then_the_cycle_starts_again() -> void:
	var coins: int = GameState.money
	var flasks: int = GameState.item_count("max_tonic")
	for i: int in 7:
		DailyBoard.take_gift(_day(i * 2))
	assert_eq(GameState.item_count("max_tonic"), flasks + 1, "the big gift on the seventh opening day")
	assert_eq(GameState.money, coins + 200 + 300 + 500)
	assert_eq(DailyBoard.gift_step(), 0, "the eighth day starts at day 1 again")

func test_turning_the_clock_back_gives_nothing() -> void:
	DailyBoard.take_gift(_day(5))
	assert_false(DailyBoard.gift_open(_day(4)))
	assert_eq(DailyBoard.take_gift(_day(3)), [] as Array[String])

# --- Server cycle ---------------------------------------------------------------------------

func test_server_config_matches_data() -> void:
	var sql: String = FileAccess.get_file_as_string(MIGRATION)
	var re := RegEx.new()
	re.compile("\\('daily_gift', '(\\{.*\\})'\\)")
	var m: RegExMatch = re.search(sql)
	assert_not_null(m, "server_config row in the migration")
	var server: Dictionary = JSON.parse_string(m.get_string(1))
	assert_eq(JSON.stringify(server.gift_rg), JSON.stringify(DailyBoard.data().gift_rg), "data/daily.json gift_rg = server")
	assert_eq((DailyBoard.data().gift_rg as Array).size(), DailyBoard.gifts().size())
	assert_gt(DailyBoard.gift_rg(6), DailyBoard.gift_rg(0), "day 7 brings more Riftglass")

func test_local_server_claims_follow_the_cycle_without_reset() -> void:
	var s := LocalBackend.new()
	s.rng.seed = 1
	Online.backend = s
	Online.state = Online.State.ONLINE
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	var got: Array[int] = []
	for i: int in 8:
		got.append(int(s.call_fn("rg_daily_claim").data.added))
		assert_eq(int(s.call_fn("rg_daily_claim").data.added), 0, "once a day")
		# Every second day missed: the step still moves only with a claim.
		s.clock_offset += 86400 * (1 + i % 2)
	assert_eq(got, [20, 20, 20, 20, 20, 20, 60, 20] as Array[int])

# --- Spirling of the day --------------------------------------------------------------------

func test_featured_is_rolled_from_the_date_and_the_reached_maps() -> void:
	var maps: Array[String] = DailyTasks.reached_maps()
	var a: String = DailyBoard.pick_featured(_day(0), maps)
	assert_ne(a, "")
	assert_eq(DailyBoard.pick_featured(_day(0), maps), a, "same date, same Spirling")
	assert_true(a in DailyBoard.meetable(maps), "only kinds that live where the player has been")
	var seen: Dictionary = {}
	for i: int in 30:
		seen[DailyBoard.pick_featured(_day(i), maps)] = true
	assert_gt(seen.size(), 3, "it changes from day to day")
	var none: Array[String] = ["brindlewick"]
	assert_eq(DailyBoard.pick_featured(_day(0), none), "", "no wild kinds reached, no Spirling of the day")

func test_featured_stays_fixed_for_the_day() -> void:
	var day: String = DailyBoard.today()
	var sp: String = DailyBoard.featured(day)
	for m: String in ["gloamwood", "quillbrook", "brackwater_fen", "thornridge"]:
		DailyTasks.note_map(m)
	assert_eq(DailyBoard.featured(day), sp, "reaching a new place at noon does not change it")
	assert_true(DailyBoard.featured_line(day).contains(sp))
	assert_false(DailyBoard.featured_places(sp).is_empty(), "the card says where it lives")

func test_featured_raises_the_encounter_weight_on_its_tables() -> void:
	var table: String = "fernstair"
	var kinds: Array[String] = EncounterTable.species_on(table)
	var sp: String = kinds[kinds.size() - 1]
	var plain: Dictionary = DailyBoard.encounter_mults(table, MON, "")
	var with: Dictionary = DailyBoard.encounter_mults(table, MON, sp)
	assert_eq(int(with.get(sp, 1)), int(plain.get(sp, 1)) * DailyBoard.featured_mult())
	assert_gt(DailyBoard.featured_mult(), 1)
	assert_eq(DailyBoard.encounter_mults("crowcrest", MON, "NotAKind"), DailyBoard.encounter_mults("crowcrest", MON, ""), "a kind not on the table changes nothing")
	var n_plain: int = _count(table, sp, plain)
	var n_with: int = _count(table, sp, with)
	assert_gt(n_with, n_plain * 2, "it steps out clearly more often (%d vs %d)" % [n_with, n_plain])

func _count(table: String, sp: String, mults: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n: int = 0
	for i: int in 600:
		var w: Spirling = EncounterTable.roll(table, rng, [], "", {}, mults)
		if w != null and w.data.species_name == sp:
			n += 1
	return n

# --- Weekend weather ------------------------------------------------------------------------

func test_weekdays_of_the_date_keys() -> void:
	assert_eq(DailyBoard.weekday(SAT), 6)
	assert_eq(DailyBoard.weekday(SUN), 0)
	assert_eq(DailyBoard.weekday(MON), 1)
	assert_eq(DailyBoard.next_day(FRI), SAT)
	assert_true(DailyBoard.is_weekend(SAT) and DailyBoard.is_weekend(SUN))
	assert_false(DailyBoard.is_weekend(FRI) or DailyBoard.is_weekend(MON))

func test_weekend_events_only_on_saturday_and_sunday_and_the_same_both_days() -> void:
	var sat: Array[Dictionary] = DailyBoard.weekend_events(SAT)
	assert_eq(sat.size(), int(DailyBoard.data().weekend.per_weekend))
	assert_eq(DailyBoard.weekend_events(SUN), sat, "Sunday keeps Saturday's sky")
	assert_eq(DailyBoard.weekend_events(MON).size(), 0)
	assert_eq(DailyBoard.weekend_events(FRI).size(), 0)
	assert_ne(sat[0].id, sat[1].id)
	var ids: Dictionary = {}
	for w: int in 12:
		var d: String = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(SAT + "T12:00:00") + w * 7 * 86400)
		for e: Dictionary in DailyBoard.weekend_events(d):
			ids[e.id] = true
	assert_gt(ids.size(), 3, "the weekends take turns")

func test_weekend_events_are_valid() -> void:
	for e: Dictionary in DailyBoard.data().weekend.events:
		assert_has(WeatherCycle.KINDS, str(e.kind))
		assert_ne(str(e.kind), "clear")
		for m: Variant in e.maps:
			var md: MapData = MapData.load_map(str(m))
			assert_true(md.outdoor and not md.biome in ["cave", "dungeon"], "%s has a sky" % m)
			assert_true(str(m) in EncounterTable.table_ids(), "%s has wild Spirlings" % m)
		for sp: Variant in e.species:
			var sd: SpirlingData = Database.species(str(sp))
			assert_not_null(sd, str(sp))
			assert_ne(sd.rarity, "common", "%s is a rare kind" % sp)
			var lives: bool = false
			for m: Variant in e.maps:
				lives = lives or str(sp) in EncounterTable.species_on(str(m))
			assert_true(lives, "%s lives on a map of %s" % [sp, e.id])

func test_weekend_sky_and_rare_weight_on_its_maps() -> void:
	var e: Dictionary = DailyBoard.weekend_events(SAT)[0]
	var map_id: String = str(e.maps[0])
	var m: MapData = MapData.load_map(map_id)
	var noon: int = Time.get_unix_time_from_datetime_string(SAT + "T12:00:00") - int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	assert_eq(DailyBoard.local_day(noon), SAT)
	for h: int in 4:
		assert_eq(WeatherCycle.current(m, noon + h * 3 * 3600 - 6 * 3600, true), str(e.kind), "the weekend sky all day")
	assert_eq(WeatherCycle.current(m, noon, false), "clear", "the Weather switch still wins")
	var monday: int = noon + 2 * 86400
	assert_eq(WeatherCycle.current(m, monday, true), WeatherCycle.roll(m.region, m.biome, monday), "weekdays roll as before")
	var mults: Dictionary = DailyBoard.encounter_mults(map_id, SAT, "")
	for sp: Variant in e.species:
		if str(sp) in EncounterTable.species_on(map_id):
			assert_eq(int(mults.get(str(sp), 1)), int(WildRules.event_mults(map_id, SAT).get(str(sp), 1)) * int(e.mult))
	assert_eq(DailyBoard.weekend_mults(map_id, MON), {})

func test_weekend_lines_announce_without_clocks() -> void:
	assert_eq(DailyBoard.weekend_lines(SAT).size(), 2)
	assert_eq(DailyBoard.weekend_lines(FRI).size(), 2, "Friday tells what the weekend brings")
	assert_eq(DailyBoard.weekend_lines(MON).size(), 0)
	for l: String in DailyBoard.weekend_lines(SAT) + DailyBoard.weekend_lines(FRI):
		assert_false(l.to_lower().contains("hour") or l.to_lower().contains("left") or l.contains(":0"), "no countdown: %s" % l)

# --- The card -------------------------------------------------------------------------------

func test_card_due_once_a_day_after_the_starter() -> void:
	var day: String = DailyBoard.today()
	GameState.flags.erase("got_starter")
	assert_false(DailyBoard.card_due(day), "not before the starter")
	GameState.set_flag("got_starter")
	assert_true(DailyBoard.card_due(day))
	DailyBoard.mark_shown(day)
	assert_false(DailyBoard.card_due(day), "once a day")
	assert_true(DailyBoard.card_due(DailyBoard.next_day(day)), "the next day again")

func test_card_shows_gift_featured_tasks_and_takes_the_gift() -> void:
	GameState.set_flag("got_starter")
	var info: Dictionary = DailyBoard.card()
	assert_true(bool(info.gift_open))
	assert_eq(int(info.gift_step), 0)
	assert_ne(str(info.featured), "")
	assert_eq((info.tasks as Array).size(), DailyTasks.today().tasks.size())
	var c := DailyCard.new()
	c.info = info
	add_child_autofree(c)
	assert_gt(c.button.custom_minimum_size.y, 0.0)
	assert_eq(c.button.text, "Take the gift")
	c.button.pressed.emit()
	assert_true(c._done)
	assert_eq(DailyBoard.take_gift().size(), 1)
	assert_false(bool(DailyBoard.card().gift_open))
