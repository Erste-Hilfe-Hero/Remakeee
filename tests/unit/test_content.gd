extends GutTest
## Content: every Spirling has art and can be met in the world, and dex numbers are unique.

func before_all() -> void:
	Database.load_all()

func test_every_species_has_art() -> void:
	for name: String in Database.spirlings:
		for side: String in ["front", "back"]:
			var path: String = "res://art/era1/spirlings/%s_%s.png" % [name.to_lower(), side]
			assert_true(ResourceLoader.exists(path), "missing %s" % path)

func test_dex_ids_are_unique_and_dense() -> void:
	var ids: Array[int] = []
	for sd: SpirlingData in Database.spirlings.values():
		assert_false(ids.has(sd.dex_id), "duplicate dex id %d" % sd.dex_id)
		ids.append(sd.dex_id)
	ids.sort()
	assert_eq(ids[0], 1)
	assert_eq(ids[-1], ids.size(), "dex ids should run 1..N without gaps")

## A species is reachable if it is a starter, spawns somewhere, or evolves from one that is.
func test_every_species_is_reachable() -> void:
	var reach: Dictionary = {}
	for sp: String in Database.STARTERS:
		reach[sp] = true
	var enc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for area: String in enc:
		for s: Dictionary in enc[area].spawns:
			reach[str(s.species)] = true
	var grew: bool = true
	while grew:
		grew = false
		for sd: SpirlingData in Database.spirlings.values():
			if reach.has(sd.species_name) and sd.evolves_to != null and not reach.has(sd.evolves_to.species_name):
				reach[sd.evolves_to.species_name] = true
				grew = true
	for name: String in Database.spirlings:
		assert_true(reach.has(name), "%s can't be met anywhere" % name)

func test_lumen_and_umbra_have_base_forms() -> void:
	var seen: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.elements.size() == 1:
			seen[sd.elements[0]] = true
	for e: int in Elements.E.values():
		if e == Elements.E.STONE:
			continue  # Stone shows up in duals (Shalebat, Calderox, Duskdigger).
		assert_true(seen.has(e), "no single-element %s Spirling" % Elements.element_name(e))

func test_every_species_has_a_spirlog_entry() -> void:
	for sd: SpirlingData in Database.spirlings.values():
		assert_false(sd.lore.is_empty(), "%s has no lore" % sd.species_name)
		assert_false(sd.habitat.is_empty(), "%s has no habitat" % sd.species_name)
		assert_false(sd.height.is_empty(), "%s has no height" % sd.species_name)

func test_item_references_are_valid() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	for it: Dictionary in raw:
		if it.has("teaches"):
			assert_not_null(Database.move(str(it.teaches)), "%s teaches an unknown move" % it.id)
		var st: Variant = it.get("stage", {})
		for stat: String in st:
			assert_true(stat in BattleRules.STAGE_STATS, "%s raises unknown stat %s" % [it.id, stat])
		var cure: Variant = it.get("cure", false)
		if cure is String:
			assert_true(StatusRules.exists(cure), "%s cures unknown status %s" % [it.id, cure])
	for sd: SpirlingData in Database.spirlings.values():
		if not sd.evolve_item.is_empty():
			assert_true(bool(Database.item(sd.evolve_item).get("evolves", false)), "%s needs %s" % [sd.species_name, sd.evolve_item])
		if not sd.evolve_map.is_empty():
			assert_true(MapData.exists(sd.evolve_map), "%s evolves in unknown map %s" % [sd.species_name, sd.evolve_map])

func test_item_evolution() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var k := Spirling.new(Database.species("Kelpup"), 12)
	assert_false(k.can_evolve(), "Kelpup has no level evolution")
	assert_eq(GameState.use_item_outside_battle("tide_pearl", k), "", "not in the bag yet")
	GameState.add_item("tide_pearl")
	assert_eq(GameState.use_item_outside_battle("tide_pearl", GameState.party[0]), "", "wrong species")
	assert_ne(GameState.use_item_outside_battle("tide_pearl", k), "")
	assert_eq(k.data.species_name, "Kelphound")
	assert_eq(GameState.item_count("tide_pearl"), 0)

func test_place_evolution() -> void:
	var m := Spirling.new(Database.species("Mirkmole"), 30)
	assert_false(m.can_evolve("crowcrest"))
	assert_true(m.can_evolve("murk_hollow"))

func test_echo_crystals_check_element_and_known_moves() -> void:
	var k := Spirling.new(Database.species("Kindlop"), 10)
	assert_true(GameState.can_learn_echo(k, "echo_ember"))
	assert_false(GameState.can_learn_echo(k, "echo_tide"))
	k.moves.append(Database.move("Kiln Strike"))
	assert_false(GameState.can_learn_echo(k, "echo_ember"), "already knows it")

func test_spark_words_and_training() -> void:
	assert_eq(GameState.spark_word(0), "faint")
	assert_eq(GameState.spark_word(Spirling.SPARK_MAX), "brilliant")
	var s := Spirling.new(Database.species("Zippit"), 20)
	s.spark["atk"] = Spirling.SPARK_MAX - 2
	var before: int = s.atk()
	assert_true(GameState.train_spark(s, "atk", 3))
	assert_eq(s.spark["atk"], Spirling.SPARK_MAX)
	assert_gte(s.atk(), before)
	assert_false(GameState.train_spark(s, "atk", 3), "already maxed")

func test_prism_is_saved() -> void:
	var s := Spirling.new(Database.species("Zippit"), 5)
	s.prism = true
	assert_true(Spirling.from_dict(s.to_dict()).prism)

func test_status_specific_cure_in_battle() -> void:
	var a: Spirling = BattleFixtures.make("Mossling", 15, ["Bowl Over"] as Array[String])
	var b: Spirling = BattleFixtures.make("Zippit", 15, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling])
	m.inventory = {"cooling_gel": 1, "dry_towel": 1}
	m.start()
	a.status = "scorch"
	m.submit_turn(BattleAction.make_item(0, "dry_towel", 0), BattleAction.make_rest(1))
	assert_eq(a.status, "scorch", "a towel doesn't cool")
	m.submit_turn(BattleAction.make_item(0, "cooling_gel", 0), BattleAction.make_rest(1))
	assert_eq(a.status, "")
