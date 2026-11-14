extends GutTest
## KAMPF_PLAN_1000 items 526, 535, 558, 559, 812: Wayfarer strategies (several at once, Overcharge),
## no repeated kinds in Wayfarer teams, the bond lessons of Wanderer Wren and the lesson battles.

func before_all() -> void:
	Database.load_all()

func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _npc(map_id: String, id: String) -> Dictionary:
	for n: Variant in (_read("res://data/maps/%s.json" % map_id) as Dictionary).get("npcs", []):
		if n is Dictionary and str(n.get("id", "")) == id:
			return n
	return {}

## Every Wayfarer of the maps (floors too) and every story duel, as [label, def].
func _all_wayfarers() -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at("res://data/maps"):
		if not f.ends_with(".json"):
			continue
		var raw: Dictionary = _read("res://data/maps/" + f)
		var levels: Array = [raw]
		levels.append_array(raw.get("floors", []))
		for lv: Variant in levels:
			for n: Variant in (lv as Dictionary).get("npcs", []):
				if n is Dictionary and TrainerData.is_trainer(n):
					out.append(["%s:%s" % [f.get_basename(), n.get("id", "")], n])
	var placed: Dictionary = _read(StoryPlacements.PATH)
	for map_id: String in placed:
		if placed[map_id] is Dictionary:
			for n: Variant in (placed[map_id] as Dictionary).get("npcs", []):
				if n is Dictionary and TrainerData.is_trainer(n):
					out.append(["placed %s:%s" % [map_id, n.get("id", "")], n])
	var story: Dictionary = _read(StoryBattles.PATH)
	for k: String in story:
		if story[k] is Dictionary and TrainerData.is_trainer(story[k]):
			out.append(["story:" + k, story[k]])
	return out

# --- 535 -------------------------------------------------------------------------------------

func test_no_wayfarer_team_repeats_a_kind() -> void:
	var all: Array = _all_wayfarers()
	assert_gt(all.size(), 200)
	for pair: Array in all:
		assert_eq(TrainerData.repeated_species(pair[1]), [] as Array[String], str(pair[0]))

func test_repeat_rule() -> void:
	var a: Dictionary = {"species": "Zippit", "level": 5}
	var b: Dictionary = {"species": "Mossling", "level": 5}
	assert_eq(TrainerData.repeated_species({"team": [a, b]}).size(), 0)
	assert_eq(TrainerData.repeated_species({"team": [a, a]}), ["team: Zippit"] as Array[String])
	assert_eq(TrainerData.repeated_species({"team": [a, a], "twins": ["Zippit"]}).size(), 0, "named twins")
	assert_eq(TrainerData.repeated_species({"team": [a, a], "wild": true}).size(), 0, "wild horde")
	var tuned: Dictionary = {"team": [a, b], "teams_by_difficulty": {"rift_born": [a, b, a], "story": [a, a]}}
	assert_eq(TrainerData.repeated_species(tuned), ["story: Zippit"] as Array[String], "one extra copy only from Tamer on")
	tuned.teams_by_difficulty["tamer"] = [a, a, a]
	assert_eq(TrainerData.repeated_species(tuned).size(), 2)

func test_the_named_twins() -> void:
	assert_eq(_npc("crowcrest", "bram").get("twins"), ["Shalebat"])
	assert_eq(_npc("lantern_steps", "isa").get("twins"), ["Zephlet"])
	assert_eq(_npc("candle_causeway", "tollwick").get("twins"), ["Puddock"])
	assert_eq((_read(StoryBattles.PATH) as Dictionary).bounty_b11.get("twins"), ["Gloamhog"])

# --- 526 and 558 -----------------------------------------------------------------------------

func test_cart_pusher_grim_plays_several_at_once() -> void:
	var def: Dictionary = _npc("slag_tunnels", "cart_pusher")
	assert_eq(str(def.get("strategy")), "multi")
	assert_eq(TrainerData.strategy_problems(def), [] as Array[String])
	assert_eq(TrainerData.front(def), [2, 2] as Array[int])
	var team: Array[Spirling] = TrainerData.build_team(def, "", RandomNumberGenerator.new(), 1)
	for s: Spirling in team:
		var spread: bool = false
		for mv: MoveData in s.moves:
			spread = spread or (mv.is_area() and mv.is_damaging())
		assert_true(spread, s.data.species_name)

func test_crater_prospector_thea_banks_for_overcharge() -> void:
	var def: Dictionary = _npc("fallen_planet", "hs_thea")
	assert_eq(str(def.get("strategy")), "overcharge")
	assert_eq(TrainerData.strategy_problems(def), [] as Array[String])
	var vet: Array[Spirling] = TrainerData.build_team(def, "", RandomNumberGenerator.new(), GameState.Difficulty.VETERAN)
	var held: Array[String] = []
	for s: Spirling in vet:
		held.append(s.held)
	assert_true("kit_rift_splinter" in held, "the Overcharge keepsake on Veteran")

func test_strategy_check_finds_a_broken_team() -> void:
	var plain: Dictionary = {"team": [{"species": "Zippit", "level": 20}], "strategy": "overcharge", "profile": "surger"}
	assert_false(TrainerData.strategy_problems(plain).is_empty())
	var multi: Dictionary = {"team": [{"species": "Zippit", "level": 20, "moves": ["Thunderhead"]}], "strategy": "multi", "profile": "sweeper"}
	assert_false(TrainerData.strategy_problems(multi).is_empty(), "one foe at the front is no multi battle")
	multi["front"] = [2, 2]
	assert_eq(TrainerData.strategy_problems(multi), [] as Array[String])
	multi["profile"] = "hothead"
	assert_false(TrainerData.strategy_problems(multi).is_empty())
	assert_false(TrainerData.strategy_problems({"team": [], "strategy": "nonsense"}).is_empty())

func test_sweeper_prefers_the_sweep() -> void:
	var rng := RandomNumberGenerator.new()
	var foe := Spirling.new(Database.species("Latchet"), 57, rng)
	foe.moves = [Database.move("Landslip")] as Array[MoveData]
	var a := Spirling.new(Database.species("Mossling"), 30, rng)
	var b := Spirling.new(Database.species("Mossling"), 30, rng)
	var m := BattleModel.new([a, b] as Array[Spirling], [foe, Spirling.new(Database.species("Knellgrim"), 58, rng)] as Array[Spirling], false, 1, 1)
	m.front_size = [2, 2]
	m.start()
	m.ai.set_profile("balanced")
	var plain: float = m.ai.score_action(m, 1, 0, 0, -1)
	m.ai.set_profile("sweeper")
	assert_gt(m.ai.score_action(m, 1, 0, 0, -1), plain)

func test_surger_counts_the_charged_hit() -> void:
	var rng := RandomNumberGenerator.new()
	var me := Spirling.new(Database.species("Rollibex"), 60, rng)
	me.moves = [Database.move("All-In Crash")] as Array[MoveData]
	var target := Spirling.new(Database.species("Brickolossus"), 70, rng)
	var m := BattleModel.new([target] as Array[Spirling], [me] as Array[Spirling], false, 1, 1)
	m.start()
	me.energy = Spirling.MAX_ENERGY
	m.ai.set_profile("balanced")
	var plain: float = m.ai.score_move(m, 1, 0)
	m.ai.set_profile("surger")
	assert_gt(m.ai.score_move(m, 1, 0), plain)
	assert_eq(int(BattleAI.profiles().surger.rest_below), 2, "rests to bank Energy")

# --- 559 and 812 -----------------------------------------------------------------------------

func test_teachers_have_their_lessons() -> void:
	assert_eq(str(_npc("fernstair", "imme").get("lessons")), "pathkeeper")
	assert_eq(str(_npc("gloamwood", "wren").get("lessons")), "listener")
	assert_gte(BattlePuzzle.for_teacher("pathkeeper").size(), 3)
	var bond: Array[Dictionary] = BattlePuzzle.for_teacher("listener")
	assert_gte(bond.size(), 2)
	for p: Dictionary in bond:
		assert_false(BattlePuzzle.needs_win(p), "%s leaves the foe standing" % p.id)

func test_every_lesson_is_complete_and_solvable() -> void:
	var ids: Dictionary = {}
	for p: Dictionary in BattlePuzzle.lessons():
		for key: String in ["id", "teacher", "name", "text", "player", "foe", "seed", "ai", "goal", "max_turns", "hint_1", "hint_2"]:
			assert_true(p.has(key), "%s has %s" % [p.get("id", "?"), key])
		assert_false(ids.has(p.id), "unique id")
		assert_true(BattlePuzzle.by_id(str(p.id)).is_empty(), "no clash with a Trial id")
		ids[p.id] = true
		for g: Dictionary in BattlePuzzle.goals(p):
			assert_true(str(g.get("type", "")) in BattlePuzzle.GOALS, str(p.id))
		var r: Dictionary = BattlePuzzle.search(p)
		assert_gt(int(r.wins), 0, "%s has a solution" % p.id)
		assert_lt(float(r.share), 1.0, "%s can be missed" % p.id)
		assert_eq(int(p.get("best_turns", 0)), int(r.best_turns), "%s best_turns" % p.id)
		var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
		for d: Dictionary in r.solution:
			BattlePuzzle.play(p, at, BattleReplay.action_from_dict(d))
		assert_true(BattlePuzzle.solved(p, at), str(p.id))
		assert_gte(BattlePuzzle.lanterns(p, at), 2, str(p.id))

func test_bond_goal_fails_on_a_knock_out() -> void:
	var p: Dictionary = BattlePuzzle.for_teacher("listener")[0]
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	var foe: Spirling = at.model.party(BattleModel.Side.FOE)[0]
	foe.hp = 1
	assert_true(BattlePuzzle.goal_met(p, {"type": "bond_ready", "value": 0.34}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "foe_status"}, at))
	foe.status = "soak"
	assert_true(BattlePuzzle.goal_met(p, {"type": "foe_status"}, at))
	foe.hp = 0
	assert_false(BattlePuzzle.goal_met(p, {"type": "bond_ready", "value": 0.34}, at))

func test_lesson_texts_are_translated() -> void:
	var de: Dictionary = {}
	for f: String in ["kampf_k36"]:
		de.merge((_read("res://data/i18n/de/%s.json" % f) as Dictionary).get("strings", {}))
	for t: String in ["pathkeeper", "listener"]:
		assert_true(de.has(BattlePuzzle.teacher_title(t)), t)
	for p: Dictionary in BattlePuzzle.lessons():
		for k: String in ["name", "text", "hint_1", "hint_2"]:
			assert_true(de.has(str(p[k])), "%s %s" % [p.id, k])
