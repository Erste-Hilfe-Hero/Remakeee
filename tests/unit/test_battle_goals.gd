extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 755 to 761, 763, 764): bonus goals.

func before_all() -> void:
	Database.load_all()

func _npc(map_id: String, npc_id: String) -> Dictionary:
	var m: MapData = MapData.load_map(map_id)
	for n: Dictionary in m.npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_every_goal_names_a_real_fighter_a_known_type_and_a_plain_reward() -> void:
	assert_gte(BattleGoals.all().size(), 12)
	for k: String in BattleGoals.all():
		var parts: PackedStringArray = k.split("/")
		var def: Dictionary = _npc(parts[0], parts[1])
		assert_false(def.is_empty(), k)
		assert_true(TrainerData.is_trainer(def), "%s fights" % k)
		var g: Dictionary = BattleGoals.all()[k]
		assert_true(str(g.type) in BattleGoals.TYPES, k)
		assert_ne(BattleGoals.describe(g), "", k)
		for r: String in (g.reward as Dictionary):
			assert_true(r in BattleGoals.REWARD_KINDS, "%s: %s is no battle edge" % [k, r])

func test_named_goals_from_the_plan() -> void:
	assert_eq(BattleGoals.goal_for("crowcrest", "lio"), {"type": "win_within", "value": 4.0, "reward": {"shards": 1.0}})
	assert_eq(str(BattleGoals.goal_for("cinder_rift", "warden_orrin").type), "max_fielded")
	assert_eq(str(BattleGoals.goal_for("tide_rift", "mystic").type), "reaction_count")
	assert_eq(BattleGoals.describe(BattleGoals.goal_for("crowcrest", "lio")), "Bonus goal: win within 4 turns.")

func _won(goal: Dictionary, my_moves: Array[String], turns_to_win: int = -1) -> BattleGoals.Tracker:
	var me: Spirling = BattleFixtures.make("Kindlop", 40, my_moves)
	var bench: Spirling = BattleFixtures.make("Puddlet", 40, ["Fizz Pop"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Mossling", 8, ["Bowl Over"] as Array[String])
	var m := BattleModel.new([me, bench] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
	var t := BattleGoals.Tracker.new(m, goal)
	m.start()
	for i: int in maxi(turns_to_win - 1, 0):
		m.submit_turn(BattleAction.make_rest(0), BattleAction.make_rest(1))
	var guard: int = 0
	while not m.is_finished() and guard < 10:
		guard += 1
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_rest(1))
	assert_eq(m.outcome, BattleModel.Outcome.WIN)
	return t

func test_each_goal_type_is_judged_from_the_battle() -> void:
	assert_true(_won({"type": "win_within", "value": 2}, ["Cinder Dash"] as Array[String]).met())
	assert_false(_won({"type": "win_within", "value": 2}, ["Cinder Dash"] as Array[String], 4).met())
	assert_true(_won({"type": "no_rest"}, ["Cinder Dash"] as Array[String]).met())
	assert_false(_won({"type": "no_rest"}, ["Cinder Dash"] as Array[String], 3).met(), "resting breaks it")
	assert_true(_won({"type": "only_kind", "value": "physical"}, ["Cinder Dash"] as Array[String]).met())
	assert_false(_won({"type": "only_kind", "value": "focus"}, ["Cinder Dash"] as Array[String]).met())
	assert_true(_won({"type": "max_fielded", "value": 1}, ["Cinder Dash"] as Array[String]).met())
	assert_true(_won({"type": "no_faint"}, ["Cinder Dash"] as Array[String]).met())
	assert_true(_won({"type": "min_hp_end", "value": 0.5}, ["Cinder Dash"] as Array[String]).met())
	assert_false(_won({"type": "reaction_count", "value": 1}, ["Cinder Dash"] as Array[String]).met(), "no status, no reaction")

func test_a_loss_never_meets_a_goal() -> void:
	var me: Spirling = BattleFixtures.make("Mossling", 5, ["Bowl Over"] as Array[String])
	var foe: Spirling = BattleFixtures.make("Kindlop", 40, ["Cinder Dash"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, 0)
	var t := BattleGoals.Tracker.new(m, {"type": "no_rest"})
	m.start()
	while not m.is_finished():
		m.submit_turn(BattleAction.make_move(0, 0), BattleAction.make_move(1, 0))
	assert_false(t.met())

func test_rewards_pay_once_and_shards_join_into_a_crystal() -> void:
	var rec: Dictionary = {"echo_shards": 4}
	var g: Dictionary = {"type": "no_rest", "reward": {"shards": 2, "title": "Current Rider", "lore": "reactions"}}
	var lines: Array[String] = BattleGoals.grant("tide_rift/x", g, rec)
	assert_gt(lines.size(), 2)
	assert_eq(int(rec.echo_crystals), 1)
	assert_eq(int(rec.echo_shards), 1)
	assert_true((rec.titles as Array).has("Current Rider"))
	assert_true((rec.lexicon as Array).has("reactions"))
	assert_eq(BattleGoals.grant("tide_rift/x", g, rec), [] as Array[String], "item 763: no second reward")
	assert_eq(int(rec.echo_shards), 1)

func test_a_tracker_changes_nothing_in_the_battle() -> void:
	# Item 764: same seed, same story, with or without a goal watching.
	var lines: Array = []
	for watch: bool in [false, true]:
		var me: Spirling = BattleFixtures.make("Kindlop", 20, ["Cinder Dash", "Glow Knuckle"] as Array[String])
		var foe: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
		var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 9, 1)
		if watch:
			BattleGoals.Tracker.new(m, {"type": "no_faint"})
		var log: Array[String] = []
		m.event_emitted.connect(func(e: BattleEvent) -> void: log.append(e.describe()))
		m.start()
		while not m.is_finished():
			m.submit_turn(BattleAction.make_move(0, 0))
		lines.append(log)
	assert_eq(lines[0], lines[1])
