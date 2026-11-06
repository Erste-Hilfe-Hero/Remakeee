extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 696 to 700): puzzle battles ("Trials").

## Most of all lines of play (weighted by branching) that may win: a Trial has to be found.
const MAX_WIN_SHARE: float = 0.2

func before_all() -> void:
	Database.load_all()

func test_every_puzzle_has_the_fields_and_real_content() -> void:
	var ids: Dictionary = {}
	for p: Dictionary in BattlePuzzle.all():
		for key: String in ["id", "warden", "player", "foe", "field", "rule", "seed", "ai", "goal", "max_turns"]:
			assert_true(p.has(key), "%s has %s" % [p.get("id", "?"), key])
		assert_false(ids.has(p.id), "unique id")
		ids[p.id] = true
		assert_true(str(p.goal.type) in BattlePuzzle.GOALS, str(p.id))
		assert_true(str(p.field).is_empty() or BattleRules.FIELDS.has(str(p.field)), str(p.id))
		assert_true(str(p.rule).is_empty() or BattleRules.RULES.has(str(p.rule)), str(p.id))
		for side: String in ["player", "foe"]:
			for e: Dictionary in p[side]:
				assert_not_null(Database.species(str(e.species)), str(e.species))
				for mv: Variant in e.get("moves", []):
					assert_not_null(Database.move(str(mv)), str(mv))
		var m: BattleModel = BattlePuzzle.build_model(p)
		assert_eq(m.party(0).size(), (p.player as Array).size())

func test_each_warden_offers_three_trials() -> void:
	# Item 697.
	for w: String in ["cinder", "tide"]:
		assert_eq(BattlePuzzle.for_warden(w).size(), 3, w)

func test_the_two_named_trials_match_the_plan() -> void:
	var a: Dictionary = BattlePuzzle.by_id("ember_trial_1")
	var m: BattleModel = BattlePuzzle.build_model(a)
	assert_eq(m.active_spirling(0).data.species_name, "Puddlet")
	assert_eq(m.active_spirling(0).level, 12)
	assert_eq(m.active_spirling(1).data.species_name, "Smoldrake")
	assert_eq(m.field, "ash_storm")
	assert_eq(m.foe_rule, "ember_pulse")
	var b: Dictionary = BattlePuzzle.by_id("current_trial_1")
	m = BattlePuzzle.build_model(b)
	assert_eq(m.active_spirling(0).energy, 4, "Zippit starts with 4 Energy")
	assert_eq(m.active_spirling(1).status, "soak")
	assert_eq(str(b.goal.reaction), "VOLT")

func test_every_trial_is_solvable_but_not_by_chance() -> void:
	# Item 700: a full search over every player choice up to max_turns, with the fixed seed.
	for p: Dictionary in BattlePuzzle.all():
		var r: Dictionary = BattlePuzzle.search(p)
		assert_gt(int(r.wins), 0, "%s has a solution" % p.id)
		assert_lte(float(r.share), MAX_WIN_SHARE, "%s: %d%% of lines win" % [p.id, roundi(float(r.share) * 100.0)])
		# The found line really solves it when played again.
		var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
		for d: Dictionary in r.solution:
			BattlePuzzle.play(p, at, BattleReplay.action_from_dict(d))
		assert_true(BattlePuzzle.solved(p, at), str(p.id))

func test_the_reaction_goal_needs_the_reaction() -> void:
	var p: Dictionary = BattlePuzzle.by_id("current_trial_1").duplicate(true)
	p.foe[0]["status"] = ""
	assert_eq(int(BattlePuzzle.search(p).wins), 0, "without Soak there is no Volt reaction and no solution")

func test_a_trial_leaves_the_party_alone() -> void:
	var before: int = GameState.party.size()
	var p: Dictionary = BattlePuzzle.by_id("ember_trial_1")
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	for i: int in 4:
		BattlePuzzle.play(p, at, BattleAction.make_move(0, 0))
	assert_eq(GameState.party.size(), before)
	for s: Spirling in at.model.party(0):
		assert_false(s in GameState.party)
