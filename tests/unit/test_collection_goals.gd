extends GutTest
## Collection goals per region, the sliding series and their rewards (plan area 1, items 408-412).

var _saved: Dictionary

func before_each() -> void:
	_saved = GameState.to_dict()
	Database.load_all()
	GameState.reset()

func after_each() -> void:
	GameState.from_dict(_saved)

func _total() -> int:
	return SpirlogBook.visible_kinds(GameState.flags).size()

func test_series_slides_up_to_every_kind() -> void:
	var steps: Array[int] = []
	for g: Dictionary in Collection.GOALS:
		if str(g.get("region", "")).is_empty():
			steps.append(int(g.bonded))
	assert_eq(steps, [3, 5, 8, 12, 16, 20, 25, 30, -1] as Array[int])
	for g: Dictionary in Collection.GOALS:
		assert_ne(g.id, "kinds_11", "the old goal is gone")

func test_veydal_has_its_own_goals() -> void:
	var steps: Array[int] = []
	for g: Dictionary in Collection.GOALS:
		if str(g.get("region", "")) == "veydal":
			steps.append(int(g.bonded))
	assert_eq(steps, [10, 20, 30, -1] as Array[int])
	assert_eq(Collection.region_total("veydal"), 40)

func test_rewards_are_only_game_items_coins_or_titles() -> void:
	for g: Dictionary in Collection.GOALS:
		var kinds: int = 0
		if not str(g.get("item", "")).is_empty():
			kinds += 1
			assert_false(Database.item(str(g.item)).is_empty(), "%s: item exists in the game" % g.id)
			assert_false(str(g.item).begins_with("rg_"), "%s: never a shop product" % g.id)
		if int(g.get("money", 0)) > 0:
			kinds += 1
		if g.has("title"):
			kinds += 1
		assert_gt(kinds, 0, "%s pays something" % g.id)
		for k: String in g:
			assert_true(k in ["id", "bonded", "region", "item", "count", "money", "title", "label"], "%s: unknown reward '%s'" % [g.id, k])

func test_region_goal_counts_only_that_region_and_gives_a_title() -> void:
	var n: int = 0
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region == "veydal" and n < 10:
			GameState.mark_seen(sd.species_name, true)
			n += 1
	var lines: Array[String] = Collection.claim()
	assert_true(Collection.titles().has("Veydal Wanderer"))
	assert_true(lines.any(func(l: String) -> bool: return l.contains("Veydal Wanderer")))
	assert_true(Collection.claim().is_empty(), "paid once")

func test_goals_menu_names_the_nearest_goal_with_what_is_left() -> void:
	for sname: String in ["Kindlop", "Wickit"]:
		GameState.mark_seen(sname, true)
	assert_eq(Collection.next_text(GameState.spirlog, _total()), "1 more kinds until the gift for 3 kinds.")
	for sd: SpirlingData in Database.spirlings.values():
		GameState.mark_seen(sd.species_name, true)
	assert_eq(Collection.next_text(GameState.spirlog, _total()), "")

func test_goals_text_shows_the_next_goal() -> void:
	assert_string_contains(PauseMenu.goals_text(), "more kinds until")

func test_every_veydal_goal_is_reachable_offline_in_act_one() -> void:
	# Offline Act I content: wild encounter tables on the Veydal maps plus unfolding. No starter
	# counted (only one is chosen), no online meetings, no shop.
	var reach: Dictionary = {}
	for table: Variant in (JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json")) as Dictionary).values():
		for sp: Variant in (table as Dictionary).get("spawns", []):
			reach[str(sp.species)] = true
	var grew: bool = true
	while grew:
		grew = false
		for n: String in reach.keys():
			var sd: SpirlingData = Database.species(n)
			if sd == null:
				continue
			for p: Dictionary in sd.unfold:
				var to: String = (p.to as SpirlingData).species_name
				if not reach.has(to):
					reach[to] = true
					grew = true
	var veydal: int = 0
	for n: String in reach:
		if Database.species(n) != null and Database.species(n).region == "veydal":
			veydal += 1
	for g: Dictionary in Collection.GOALS:
		if str(g.get("region", "")) == "veydal" or str(g.get("region", "")).is_empty():
			assert_lte(Collection.goal_need(g, _total()), veydal, "%s can be reached offline" % g.id)
