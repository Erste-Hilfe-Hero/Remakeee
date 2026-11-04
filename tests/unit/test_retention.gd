extends GutTest
## Weekly challenge (88), seasonal festivals (89), local achievements (90) and screen reader text (77).

var _saved: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_saved = GameState.to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Juno", 0, "Kindlop")

func after_each() -> void:
	GameState.from_dict(_saved)

func _unix(y: int, m: int, d: int) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})

func test_iso_week_keys() -> void:
	assert_eq(WeeklyChallenge.week_key(_unix(2026, 1, 1)), "2026-W01", "Thursday 1 Jan")
	assert_eq(WeeklyChallenge.week_key(_unix(2024, 12, 30)), "2025-W01", "Monday belongs to next ISO year")
	assert_eq(WeeklyChallenge.week_key(_unix(2021, 1, 3)), "2020-W53", "Sunday belongs to last ISO year")
	assert_eq(WeeklyChallenge.week_key(_unix(2026, 11, 1)), "2026-W44")
	assert_eq(WeeklyChallenge.week_key(_unix(2026, 11, 2)), "2026-W45", "weeks start on Monday")

func _names(team: Array[Spirling]) -> Array[String]:
	var out: Array[String] = []
	for s: Spirling in team:
		out.append("%s/%d/%d" % [s.data.species_name, s.level, s.max_hp()])
	return out

func test_weekly_is_the_same_for_everyone_in_a_week() -> void:
	var a := WeeklyChallenge.new("2026-W44", 20)
	var b := WeeklyChallenge.new("2026-W44", 20)
	assert_eq(a.field, b.field)
	assert_eq(a.rule, b.rule)
	for i: int in WeeklyChallenge.ROUNDS:
		assert_eq(_names(a.team(i)), _names(b.team(i)))
		assert_eq(a.team(i).size(), WeeklyChallenge.TEAM_SIZE)
	assert_true(BattleRules.FIELDS.has(a.field))
	assert_true(BattleRules.RULES.has(a.rule))

func test_weekly_changes_between_weeks() -> void:
	var seen: Dictionary = {}
	for w: int in range(1, 9):
		var c := WeeklyChallenge.new("2026-W%02d" % w, 20)
		seen[str(_names(c.team(0)))] = true
	assert_gt(seen.size(), 4)

func test_weekly_level_follows_the_team() -> void:
	assert_eq(WeeklyChallenge.new("2026-W44", 20).level, 22)
	assert_eq(WeeklyChallenge.new("2026-W44", 1).level, 8)
	for s: Spirling in WeeklyChallenge.new("2026-W44", 40).team(1):
		assert_eq(s.level, 42)

func test_festivals_cover_their_months() -> void:
	assert_eq(Season.for_month(10).id, "lantern_nights")
	assert_eq(Season.for_month(1).id, "hearth_weeks")
	assert_true(Season.for_month(3).is_empty())
	assert_eq(Season.next_after(3).id, "bloom_fair")
	assert_eq(Season.next_after(11).id, "hearth_weeks")
	assert_eq(Season.festival_year(1, 2027), 2026, "Hearth Weeks over New Year count as one festival")
	assert_ne(Season.gift_flag(Season.for_month(10), 2026), Season.gift_flag(Season.for_month(10), 2027))
	for f: Dictionary in Season.FESTIVALS:
		assert_true(Database.items.has(str(f.gift)), str(f.gift))

func test_festival_boosts_encounter_weight() -> void:
	var spawn: Dictionary = {"species": "Kindlop", "weight": 10}
	assert_eq(EncounterTable.weight_of(spawn, []), 10)
	assert_eq(EncounterTable.weight_of(spawn, [Elements.E.EMBER] as Array[int]), 30)
	assert_eq(EncounterTable.weight_of(spawn, [Elements.E.TIDE] as Array[int]), 20)

func test_achievements_unlock_from_state() -> void:
	assert_eq(Achievements.check(), [] as Array[String])
	GameState.set_flag("rift_cinder_sealed")
	var fresh: Array[String] = Achievements.check()
	assert_eq(fresh, ["Mender"] as Array[String])
	assert_eq(Achievements.check(), [] as Array[String], "only announced once")
	GameState.set_flag("rift_tide_sealed")
	GameState.money = 12000
	fresh = Achievements.check()
	assert_has(fresh, "Quiet Valley")
	assert_has(fresh, "Full Purse")
	GameState.money = 0
	assert_true(Achievements.unlocked().has("rich"), "earned achievements stay")

func test_achievements_for_bonds_and_prism() -> void:
	var p := Spirling.new(Database.species("Puddlet"), 5)
	p.prism = true
	GameState.receive_spirling(p)
	var fresh: Array[String] = Achievements.check()
	assert_has(fresh, "First Bond")
	assert_has(fresh, "Odd Colours")

func test_every_achievement_has_a_check() -> void:
	var ids: Dictionary = {}
	for a: Dictionary in Achievements.LIST:
		assert_false(ids.has(a.id), "duplicate " + str(a.id))
		ids[a.id] = true
	assert_eq(Achievements.lines().size(), Achievements.LIST.size())
	# Every id is handled by earned(): a fully set-up save earns each of them.
	for f: String in QuestLog.all_flags():
		GameState.set_flag(f)
	for f: String in ["rift_cinder_sealed", "rift_tide_sealed", "hollow_lamps", "gauntlet_clear"]:
		GameState.set_flag(f)
	GameState.records["weekly_wins"] = 1
	GameState.records["rematch_wins"] = 5
	GameState.iron_oath = true
	GameState.money = 10000
	GameState.party.clear()
	for sd: SpirlingData in Database.spirlings.values():
		GameState.mark_seen(sd.species_name, true)
	for n: String in ["Calderox", "Puddlet", "Mossling", "Zippit", "Zephlet", "Kelpup"]:
		var s := Spirling.new(Database.species(n), 30)
		GameState.party.append(s)
	GameState.party[1].prism = true
	Achievements.check()
	for a: Dictionary in Achievements.LIST:
		assert_true(Achievements.unlocked().has(a.id), "never earned: " + str(a.id))

func test_side_goals_done() -> void:
	assert_false(QuestLog.side_goals_done(GameState.flags))
	for g: Variant in QuestLog.data().get("side", []):
		GameState.set_flag(str((g as Dictionary).done))
	assert_true(QuestLog.side_goals_done(GameState.flags))

func test_records_text() -> void:
	GameState.records["gauntlet_best"] = 3
	GameState.records["weekly"] = {"week": WeeklyChallenge.this_week(), "best": 2, "claimed": false}
	var t: String = PauseMenu.records_text()
	assert_string_contains(t, "Lighthouse climb best: 3 of 5")
	assert_string_contains(t, "This week: 2 of 3")

func test_info_strip_speaks() -> void:
	var strip := InfoStrip.new()
	add_child_autofree(strip)
	var s := Spirling.new(Database.species("Kindlop"), 9)
	s.status = "scorch"
	strip.set_spirling(s)
	var t: String = strip.screen_reader_text()
	assert_string_contains(t, "Kindlop ring 9, Vigor")
	assert_string_contains(t, StatusRules.label("scorch"))

func test_new_npcs_are_placed() -> void:
	var m: MapData = MapData.load_map("brindlewick")
	var ids: Array[String] = []
	for n: Dictionary in m.npcs:
		ids.append(str(n.id))
	assert_has(ids, "crier")
	assert_has(ids, "wynn")
