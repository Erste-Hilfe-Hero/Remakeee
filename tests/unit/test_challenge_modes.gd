extends GutTest
## KAMPF_PLAN_1000, area "Schwierigkeit und Herausforderungen" (items 486-520): the challenge
## modes of data/challenge_modes.json, the run seed, the challenge record, the Story crit and
## Growth touches, Rift-Born art fill, the ranked difficulty and the rest spring cap note.

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")

func _spirling(species: String, ring: int) -> Spirling:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return Spirling.new(Database.species(species), ring, rng)

func _model(wild: bool, foes: Array[Spirling] = []) -> BattleModel:
	var mine: Array[Spirling] = [_spirling("Kindlop", 12), _spirling("Mossling", 12)]
	if foes.is_empty():
		foes = [_spirling("Shalebat", 12)]
	var m := BattleModel.new(mine, foes, wild, 5, 1)
	m.inventory = {"tonic": 2, "remedy": 1}
	return m

func _kinds(m: BattleModel) -> Array[int]:
	var out: Array[int] = []
	for a: BattleAction in m.legal_actions(BattleModel.Side.PLAYER):
		out.append(a.kind)
	return out

func test_every_mode_has_a_name_and_text() -> void:
	for id: String in ChallengeRules.ids():
		var c: Dictionary = ChallengeRules.find(id)
		assert_false(str(c.get("name", "")).is_empty(), id)
		assert_false(str(c.get("text", "")).is_empty(), id)
	assert_eq(ChallengeRules.ids().size(), 13)

func test_rules_combine_and_are_taken_only_before_the_first_rift() -> void:
	assert_true(ChallengeRules.take("night_bonds"))
	assert_true(ChallengeRules.take("stand_ground"))
	assert_false(ChallengeRules.take("night_bonds"), "already on")
	assert_false(ChallengeRules.take("bogus"))
	assert_eq(ChallengeRules.active_ids(), ["stand_ground", "night_bonds"] as Array[String])
	GameState.seal_rift("cinder")
	assert_false(ChallengeRules.take("half_rested"), "too late after the first Rift")
	assert_true(ChallengeRules.drop("night_bonds"), "dropping works at any time")
	assert_true(bool(GameState.records.get(ChallengeRules.DROPPED_KEY, false)))
	assert_true(ChallengeRules.stats_lines()[-1] == Loc.t("A rule was dropped on the way."))

func test_seed_code_round_trip() -> void:
	for v: int in [0, 1, 31, 99999, ChallengeRules.code_space() - 1]:
		var code: String = ChallengeRules.seed_code(v)
		assert_eq(code.length(), ChallengeRules.CODE_LENGTH)
		assert_eq(ChallengeRules.parse_code(code), v)
		assert_eq(ChallengeRules.parse_code(" " + code.to_lower() + " "), v, "case and spaces do not matter")
	assert_eq(ChallengeRules.parse_code("OOOOOOO"), -1, "O is not a code letter")
	assert_eq(ChallengeRules.parse_code("ABC"), -1)
	var s: int = ChallengeRules.ensure_seed()
	assert_eq(ChallengeRules.ensure_seed(), s, "made once")
	ChallengeRules.set_seed(1234)
	assert_eq(ChallengeRules.run_seed(), 1234)

func test_bond_blocks() -> void:
	var foes: Array = [_spirling("Puddlet", 5)]
	assert_eq(ChallengeRules.bond_block("route_a", foes, false), "")
	ChallengeRules.take("night_bonds")
	assert_ne(ChallengeRules.bond_block("route_a", foes, false), "")
	assert_eq(ChallengeRules.bond_block("route_a", foes, true), "")
	ChallengeRules.drop("night_bonds")
	ChallengeRules.take("first_meeting")
	assert_eq(ChallengeRules.bond_block("route_a", foes, true), "", "the first meeting may bond")
	ChallengeRules.note_wild_battle("route_a")
	assert_ne(ChallengeRules.bond_block("route_a", foes, true), "", "the second may not")
	assert_eq(ChallengeRules.bond_block("route_b", foes, true), "")
	ChallengeRules.drop("first_meeting")
	ChallengeRules.take("one_per_place")
	ChallengeRules.note_bonded(foes[0], "route_b")
	assert_ne(ChallengeRules.bond_block("route_b", foes, true), "")
	ChallengeRules.drop("one_per_place")
	ChallengeRules.take("one_element")
	assert_ne(ChallengeRules.bond_block("route_c", foes, true), "", "Tide does not match an Ember partner")
	assert_eq(ChallengeRules.bond_block("route_c", [_spirling("Smoldrake", 20)], true), "")

func test_wild_battle_without_bond_and_with_reason() -> void:
	ChallengeRules.take("night_bonds")
	var m: BattleModel = _model(true)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	m.start()
	if DayCycle.current() == DayCycle.Phase.NIGHT:
		assert_eq(m.bond_block, "")
		return
	assert_false(m.bond_block.is_empty())
	assert_false(BattleAction.Kind.BOND in _kinds(m))
	assert_false(m.is_legal(BattleAction.make_bond(BattleModel.Side.PLAYER, 1.0, "", 0)))
	assert_true(BattleAction.Kind.RUN in _kinds(m), "running still works")

func test_shuffled_wilds_are_fixed_by_seed_place_and_species() -> void:
	assert_eq(ChallengeRules.wild_species("Puddlet", "route_a"), "Puddlet", "off: no change")
	ChallengeRules.take("wild_shuffle")
	ChallengeRules.set_seed(77)
	var a: String = ChallengeRules.wild_species("Puddlet", "route_a")
	assert_eq(ChallengeRules.wild_species("Puddlet", "route_a"), a, "the same every time")
	var sd: SpirlingData = Database.species(a)
	assert_not_null(sd)
	assert_eq(sd.region, Database.species("Puddlet").region)
	assert_ne(sd.rarity, "ancient")
	var changed: bool = false
	for v: int in 20:
		ChallengeRules.set_seed(v)
		changed = changed or ChallengeRules.wild_species("Puddlet", "route_a") != a
	assert_true(changed, "another seed shuffles differently")
	var rng := RandomNumberGenerator.new()
	var w: Spirling = _spirling("Puddlet", 7)
	var r: Spirling = ChallengeRules.reroll_wild(w, "route_a", rng)
	assert_eq(r.level, 7)
	assert_eq(r.data.species_name, ChallengeRules.wild_species("Puddlet", "route_a"))

func test_shuffled_arts_fit_the_ring() -> void:
	var s: Spirling = _spirling("Kindlop", 8)
	var before: Array[MoveData] = s.moves.duplicate()
	ChallengeRules.shuffle_arts(s)
	assert_eq(s.moves, before, "off: no change")
	ChallengeRules.take("art_shuffle")
	ChallengeRules.set_seed(5)
	ChallengeRules.shuffle_arts(s)
	assert_between(s.moves.size(), 1, Spirling.MAX_MOVES)
	var hits: int = 0
	for mv: MoveData in s.moves:
		hits += 1 if mv.is_damaging() else 0
		assert_lte(int(ChallengeRules._art_ring.get(mv.move_name, 99)), 8, mv.move_name)
	assert_gt(hits, 0, "at least one damaging art")
	var again: Spirling = _spirling("Kindlop", 8)
	again.uid = s.uid
	ChallengeRules.shuffle_arts(again)
	assert_eq(again.moves, s.moves, "the seed decides")

func test_spring_water_blocks_healing_items_for_the_player_only() -> void:
	assert_true(ChallengeRules.item_allowed("tonic"))
	ChallengeRules.take("spring_water")
	assert_false(ChallengeRules.item_allowed("tonic"))
	assert_true(ChallengeRules.item_allowed("remedy"), "a cure is no healing")
	var m: BattleModel = _model(false)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	m.start()
	assert_true("tonic" in m.blocked_items)
	assert_false(m.is_legal(BattleAction.make_item(BattleModel.Side.PLAYER, "tonic", 0, 0)))
	assert_true(m.is_legal(BattleAction.make_item(BattleModel.Side.PLAYER, "remedy", 0, 0)) or not GameState.items_allowed_in_battle())
	m.foe_items = {"tonic": 1}
	assert_true(m.is_legal(BattleAction.make_item(BattleModel.Side.FOE, "tonic", 0, 0)), "foes keep their tonics")

func test_no_items_rule_closes_the_bag() -> void:
	ChallengeRules.take("no_items")
	var m: BattleModel = _model(false)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	m.start()
	assert_false(BattleAction.Kind.ITEM in _kinds(m))

func test_stand_your_ground_locks_chosen_swaps_but_not_replacements() -> void:
	var m: BattleModel = _model(false)
	m.start()
	assert_true(BattleAction.Kind.SWAP in _kinds(m))
	ChallengeRules.take("stand_ground")
	m = _model(false)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	m.start()
	assert_false(BattleAction.Kind.SWAP in _kinds(m))
	assert_false(m.is_legal(BattleAction.make_swap(BattleModel.Side.PLAYER, 1, 0)))
	assert_false(m.swap_candidates(BattleModel.Side.PLAYER, 0).is_empty(), "a fallen Spirling can still be replaced")

func test_half_rested() -> void:
	var party: Array[Spirling] = [_spirling("Kindlop", 10)]
	ChallengeRules.after_rest(party)
	assert_eq(party[0].hp, party[0].max_hp())
	ChallengeRules.take("half_rested")
	ChallengeRules.after_rest(party)
	assert_eq(party[0].hp, ceili(party[0].max_hp() / 2.0))

func test_ace_up_front() -> void:
	var foes: Array[Spirling] = [_spirling("Shalebat", 8), _spirling("Puddlet", 14), _spirling("Mossling", 10)]
	ChallengeRules.order_foes(foes)
	assert_eq(foes[0].level, 8, "off: no change")
	ChallengeRules.take("ace_first")
	var m: BattleModel = _model(false, foes)
	ChallengeRules.apply_to_model(m, {"name": "Wayfarer"}, "route_a")
	assert_eq((m.parties[1][0] as Spirling).level, 14)
	assert_eq(m.parties[1].size(), 3)

func test_story_softens_crits_and_gives_more_growth() -> void:
	GameState.difficulty = GameState.Difficulty.STORY
	var m: BattleModel = _model(false)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	assert_eq(m.foe_crit_mult, ChallengeRules.FOE_CRIT[0])
	assert_lt(m.foe_crit_mult, 1.0)
	assert_almost_eq(m.xp_mult, ChallengeRules.GROWTH[0], 0.001)
	assert_gt(m.xp_mult, 1.0)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "")
	assert_eq(float(snap.foe_crit), m.foe_crit_mult)
	GameState.difficulty = GameState.Difficulty.TAMER
	m = _model(false)
	ChallengeRules.apply_to_model(m, {}, "route_a")
	assert_eq(m.foe_crit_mult, 1.0)
	assert_false(BattleReplay.snapshot(m, "battle", "").has("foe_crit"), "old replays stay the same")

func test_echo_duels_stay_even() -> void:
	GameState.difficulty = GameState.Difficulty.STORY
	ChallengeRules.take("stand_ground")
	var m: BattleModel = _model(false)
	ChallengeRules.apply_to_model(m, {"player_team": [_spirling("Kindlop", 5)]}, "route_a")
	assert_eq(m.foe_crit_mult, 1.0)
	assert_false(m.swap_locked)

func test_rift_born_foes_know_four_arts() -> void:
	var low: Spirling = _spirling("Shalebat", 3)
	var known: int = low.moves.size()
	GameState.difficulty = GameState.Difficulty.RIFT_BORN
	var m: BattleModel = _model(false, [low] as Array[Spirling])
	ChallengeRules.apply_to_model(m, {"name": "Wayfarer"}, "route_a")
	assert_gte(low.moves.size(), known)
	assert_lte(low.moves.size(), Spirling.MAX_MOVES)
	for i: int in low.data.learnset_levels.size():
		if low.data.learnset_levels[i] <= low.level + ChallengeRules.RIFT_BORN_ART_REACH and low.moves.size() < Spirling.MAX_MOVES:
			assert_has(low.moves, low.data.learnset_moves[i])

func test_battle_line_names_difficulty_and_rules() -> void:
	var m: BattleModel = _model(false)
	ChallengeRules.apply_to_model(m, {"name": "Wayfarer"}, "route_a")
	assert_false(m.has_meta("challenge_line"), "a normal Wayfarer battle shows nothing extra")
	ChallengeRules.take("ace_first")
	m = _model(false)
	ChallengeRules.apply_to_model(m, {"name": "Wayfarer"}, "route_a")
	var line: String = str(m.get_meta("challenge_line"))
	assert_string_contains(line, Loc.t("Wayfarer"))
	assert_string_contains(line, Loc.t("Ace Up Front"))

func test_challenge_record() -> void:
	ChallengeRules.note_result(true, true)
	assert_false(GameState.records.has(ChallengeRules.STATS_KEY), "no rules, no record")
	ChallengeRules.take("half_rested")
	ChallengeRules.note_result(true, true)
	ChallengeRules.note_result(true, false)
	ChallengeRules.note_result(false, false)
	var st: Dictionary = GameState.records[ChallengeRules.STATS_KEY]
	assert_eq(int(st.wins), 2)
	assert_eq(int(st.losses), 1)
	assert_eq(int(st.wardens), 1)
	assert_string_contains(ChallengeRules.stats_lines()[0], "2")

func test_ranked_difficulty_never_rises_after_a_lowering() -> void:
	GameState.set_difficulty(GameState.Difficulty.RIFT_BORN)
	assert_eq(ChallengeRules.ranked_difficulty(), int(GameState.Difficulty.RIFT_BORN), "raising before any lowering counts")
	GameState.set_difficulty(GameState.Difficulty.STORY)
	GameState.set_difficulty(GameState.Difficulty.VETERAN)
	assert_eq(GameState.difficulty, GameState.Difficulty.VETERAN)
	assert_eq(ChallengeRules.ranked_difficulty(), int(GameState.Difficulty.STORY))
	assert_eq(int(RunChronicle.entry().difficulty), int(GameState.Difficulty.STORY))

func test_rest_names_the_ring_cap_on_veteran() -> void:
	assert_true(ChallengeRules.rest_lines().is_empty(), "no cap on Wayfarer")
	GameState.difficulty = GameState.Difficulty.VETERAN
	var lines: Array[String] = ChallengeRules.rest_lines()
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "R%d" % GameState.level_cap())
	assert_true("ring_caps" in Lexicon.collected(GameState.records))

func test_lexicon_and_no_paid_rules() -> void:
	assert_true(Lexicon.has_entry("challenges"))
	assert_true(Lexicon.has_entry("ring_caps"))
	var shop: String = FileAccess.get_file_as_string("res://data/shop.json")
	for id: String in ChallengeRules.ids():
		assert_false("\"%s\"" % id in shop, "challenge %s is never sold" % id)

func test_challenge_menu_rows() -> void:
	var rows: Array[Dictionary] = ChallengeMenu.entries()
	assert_eq(rows.size(), ChallengeRules.ids().size() + 3)
	assert_string_contains(str(rows[ChallengeRules.ids().size()].text), ChallengeRules.seed_code(ChallengeRules.run_seed()))
	GameState.seal_rift("cinder")
	assert_eq(ChallengeMenu.entries().size(), ChallengeRules.ids().size() + 2, "no clipboard seed after the first Rift")
	var keys: Array = []
	for r: Array in MenuHost.settings_rows("game"):
		keys.append(r[0])
	assert_has(keys, "challenges")
