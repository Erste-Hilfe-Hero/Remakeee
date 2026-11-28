extends GutTest
## Plan area 8: achievements from data, Waymark rewards, steps, badges and the badge book.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func test_eighty_plus_in_six_categories_with_valid_rewards() -> void:
	var list: Array[Dictionary] = Achievements.list()
	assert_gte(list.size(), 80)
	var per_cat: Dictionary = {}
	for a: Dictionary in list:
		assert_true(str(a.cat) in Achievements.CATEGORIES, str(a.id))
		assert_true(int(a.reward) in Achievements.REWARDS, "%s reward" % a.id)
		assert_gte(int(a.get("n", 1)), 1)
		assert_true(str(a.title) != "" and str(a.text) != "")
		per_cat[a.cat] = int(per_cat.get(a.cat, 0)) + 1
		Achievements.stat(str(a.stat))
	assert_eq(per_cat.size(), 6)
	assert_eq(get_logger().get_warnings().filter(func(w: Variant) -> bool: return str(w).contains("unknown stat")).size(), 0, "every stat is known")

func test_kindred_has_three_steps() -> void:
	var tiers: Dictionary = {}
	for a: Dictionary in Achievements.list():
		if str(a.get("group", "")) == "kindred":
			tiers[a.tier] = int(a.n)
	assert_eq(tiers, {"bronze": 10, "silver": 15, "gold": 21})

func test_rewards_paid_once_also_for_old_unlocks() -> void:
	# An old save: achievements unlocked before rewards existed.
	GameState.records["achievements"] = {"first_rift": "2026-11-01", "rich": "2026-11-02"}
	Achievements.check()
	assert_eq(GameState.waymarks, 25 + 25, "old unlocks pay their reward once")
	Achievements.check()
	assert_eq(GameState.waymarks, 50, "never twice")
	assert_true(Achievements.unlocked().has("rich"), "unlock dates stay")
	assert_eq(str(Achievements.unlocked()["rich"]), "2026-11-02")

func test_new_unlock_pays_reward() -> void:
	GameState.set_flag("rift_cinder_sealed")
	assert_eq(Achievements.check(), ["Mender"] as Array[String])
	assert_eq(GameState.waymarks, int(Achievements.find("first_rift").reward))

func test_progress_and_card() -> void:
	GameState.records["count_step"] = 250
	var a: Dictionary = Achievements.find("steps_1000")
	assert_eq(Achievements.progress(a), [250, 1000] as Array[int])
	assert_eq(Achievements.progress(Achievements.find("first_rift")), [] as Array[int], "no count, no k/n")
	var card: String = Achievements.card(a)
	assert_string_contains(card, "Progress: 250/1000")
	assert_string_contains(card, "Reward: 10 Waymarks")

func test_counters_come_from_game_events() -> void:
	DailyTasks.record("win", {"map": "fernstair", "wild": true})
	DailyTasks.record("win", {"map": "fernstair", "wild": false})
	DailyTasks.record("step", {}, 7)
	assert_eq(Achievements.stat("count_win"), 2)
	assert_eq(Achievements.stat("count_win_wild"), 1)
	assert_eq(Achievements.stat("count_win_tamer"), 1)
	assert_eq(Achievements.stat("count_step"), 7)

func test_starter_line_and_element_sets() -> void:
	GameState.party[0].level = 31
	assert_eq(Achievements.stat("starter_level"), 31)
	assert_eq(Achievements.stat("element_bonded:EMBER"), 0)
	for sd: SpirlingData in Database.spirlings.values():
		if Elements.E.EMBER in sd.elements:
			GameState.mark_seen(sd.species_name, true)
	assert_eq(Achievements.stat("element_bonded:EMBER"), 1)

func test_badges_are_16px_and_locked_ones_grey() -> void:
	var a: Dictionary = Achievements.find("bonded_21")
	var on: Image = Badges.image(a, true)
	var off: Image = Badges.image(a, false)
	assert_eq(on.get_size(), Vector2i(16, 16))
	var px: Color = off.get_pixel(8, 1)
	assert_almost_eq(px.r, px.g, 0.01, "locked rim is grey")
	assert_ne(on.get_pixel(8, 1), off.get_pixel(8, 1))
	for c: String in Achievements.CATEGORIES:
		assert_true(Badges.MOTIFS.has(c), c)

func test_badge_book_builds_a_grid() -> void:
	var book := BadgeBook.new()
	add_child_autofree(book)
	await get_tree().process_frame
	assert_eq(book._grid.get_child_count(), Achievements.list().size())
