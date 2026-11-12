extends GutTest
## Own ideas 200, batch 3: echo tower 100 floors and Warden echoes (1101, 1102), Master Rifts
## (1104), master tour (1105), Random Rift with rentals (1107, 1108), best times (1109), the
## Cartographer's exam (1110), weekly giant (1118) and released Spirlings (1136, 1137).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _rng(n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = n
	return r

func _win_rematches(n: int) -> void:
	var all: Array = WardenRematch.entries()
	for i: int in mini(n, all.size()):
		GameState.set_flag(WardenRematch.won_flag(all[i]))

func test_data_references_exist() -> void:
	for n: Variant in RandomRift.data().rental_pool:
		assert_true(Database.spirlings.has(str(n)), str(n))
	for n: Variant in FinalExam.data().team:
		assert_true(Database.spirlings.has(str(n)), str(n))
	for g: Variant in WeeklyGiant.data().giants:
		assert_true(Database.spirlings.has(str(g.species)), str(g.species))
		assert_true(BattleRules.BOSSES.has(str(g.boss)), str(g.boss))
	for id: Variant in RandomRift.data().rules:
		assert_true(BattleRules.RULES.has(str(id)), str(id))
	for id: Variant in RandomRift.data().fields:
		assert_true(BattleRules.FIELDS.has(str(id)), str(id))
	for e: Variant in WardenRematch.entries():
		for id: String in BattleRules.split_rules(MasterRifts.rule(e)):
			assert_true(BattleRules.RULES.has(id), id)
		assert_true(MasterRifts.data().hall_rules.has(str(e.warden)), str(e.warden))
	assert_true(Database.items.has(str(EchoTower.data().top_item)))

func test_echo_tower_floors_and_wardens() -> void:
	assert_eq(EchoTower.tower_floor(0), Gauntlet.FLOORS + 1)
	assert_eq(EchoTower.top_floor(), 100)
	assert_true(EchoTower.is_top(EchoTower.tower_floor(100 - Gauntlet.FLOORS - 1)))
	assert_false(EchoTower.is_warden_floor(9))
	assert_true(EchoTower.is_warden_floor(10))
	assert_eq(EchoTower.warden_entry(7), {})
	var first: Dictionary = EchoTower.warden_entry(10)
	assert_eq(str(first.warden), str(WardenRematch.entries()[0].warden))
	assert_eq(EchoTower.warden_entry(130), first, "the Wardens take turns")
	assert_ne(EchoTower.warden_entry(20), first)
	var team: Array[Spirling] = EchoTower.warden_team(40, 33, _rng(1))
	assert_eq(team.size(), int(EchoTower.data().warden_team))
	for s: Spirling in team:
		assert_eq(s.level, 33)
	assert_string_contains(EchoTower.warden_name(10), str(first.name))
	assert_ne(EchoTower.warden_line(10), "")

func test_echo_tower_top_pays_once() -> void:
	var before: int = GameState.waymarks
	assert_eq(EchoTower.pay_top(99), [])
	assert_gt(EchoTower.pay_top(100).size(), 1)
	assert_eq(GameState.waymarks, before + int(EchoTower.data().top_waymarks))
	assert_eq(EchoTower.pay_top(100), [], "only once")

func test_master_rifts() -> void:
	assert_eq(MasterRifts.open_entries().size(), 0)
	_win_rematches(3)
	assert_eq(MasterRifts.open_entries().size(), 3)
	var e: Dictionary = MasterRifts.open_entries()[0]
	var team: Array[Spirling] = MasterRifts.team(e, _rng(2))
	assert_eq(team.size(), (e.team as Array).size())
	assert_eq(team[0].level, mini(int(e.team[0].level) + int(MasterRifts.data().ring_bonus), Spirling.STORY_RING))
	assert_true(MasterRifts.rule(e).begins_with(str(MasterRifts.data().base_rule)))
	var before: int = GameState.waymarks
	assert_gt(MasterRifts.win(e).size(), 1)
	assert_eq(GameState.waymarks, before + int(MasterRifts.data().waymarks))
	assert_eq(MasterRifts.win(e).size(), 1, "Waymarks only the first time")
	assert_eq(MasterRifts.won_count(), 1)

func test_master_tour() -> void:
	assert_false(MasterTour.is_open())
	_win_rematches(MasterTour.steps() - 1)
	assert_false(MasterTour.is_open())
	_win_rematches(MasterTour.steps())
	assert_true(MasterTour.is_open())
	assert_eq(MasterTour.steps(), 12)
	assert_eq(MasterTour.team(0, _rng(3)).size(), int(MasterTour.data().team_size))
	assert_eq(MasterTour.entry(99), {})
	assert_eq(MasterTour.finish(5), [])
	assert_eq(MasterTour.best(), 5)
	assert_eq(MasterTour.finish(2), [])
	assert_eq(MasterTour.best(), 5, "best stays")
	var before: int = GameState.waymarks
	assert_gt(MasterTour.finish(12).size(), 0)
	assert_eq(GameState.waymarks, before + int(MasterTour.data().waymarks))
	assert_eq(MasterTour.finish(12), [], "clear pays once")

func test_random_rift_is_the_same_all_day() -> void:
	var a := RandomRift.new("2026-11-12")
	var b := RandomRift.new("2026-11-12")
	assert_eq(a.field, b.field)
	assert_eq(a.rule, b.rule)
	assert_eq(a.team(1)[0].data.species_name, b.team(1)[0].data.species_name)
	assert_eq(a.team(0).size(), int(RandomRift.data().team))
	var fields: Dictionary = {}
	for d: int in range(1, 29):
		fields[RandomRift.new("2026-02-%02d" % d).field] = true
	assert_gt(fields.size(), 1, "the hall changes from day to day")
	assert_ne(a.intro(), "")

func test_random_rift_rentals() -> void:
	var r := RandomRift.new("2026-11-12")
	var team: Array[Spirling] = r.rentals()
	assert_eq(team.size(), int(RandomRift.data().team))
	var names: Dictionary = {}
	for s: Spirling in team:
		assert_eq(s.level, r.ring)
		assert_true(s.data.species_name in RandomRift.data().rental_pool)
		names[s.data.species_name] = true
	assert_eq(names.size(), team.size(), "no rental twice")
	assert_eq(RandomRift.new("2026-11-12").rentals()[0].data.species_name, team[0].data.species_name)

func test_random_rift_pays_once_a_day() -> void:
	var r := RandomRift.new("2026-11-12")
	var before: int = GameState.waymarks
	assert_false(r.cleared())
	r.clear()
	assert_true(r.cleared())
	assert_eq(GameState.waymarks, before + int(RandomRift.data().waymarks))
	assert_eq(r.clear(), [])
	assert_false(RandomRift.new("2026-11-13").cleared())

func test_hall_times() -> void:
	assert_eq(HallTimes.best("exam"), 0)
	assert_true(HallTimes.submit("exam", 300))
	assert_false(HallTimes.submit("exam", 301))
	assert_true(HallTimes.submit("exam", 125))
	assert_false(HallTimes.submit("exam", 0))
	assert_false(HallTimes.submit("", 10))
	assert_eq(HallTimes.best("exam"), 125)
	assert_eq(HallTimes.fmt(125), "2:05")
	HallTimes.submit("tour", 61)
	assert_eq(HallTimes.lines({"exam": "Exam"}), ["Exam  2:05", "tour  1:01"] as Array[String])

func test_final_exam() -> void:
	assert_false(FinalExam.is_open())
	for e: Variant in WardenRematch.entries():
		GameState.set_flag(MasterRifts.won_flag(e))
	assert_true(FinalExam.is_open())
	var team: Array[Spirling] = FinalExam.team(_rng(4))
	assert_eq(team.size(), 6)
	assert_eq(team[0].level, mini(int(FinalExam.data().ring), Spirling.STORY_RING))
	assert_eq(FinalExam.lines("intro").size(), 2)
	var before: int = GameState.waymarks
	FinalExam.pass_exam()
	assert_true(FinalExam.passed())
	assert_eq(GameState.waymarks, before + int(FinalExam.data().waymarks))
	FinalExam.pass_exam()
	assert_eq(GameState.waymarks, before + int(FinalExam.data().waymarks), "paid once")

func test_weekly_giant() -> void:
	assert_eq(WeeklyGiant.giant("2026-W46"), WeeklyGiant.giant("2026-W46"))
	assert_eq(WeeklyGiant.foe("2026-W46", _rng(5)).size(), 1)
	assert_eq(WeeklyGiant.share_pct(200, 150), 25)
	assert_eq(WeeklyGiant.share_pct(200, -5), 100)
	assert_eq(WeeklyGiant.share_pct(0, 0), 0)
	var before: int = GameState.waymarks
	assert_eq(WeeklyGiant.submit("2026-W46", 10), [])
	assert_eq(WeeklyGiant.submit("2026-W46", 60).size() > 0, true)
	var tiers: Array = WeeklyGiant.data().tiers
	assert_eq(GameState.waymarks, before + int(tiers[0].waymarks) + int(tiers[1].waymarks))
	assert_eq(WeeklyGiant.submit("2026-W46", 55), [], "tiers pay once a week")
	assert_eq(int(WeeklyGiant.record("2026-W46").best), 60)
	assert_eq(int(WeeklyGiant.record("2026-W47").best), 0, "a new week starts fresh")
	WeeklyGiant.submit("2026-W47", 100)
	assert_eq(int(WeeklyGiant.record("2026-W47").paid), tiers.size())

func test_release_letter_and_sightings() -> void:
	var s := Spirling.new(Database.spirlings["Puddlet"], 5, _rng(6))
	s.origin_map = "saltmarsh"
	GameState.storage.append(s)
	var line: String = GameState.release(GameState.storage.size() - 1)
	assert_ne(line, "")
	assert_eq(Released.list().size(), 1)
	var letter: Array[String] = Released.letter(s)
	assert_eq(letter.size(), 2)
	assert_string_contains(letter[0], s.display_name())
	s.origin_map = ""
	assert_string_contains(Released.letter(s)[0], s.display_name())
	var seen: Array[String] = []
	var r := _rng(7)
	for i: int in 40:
		seen.append_array(Released.sightings("saltmarsh", "2026-11-12", r))
	assert_eq(seen.size(), 1, "at most once a day")
	assert_eq(Released.sightings("fernstair", "2026-11-13", r), [])
	for i: int in 60:
		Released.remember(s)
	assert_eq(Released.list().size(), int(Released.data().max))

func test_hollis_is_wired() -> void:
	var d: Dictionary = GameState.as_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/map_house.json")))
	assert_eq(str(d.hollis.action), "postgame_board")
