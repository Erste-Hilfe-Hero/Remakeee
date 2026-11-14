extends GutTest
## Plan area 8, P2 batch: secret badges, badge book percent and new achievements
## (plan 3319-3323, 3326, 3328, 3334).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_secret_badges_hide_until_earned() -> void:
	var secrets: Array = Achievements.list().filter(func(a: Dictionary) -> bool: return bool(a.get("secret", false)))
	assert_between(secrets.size(), 1, Achievements.MAX_SECRET)
	var a: Dictionary = Achievements.find("no_miss")
	assert_true(Achievements.is_hidden(a))
	assert_false(Achievements.card(a).contains(str(a.title)), "title hidden")
	assert_false(Achievements.card(a).contains(str(a.text)), "text hidden")
	assert_true(Achievements.lines().has("[ ] ???"))
	GameState.records["melody_perfect"] = 1
	Achievements.check()
	assert_false(Achievements.is_hidden(a))
	assert_string_contains(Achievements.card(a), str(a.title))

func test_percent() -> void:
	assert_eq(Achievements.percent(), Achievements.unlocked().size() * 100 / Achievements.list().size())
	GameState.records["achievements"] = {}
	assert_eq(Achievements.percent(), 0)

func test_night_wins_count() -> void:
	DailyTasks.record("win", {"map": "fernstair", "wild": true, "night": true})
	DailyTasks.record("win", {"map": "fernstair", "wild": true, "night": false})
	assert_eq(Achievements.stat("count_win_night"), 1)

func test_every_field_and_every_wild_map() -> void:
	assert_eq(Achievements.stat("all_fields"), 0)
	GameState.records["fields_won"] = BattleRules.FIELDS.keys().slice(1)
	assert_eq(Achievements.stat("all_fields"), 0)
	GameState.records["fields_won"] = BattleRules.FIELDS.keys()
	assert_eq(Achievements.stat("all_fields"), 1)
	assert_eq(Achievements.stat("wild_maps_all"), 0)
	for m: String in EncounterTable.table_ids():
		DailyTasks.note_map(m)
	assert_eq(Achievements.stat("wild_maps_all"), 1)

func test_team_at_cap_and_host() -> void:
	GameState.party[0].level = Spirling.STORY_RING
	assert_eq(Achievements.stat("team_at_cap"), 1)
	for i: int in 3:
		DailyTasks.record("daily_find", {"map": "fernstair"})
	assert_eq(Achievements.stat("count_daily_find"), 3)
