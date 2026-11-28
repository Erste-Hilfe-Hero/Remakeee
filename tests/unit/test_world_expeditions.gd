extends GutTest
## Plan area 8: world events, the wandering merchant and roaming trips.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	WorldEvents.force_spot = -1

func after_each() -> void:
	WorldEvents.force_spot = -1

func test_events_are_valid_and_same_for_everyone() -> void:
	assert_gte(WorldEvents.events().size(), 6)
	for e: Dictionary in WorldEvents.events():
		assert_true(MapData.exists(str(e.map)), str(e.map))
		assert_true(Database.items.has(str(e.item)), str(e.item))
		assert_ne(str(e.get("found", "")), "")
	for day: int in range(1, 29):
		var key: String = "2026-11-%02d" % day
		assert_eq(WorldEvents.event_for(key), WorldEvents.event_for(key))
		assert_eq(WorldEvents.merchant_for(key), WorldEvents.merchant_for(key))

func test_merchant_moves_every_day_and_sells_three() -> void:
	var prev: String = ""
	for day: int in range(1, 61):
		var key: String = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2026-11-01T12:00:00") + day * 86400)
		var m: Dictionary = WorldEvents.merchant_for(key)
		assert_ne(str(m.map), prev, "a different place than yesterday (%s)" % key)
		prev = str(m.map)
		assert_eq((m.items as Array).size(), 3)
		for id: Variant in m.items:
			assert_gt(int(Database.item(str(id)).get("price", 0)), 0, "sold for coins: %s" % id)
	assert_eq(WorldEvents.previous_day("2026-03-01"), "2026-02-28")

func test_merchant_spots_are_free_and_reachable() -> void:
	var spots: Array = WorldEvents.merchant_data().spots
	for i: int in spots.size():
		WorldEvents.force_spot = i
		var sp: Dictionary = spots[i]
		var map: MapData = MapData.load_map(str(sp.map))
		var cell := Vector2i(int(sp.x), int(sp.y))
		assert_true(map.is_walkable(cell))
		var here: int = 0
		for n: Dictionary in map.npcs:
			if Vector2i(int(n.x), int(n.y)) == cell:
				here += 1
		assert_eq(here, 1, "the merchant stands alone at %s" % sp.map)
		for e: String in WorldValidator.validate():
			assert_false(e.contains(WorldEvents.MERCHANT_ID), e)

func test_event_find_once_per_day() -> void:
	var e: Dictionary = WorldEvents.today()
	var before: int = GameState.item_count(str(e.item))
	assert_eq(WorldEvents.on_visit("nowhere"), [] as Array[String])
	var lines: Array[String] = WorldEvents.on_visit(str(e.map))
	assert_eq(lines.size(), 2)
	assert_eq(GameState.item_count(str(e.item)), before + int(e.get("count", 1)))
	assert_eq(WorldEvents.on_visit(str(e.map)), [] as Array[String], "only once a day")
	assert_string_contains("\n".join(WorldEvents.lines()), "[x]")
	assert_string_contains(PauseMenu.goals_text(), "Wandering merchant today")

func _storage_spirling() -> Spirling:
	var s := Spirling.new(Database.species("Kindlop"), 10)
	if s.uid == "":
		s.uid = "test-%d" % GameState.storage.size()
	GameState.storage.append(s)
	return s

func test_trip_rewards_and_limits() -> void:
	assert_eq(Expeditions.plans().size(), 3)
	for h: int in [4, 8, 12]:
		var p: Dictionary = Expeditions.plan_for(h)
		assert_eq(int(p.waymarks), {4: 1, 8: 1, 12: 2}[h], "1, 1 or 2 Waymarks (docs/BALANCE.md, 90-day run)")
		assert_true(Database.items.has(str(p.item)))
		assert_string_contains(Expeditions.plan_text(p), "%d h" % h)
	var team: Array[Spirling] = []
	for i: int in 4:
		team.append(_storage_spirling())
	for i: int in 3:
		assert_true(Expeditions.send(team[i], 4))
	assert_false(Expeditions.send(team[3], 4), "three trips at most")
	assert_false(Expeditions.send(team[0], 8), "already away")
	assert_false(Expeditions.can_send())
	# Away Spirlings cannot be called back.
	var idx: int = GameState.storage.find(team[0])
	assert_false(GameState.withdraw(idx))
	assert_eq(Expeditions.collect(), [] as Array[String], "not back yet")
	var list: Array = GameState.records["expeditions"]
	list[0]["start"] = Online.unix_now() - 5 * 3600
	var money: int = GameState.money
	var lines: Array[String] = Expeditions.collect()
	assert_gt(lines.size(), 0)
	assert_eq(GameState.money, money + int(Expeditions.plan_for(4).coins))
	assert_eq(GameState.waymarks, int(Expeditions.plan_for(4).waymarks))
	assert_eq(Expeditions.trips().size(), 2)
	assert_eq(Expeditions.collect(), [] as Array[String], "paid once")
	assert_true(GameState.withdraw(GameState.storage.find(team[0])), "home again")

func test_damaged_trip_state_is_ignored() -> void:
	GameState.records["expeditions"] = "broken"
	assert_eq(Expeditions.trips().size(), 0)
	GameState.records["expeditions"] = [{"uid": "x", "hours": 5, "start": 0}, 7]
	assert_eq(Expeditions.trips().size(), 0)
	assert_eq(Expeditions.collect(), [] as Array[String])

func test_aldo_offers_trips_after_act_one() -> void:
	var m: MapData = MapData.load_map("lighthouse")
	var shown: Array[String] = []
	GameState.set_flag("kestra_dock_talk")
	GameState.set_flag("aldo_dock_told")
	for n: Dictionary in m.npcs:
		if n.has("hide_flag") and GameState.has_flag(str(n.hide_flag)):
			continue
		if n.has("show_flag") and not GameState.has_flag(str(n.show_flag)):
			continue
		if Vector2i(int(n.x), int(n.y)) == Vector2i(2, 3):
			shown.append(str(n.id))
	assert_eq(shown, ["aldo_post"] as Array[String])
	assert_eq(str(Dialogue.get_entry("lighthouse/aldo_post").action), "expedition")
