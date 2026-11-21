extends GutTest
## Plan area 8, P2 batch: roaming trip places, finds, element bonus, growth and diary
## (plan 3449-3455).

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	Online.clock_offset = 0
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _stored(species: String, level: int = 10) -> Spirling:
	var s := Spirling.new(Database.species(species), level)
	if s.uid == "":
		s.uid = "trip-%d" % GameState.storage.size()
	GameState.storage.append(s)
	return s

func _back(i: int = 0) -> void:
	var list: Array = GameState.records["expeditions"]
	list[i]["start"] = Online.unix_now() - 13 * 3600

func test_only_known_wild_maps() -> void:
	assert_true(Expeditions.destinations().is_empty())
	GameState.records["maps_visited"] = ["lighthouse", "fernstair", "nowhere"]
	assert_eq(Expeditions.destinations(), ["fernstair"] as Array[String], "towns and unknown ids are no target")
	var s: Spirling = _stored("Kindlop")
	assert_false(Expeditions.send(s, 4, "saltmarsh"), "not visited yet")
	assert_true(Expeditions.send(s, 4, "fernstair"))

func test_finds_come_from_the_map() -> void:
	var f: Array[String] = Expeditions.finds("fernstair")
	assert_gt(f.size(), 0)
	for id: String in f:
		assert_lte(int(Database.item(id).get("price", 0)), Expeditions.find_max_price(), id)
		assert_false(Database.item(id).has("held"), id)
	GameState.records["maps_visited"] = ["fernstair"]
	var s: Spirling = _stored("Kindlop")
	Expeditions.send(s, 4, "fernstair")
	_back()
	var item: String = Expeditions.find_for(Expeditions.trips()[0])
	assert_true(item in f)
	var before: int = int(GameState.inventory.get(item, 0))
	Expeditions.collect()
	assert_eq(int(GameState.inventory.get(item, 0)), before + 1)

func test_element_bonus_on_coins() -> void:
	var map_id: String = ""
	var kind: String = ""
	for id: String in ["fernstair", "saltmarsh", "gloamwood", "crowcrest", "greyreach"]:
		for sp: String in EncounterTable.species_on(MapData.load_map(id).encounter_table):
			map_id = id
			kind = sp
			break
		if kind != "":
			break
	GameState.records["maps_visited"] = [map_id]
	var s: Spirling = _stored(kind)
	assert_true(Expeditions.element_match(s, map_id))
	var p: Dictionary = Expeditions.plan_for(4)
	assert_eq(Expeditions.coins_for(s, p, map_id), int(p.coins) * (100 + Expeditions.match_bonus_pct()) / 100)
	assert_eq(Expeditions.coins_for(s, p, ""), int(p.coins), "no map, no bonus")
	Expeditions.send(s, 4, map_id)
	_back()
	var money: int = GameState.money
	Expeditions.collect()
	assert_eq(GameState.money, money + Expeditions.coins_for(s, p, map_id))

func test_growth_per_hour_up_to_the_cap() -> void:
	var s: Spirling = _stored("Kindlop", 10)
	var four: int = Expeditions.xp_for(s, 4)
	assert_eq(Expeditions.xp_for(s, 12), four * 3)
	assert_eq(four, int(float(s.data.xp_yield) * 10.0 / BattleModel.XP_LEVEL_DIV * 0.25 * 4))
	var hp: int = s.hp
	Expeditions.send(s, 12)
	_back()
	var xp: int = s.xp
	Expeditions.collect()
	assert_gt(s.xp, xp)
	assert_gte(s.hp, hp, "a trip never costs Vigor")
	var capped: Spirling = _stored("Kindlop", GameState.progress_cap())
	assert_eq(Expeditions.grow(capped, 999999), 0, "no growth over the ring cap")
	assert_eq(capped.level, GameState.progress_cap())

func test_trips_never_fail_and_sanctuary_stays() -> void:
	var s: Spirling = _stored("Kindlop")
	var safe := Spirling.new(Database.species("Kindlop"), 10)
	safe.uid = "sanct"
	GameState.sanctuary.append(safe)
	assert_false(Expeditions.send(safe, 4), "Iron Oath sanctuary Spirlings never go")
	assert_false(safe in Expeditions.ready_to_go())
	Expeditions.send(s, 4)
	_back()
	var lines: Array[String] = Expeditions.collect()
	assert_gt(lines.size(), 0)
	assert_eq(Expeditions.trips().size(), 0)

func test_diary_lines() -> void:
	GameState.records["maps_visited"] = ["fernstair"]
	for i: int in Expeditions.LOG_SIZE + 2:
		var s: Spirling = _stored("Kindlop")
		GameState.records["expeditions"] = []
		Expeditions.send(s, 4, "fernstair")
		_back()
		Expeditions.collect()
	var d: Array[String] = Expeditions.diary()
	assert_eq(d.size(), Expeditions.LOG_SIZE)
	assert_string_contains(d[0], Spirling.place_name("fernstair"))

func test_data_in_endgame_json() -> void:
	var d: Dictionary = Expeditions.data()
	for k: String in ["max", "plans", "match_bonus_pct", "xp_per_hour", "find_max_price"]:
		assert_true(d.has(k), k)
