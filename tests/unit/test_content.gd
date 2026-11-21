extends GutTest
## Content: every Spirling has art and can be met in the world, and dex numbers are unique.

func before_all() -> void:
	Database.load_all()

## Each kind is drawn in its own era (Era III kinds of Quillmarch in art/era3/).
func test_every_species_has_art() -> void:
	for name: String in Database.spirlings:
		for side: String in ["front", "back"]:
			var path: String = "res://art/era%d/spirlings/%s_%s.png" % [Database.spirlings[name].era, name.to_lower(), side]
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
		# Kinds of regions that are not playable yet wait in the data (plan area 1, items 61-63).
		if Database.spirlings[name].region != "veydal":
			continue
		# First Voices are met once at a fixed place (FirstVoices.VOICES), never in the wild.
		if FirstVoices.VOICES.has(name) or FirstVoices.LEGENDS.has(name):
			continue
		assert_true(reach.has(name), "%s can't be met anywhere" % name)

func test_lumen_and_umbra_have_base_forms() -> void:
	var seen: Dictionary = {}
	var used: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.elements.size() == 1:
			seen[sd.elements[0]] = true
		for e: int in sd.elements:
			used[e] = true
	for e: int in Elements.E.values():
		if e == Elements.E.STONE:
			continue  # Stone shows up in duals (Shalebat, Calderox, Duskdigger).
		if not used.has(e):
			continue  # Element added ahead of its region's kinds.
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

# --- Plan area 1: the ten new Veydal lines (items 26-37, 101-104, 333) -----------------------

const NEW_VEYDAL: Array[String] = ["Blotling", "Scrivane", "Hushkin", "Silentra", "Paddlewisp",
	"Ferrowyn", "Talusk", "Talusgard", "Cairnhold", "Fluting", "Marshfife", "Glasstarn", "Lanternel",
	"Seamlet", "Mendlace", "Croziel", "Frondmere", "Brinelet", "Saltspire"]

func test_new_lines_are_in_veydal_with_their_rules() -> void:
	for n: String in NEW_VEYDAL:
		assert_not_null(Database.species(n), n)
		assert_eq(Database.species(n).region, "veydal", n)
	var rule: Dictionary = {"Blotling": ["map_pages", 6], "Seamlet": ["mended", "origin"],
		"Fluting": ["time", "dusk"], "Hushkin": ["echo_streak", 10]}
	for n: String in rule:
		var p: Dictionary = Database.species(n).unfold[0]
		assert_eq(str(p.rule), str(rule[n][0]), n)
		assert_eq(str(p.value), str(rule[n][1]), n)
	assert_eq(str(Database.species("Fluting").unfold[0].map), "saltmarsh")
	assert_true(Database.species("Glasstarn").unfold.is_empty(), "Glasstarn does not unfold")
	assert_true(Database.species("Lanternel").unfold.is_empty(), "Lanternel does not unfold")
	assert_eq(Database.species("Glasstarn").rarity, "shy")
	assert_eq(Database.species("Lanternel").rarity, "uncommon")
	assert_eq(BalanceSim.stage(Database.species("Cairnhold")), 3, "Talusk's line has three stages")

func test_new_kinds_spread_over_the_veydal_maps() -> void:
	for map_id: String in ["fernstair", "crowcrest", "saltmarsh", "thornridge", "murk_hollow"]:
		var n: int = 0
		for sp: String in EncounterTable.species_on(map_id):
			n += 1 if sp in NEW_VEYDAL else 0
		assert_gte(n, 2, "%s has at least two new kinds" % map_id)

func test_every_element_has_four_veydal_kinds() -> void:
	var count: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		if sd.region != "veydal":
			continue
		for e: int in sd.elements:
			count[e] = int(count.get(e, 0)) + 1
	var types: Dictionary = Elements.chart().get("types", {})
	for e: int in Elements.E.values():
		# Era II elements (Ink, Echo) sit only on legendaries so far.
		if int(types[Elements.E.keys()[e]].get("era", 1)) > 1:
			continue
		assert_gte(int(count.get(e, 0)), 4, "%s in Veydal" % Elements.element_name(e))

func test_no_trait_on_more_than_six_lines() -> void:
	# Per region: with 70 kinds per act (owner rule) the eight traits are spread over each act.
	var lines: Dictionary = {}
	for sd: SpirlingData in Database.spirlings.values():
		var key: String = "%s in %s" % [sd.trait_id, sd.region]
		var set: Dictionary = lines.get(key, {})
		set[sd.line_id] = true
		lines[key] = set
	for t: String in lines:
		assert_lte((lines[t] as Dictionary).size(), 6, "trait %s" % t)

func test_perfect_echoes_grow_the_streak_and_a_miss_resets_it() -> void:
	var saved: Dictionary = GameState.to_dict()
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	var h := Spirling.new(Database.species("Hushkin"), 12)
	GameState.receive_spirling(h)
	for i: int in 9:
		GameState.note_echo(1.0)
	assert_false(h.can_unfurl())
	GameState.note_echo(1.0)
	assert_true(h.can_unfurl(), "ten perfect echoes in the team")
	GameState.note_echo(0.75)
	assert_eq(h.echo_streak, 0)
	GameState.from_dict(saved)
