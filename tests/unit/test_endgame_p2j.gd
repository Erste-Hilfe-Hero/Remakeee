extends GutTest
## Plan area 8, P2 batch: new badges (plan 3324, 3325, 3327, 3329, 3330), badge book filter
## (3333) and a check that every badge has a known stat (3337).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_every_badge_has_a_known_stat() -> void:
	for a: Dictionary in Achievements.list():
		assert_true(Achievements.known_stat(str(a.stat)), "%s: %s" % [a.id, a.stat])
		assert_true(int(a.get("reward", 0)) in Achievements.REWARDS, str(a.id))
		assert_true(str(a.get("cat", "")) in Achievements.CATEGORIES, str(a.id))

func test_one_element_win() -> void:
	assert_false(Achievements.one_element_team(GameState.party), "one Spirling is no team of five")
	var sd: SpirlingData = GameState.party[0].data
	var team: Array[Spirling] = []
	for i: int in GameState.MAX_PARTY:
		team.append(Spirling.new(sd, 10))
	assert_true(Achievements.one_element_team(team))
	DailyTasks.record("win", {"map": "fernstair", "wild": true, "one_element": true})
	assert_true(Achievements.earned("one_element"))

func test_keepsake_collector_skips_shop_mementos() -> void:
	var ks: Array[String] = Achievements.keepsakes()
	assert_gt(ks.size(), 0)
	for id: String in ks:
		assert_false(bool(Database.item(id).get("shop", false)), id)
	assert_false(Achievements.earned("keepsakes_all"))
	for id: String in ks:
		GameState.add_item(id)
		GameState.inventory[id] = 0
	assert_eq(Achievements.stat("keepsakes"), ks.size(), "owned once is enough")
	assert_true(Achievements.earned("keepsakes_all"))

func test_photographer_and_festivals() -> void:
	GameState.records["photos"] = 25
	assert_true(Achievements.earned("photos_25"))
	assert_eq(int(Achievements.find("festival_4").n), Season.festivals().size(), "Every Season means every festival")

func test_tower_top_and_echo_climber() -> void:
	assert_eq(int(Achievements.find("tower").n), Gauntlet.FLOORS)
	assert_eq(str(Achievements.find("tower").title), "Tower Top")
	var five: Dictionary = Achievements.find("tower_5")
	assert_eq(str(five.title), "Echo Climber")
	assert_eq(int(five.n), 5)

func test_badge_book_filters_by_category() -> void:
	var book := BadgeBook.new()
	add_child_autofree(book)
	await get_tree().process_frame
	book.next_category()
	assert_eq(book.category, Achievements.CATEGORIES[0])
	await get_tree().process_frame
	assert_eq(book._grid.get_child_count(), Achievements.indices_for(book.category).size())
	assert_lt(book._grid.get_child_count(), Achievements.list().size())
	for i: int in Achievements.CATEGORIES.size():
		book.next_category()
	assert_eq(book.category, "", "back to every badge")
