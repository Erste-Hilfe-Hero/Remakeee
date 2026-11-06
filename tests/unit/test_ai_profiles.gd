extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 611-615, 625, 627, 629, 637-639):
## Wayfarer personalities and fixed Wayfarer kits.

func before_all() -> void:
	Database.load_all()

func _duel(mine: Array[String], theirs: Array[String], ai: int = 2) -> BattleModel:
	var me: Spirling = BattleFixtures.make("Mossling", 20, theirs)
	var foe: Spirling = BattleFixtures.make("Shalebat", 20, mine)
	# The foe side is the AI side here: index 1 holds the profiled Wayfarer.
	return BattleFixtures.model([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, ai)

func test_profiles_file_has_the_four_p1_profiles_in_range() -> void:
	var all: Dictionary = BattleAI.profiles()
	for id: String in ["balanced", "hothead", "wall", "spoiler"]:
		assert_true(all.has(id), id)
	assert_eq(float(all.hothead.damage_w), 1.4)
	assert_eq(float(all.wall.heal_below), 0.45)
	assert_eq(float(all.spoiler.status_w), 1.6)
	assert_eq(DataValidator.validate().size(), 0, "validate_data checks the 0.2..2.0 band")

func test_unknown_profile_is_balanced() -> void:
	var ai := BattleAI.new(2, "nobody")
	assert_eq(ai.profile_id, "balanced")
	assert_eq(ai.weight("damage_w"), 1.0)
	assert_eq(BattleAI.new(0, "hothead").weight("damage_w"), 1.0, "tier 0 ignores personalities")

func test_hothead_keeps_swinging_at_four_energy_and_rests_at_one() -> void:
	var m: BattleModel = _duel(["Draft Needle", "Grit Jab", "Hunker Down", "Pebble Toss"], ["Bowl Over"])
	m.ai.set_profile("hothead")
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 4
	assert_eq(m.ai.choose(m, 1).kind, BattleAction.Kind.MOVE)
	foe.energy = 1
	assert_eq(m.ai.choose(m, 1).kind, BattleAction.Kind.REST)

func test_hothead_never_swaps_by_choice() -> void:
	var me: Spirling = BattleFixtures.make("Puddlet", 20, ["Spout Jab"] as Array[String])
	var a: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Dash"] as Array[String])
	var b: Spirling = BattleFixtures.make("Mossling", 20, ["Pollen Prick"] as Array[String])
	var m: BattleModel = BattleFixtures.model([me] as Array[Spirling], [a, b] as Array[Spirling], false, 7, 2)
	m.turn = 5
	assert_eq(m.ai.choose(m, 1).kind, BattleAction.Kind.SWAP, "balanced leaves the bad matchup")
	m.ai.set_profile("hothead")
	assert_ne(m.ai.choose(m, 1).kind, BattleAction.Kind.SWAP)

func test_wall_heals_at_forty_percent_vigor() -> void:
	var m: BattleModel = _duel(["Candle Ward", "Pebble Toss"], ["Bowl Over"])
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 6
	foe.hp = int(foe.max_hp() * 0.4)
	assert_eq(m.ai.choose(m, 1).move_index, 1, "balanced still hits at 40%")
	m.ai.set_profile("wall")
	var a: BattleAction = m.ai.choose(m, 1)
	assert_eq(a.kind, BattleAction.Kind.MOVE)
	assert_eq(a.move_index, 0, "the wall mends first")

func test_spoiler_lays_status_before_damage() -> void:
	var m: BattleModel = _duel(["Pebble Toss", "Heat Haze"], ["Bowl Over"])
	var foe: Spirling = m.active_spirling(1)
	foe.energy = 6
	m.ai.set_profile("spoiler")
	assert_eq(m.ai.choose(m, 1).move_index, 1, "status first")
	m.active_spirling(0).status = "jolt"
	assert_eq(m.ai.choose(m, 1).move_index, 0, "then damage once the target carries a status")

func test_profiles_change_choice_not_numbers() -> void:
	var dmg: Array[int] = []
	for p: String in ["balanced", "hothead"]:
		var m: BattleModel = _duel(["Pebble Toss"], ["Bowl Over"])
		m.ai.set_profile(p)
		var me: Spirling = m.active_spirling(0)
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_move(1, 0))
		dmg.append(me.max_hp() - me.hp)
	assert_eq(dmg[0], dmg[1])

func test_replay_keeps_the_profile() -> void:
	var m: BattleModel = _duel(["Pebble Toss"], ["Bowl Over"])
	m.ai.set_profile("spoiler")
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	assert_eq(BattleReplay.build_model(JSON.parse_string(JSON.stringify(snap))).ai.profile_id, "spoiler")

func test_team_entries_take_fixed_arts_keepsake_and_difficulty() -> void:
	var rng := RandomNumberGenerator.new()
	var def: Dictionary = {"trainer": "Test", "profile": "hothead",
		"team": [{"species": "Zephlet", "level": 7}],
		"teams_by_difficulty": {"story": [{"species": "Zephlet", "level": 6}],
			"veteran": [{"species": "Zephlet", "level": 7, "moves": ["Kite Cut", "Draft Needle", "Nope"], "held": "spark_coil"}]}}
	assert_eq(TrainerData.build_team(def, "", rng, GameState.Difficulty.STORY)[0].level, 6)
	assert_eq(TrainerData.build_team(def, "", rng, GameState.Difficulty.TAMER)[0].level, 7, "missing block falls back to team")
	var vet: Spirling = TrainerData.build_team(def, "", rng, GameState.Difficulty.VETERAN)[0]
	assert_eq(vet.moves.size(), 2, "unknown arts are skipped")
	assert_eq(vet.moves[0].move_name, "Kite Cut")
	assert_eq(vet.held, "spark_coil")
	var up: Array[Spirling] = TrainerData.rematch_team(def, "", rng, 20, 100, GameState.Difficulty.VETERAN)
	assert_eq(up[0].moves[1].move_name, "Draft Needle", "a rematch keeps the fixed kit")
	assert_eq(TrainerData.battle_info(def, [vet] as Array[Spirling], 2).profile, "hothead")
