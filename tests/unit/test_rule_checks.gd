extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 861, 862, 867): rule variants
## change exactly their own numbers, the difficulty table in GameState is what a battle gets,
## and the IP check's banned terms are not in any art, rule, profile or puzzle name.

func before_all() -> void:
	Database.load_all()

func _fixed(variants: Array[String]) -> BattleModel:
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Nip"] as Array[String])
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var m: BattleModel = BattleFixtures.model([a] as Array[Spirling], [b] as Array[Spirling], false, 31)
	m.variants = variants
	m.start()
	return m

## Item 861.
func test_every_variant_changes_exactly_the_numbers_in_its_file() -> void:
	var plain: BattleModel = _fixed([] as Array[String])
	assert_eq(plain.rules, BattleRules.VARIANT_KEYS, "no variant, default rules")
	var all: Dictionary = BattleRules.variants()
	assert_gt(all.size(), 5)
	for id: String in all:
		var keys: Dictionary = all[id].get("keys", {})
		assert_false(keys.is_empty(), "%s sets at least one number" % id)
		var m: BattleModel = _fixed([id] as Array[String])
		for k: String in BattleRules.VARIANT_KEYS:
			if keys.has(k):
				assert_almost_eq(float(m.rules[k]), float(keys[k]), 0.0001, "%s sets %s" % [id, k])
			else:
				assert_eq(m.rules[k], plain.rules[k], "%s leaves %s alone" % [id, k])
		# What the start of the fixed battle shows.
		var me: Spirling = m.parties[0][0]
		var base: Spirling = plain.parties[0][0]
		var want_energy: int = mini(int(m.rules.start_energy), m.max_energy())
		assert_eq(me.energy, want_energy, "%s start Energy" % id)
		assert_eq(me.max_hp(), int(base.max_hp() * float(m.rules.hp_mult)) if keys.has("hp_mult") else base.max_hp(), "%s Vigor" % id)

## Item 862.
func test_difficulty_values_match_the_table_in_game_state() -> void:
	var def: Dictionary = {"team": [{"species": "Kindlop", "level": 20}, {"species": "Mossling", "level": 22}]}
	for d: int in GameState.Difficulty.values():
		var rng := RandomNumberGenerator.new()
		rng.seed = 862
		var team: Array[Spirling] = TrainerData.build_team(def, "", rng, d)
		var want_size: int = 3 if d == GameState.Difficulty.RIFT_BORN else 2
		assert_eq(team.size(), want_size, "difficulty %d team size" % d)
		assert_eq(team[0].level, 20 + GameState.FOE_LEVEL_SHIFT[d], "difficulty %d ring shift" % d)
		assert_eq(team[1].level, 22 + GameState.FOE_LEVEL_SHIFT[d])
		for s: Spirling in team:
			for key: String in Spirling.STAT_KEYS:
				assert_eq(int(s.spark[key]), GameState.FOE_SPARK[d], "difficulty %d spark %s" % [d, key])
		if d == GameState.Difficulty.RIFT_BORN:
			assert_eq(team[2].data.species_name, "Kindlop", "the extra copy is the lowest entry")
		var mine: Array[Spirling] = [BattleFixtures.make("Zippit", 20)]
		var m := BattleModel.new(mine, team, false, 5, GameState.AI_LEVELS[d])
		m.start_energy_cut = [0, BattleRules.foe_start_cut(d)]
		m.foe_turn1_energy = BattleRules.foe_turn1_energy(d)
		m.start()
		assert_eq(mine[0].energy, Spirling.MAX_ENERGY, "the player starts full")
		assert_eq(team[0].energy, Spirling.MAX_ENERGY - BattleRules.FOE_START_CUT[d], "difficulty %d foe start Energy" % d)
	assert_eq(GameState.FOE_SPARK, [0, 3, 6, 10] as Array[int])
	assert_eq(GameState.FOE_LEVEL_SHIFT, [-1, 0, 1, 2] as Array[int])
	assert_eq(BattleRules.FOE_START_CUT, [2, 0, 0, 0] as Array[int])
	assert_eq(BattleRules.FOE_TURN1_ENERGY, [0, 0, 0, 1] as Array[int])
	assert_eq(TrainerData.RIFT_BORN_MAX_TEAM, 5)

## Item 867: the banned-term pattern of tools/ip_check.sh over every name this area added.
func _ip_patterns() -> Array[RegEx]:
	var script: String = FileAccess.get_file_as_string("res://tools/ip_check.sh")
	var out: Array[RegEx] = []
	var find := RegEx.create_from_string("(pattern|phrases)=\"\\$\\(printf '%s' '([A-Za-z0-9+/=]+)' \\| base64 -d\\)\"")
	for m: RegExMatch in find.search_all(script):
		var re := RegEx.new()
		assert_eq(re.compile("(?i)" + Marshalls.base64_to_utf8(m.get_string(2))), OK)
		out.append(re)
	return out

func test_ip_check_terms_are_in_no_art_rule_profile_or_puzzle_name() -> void:
	var res: Array[RegEx] = _ip_patterns()
	assert_eq(res.size(), 2, "banned terms and borrowed phrases")
	var names: Array[String] = []
	for md: MoveData in Database.moves.values():
		names.append(md.move_name)
	for id: String in BattleRules.variants():
		names.append(id)
		names.append(str(BattleRules.variants()[id].get("label", "")))
		names.append(str(BattleRules.variants()[id].get("text", "")))
	var profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai_profiles.json"))
	if profiles is Dictionary:
		for k: String in profiles:
			names.append(k)
			names.append(JSON.stringify(profiles[k]))
	var puzzles: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	assert_not_null(puzzles)
	names.append(JSON.stringify(puzzles))
	assert_gt(names.size(), 150)
	for n: String in names:
		for re: RegEx in res:
			assert_null(re.search(n), "banned term in %s" % n.left(80))
	# The check itself works: a known banned term is found.
	assert_not_null(res[0].search(Marshalls.base64_to_utf8("UG9rZWJhbGw=")))
