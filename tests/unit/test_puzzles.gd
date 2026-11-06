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
		var gl: Array[Dictionary] = BattlePuzzle.goals(p)
		assert_between(gl.size(), 1, BattlePuzzle.MAX_GOALS, str(p.id))
		for g: Dictionary in gl:
			assert_true(str(g.get("type", "")) in BattlePuzzle.GOALS, str(p.id))
		assert_true(str(p.field).is_empty() or BattleRules.FIELDS.has(str(p.field)), str(p.id))
		assert_true(str(p.rule).is_empty() or BattleRules.RULES.has(str(p.rule)), str(p.id))
		for side: String in ["player", "foe"]:
			for e: Dictionary in p[side]:
				assert_not_null(Database.species(str(e.species)), str(e.species))
				for mv: Variant in e.get("moves", []):
					assert_not_null(Database.move(str(mv)), str(mv))
		var m: BattleModel = BattlePuzzle.build_model(p)
		var ally: Array = (p.get("partner", {}) as Dictionary).get("team", [])
		assert_eq(m.party(0).size(), (p.player as Array).size() + ally.size())

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
		# Item 706: the stored fewest turns is what the solver finds.
		assert_eq(int(p.get("best_turns", 0)), int(r.best_turns), "%s best_turns" % p.id)

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

## Plan area 2, items 701-703, 705: the new goal types and the second and third Trials.
func test_new_trials_match_the_plan() -> void:
	var m: BattleModel = BattlePuzzle.build_model(BattlePuzzle.by_id("ember_trial_2"))
	assert_eq(m.active_spirling(0).data.species_name, "Kindlop")
	assert_eq(m.active_spirling(0).status, "scorch")
	assert_eq(m.party(1).size(), 2, "1 against 2")
	m = BattlePuzzle.build_model(BattlePuzzle.by_id("ember_trial_3"))
	assert_eq(m.active_spirling(0).data.species_name, "Mossling")
	assert_lt(m.active_spirling(0).hp, m.active_spirling(0).max_hp())
	var p: Dictionary = BattlePuzzle.by_id("current_trial_2")
	m = BattlePuzzle.build_model(p)
	assert_eq(m.active_spirling(0).energy, 2)
	assert_eq(m.field, "high_tide")
	assert_eq(BattlePuzzle.goals(p).size(), 2)

func test_goal_types() -> void:
	var p: Dictionary = BattlePuzzle.by_id("ember_trial_1")
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	at.rests = 1
	at.cured.append("scorch")
	at.last_move = "Fizz Pop"
	assert_true(BattlePuzzle.goal_met(p, {"type": "exact_rests", "value": 1}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "exact_rests", "value": 0}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "keep_status", "value": "scorch"}, at))
	assert_true(BattlePuzzle.goal_met(p, {"type": "keep_status", "value": "soak"}, at))
	assert_true(BattlePuzzle.goal_met(p, {"type": "last_hit_with", "value": "Fizz Pop"}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "last_hit_with", "value": "Drench"}, at))
	assert_true(BattlePuzzle.goal_met(p, {"type": "no_faint"}, at))
	at.own_faints = 1
	assert_false(BattlePuzzle.goal_met(p, {"type": "no_faint"}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "use_reaction", "value": "VOLT"}, at))
	assert_false(BattlePuzzle.goal_met(p, {"type": "unknown"}, at))

func test_scorch_trial_fails_when_cured() -> void:
	# Resting cures the Scorch, so a rest anywhere in the line breaks the goal.
	var p: Dictionary = BattlePuzzle.by_id("ember_trial_2")
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	BattlePuzzle.play(p, at, BattleAction.make_rest(BattleModel.Side.PLAYER))
	if "scorch" in at.cured:
		while not BattlePuzzle.is_over(p, at):
			BattlePuzzle.play(p, at, BattleAction.make_move(0, 0))
		assert_false(BattlePuzzle.solved(p, at))
	else:
		pass_test("resting does not cure Scorch here")

## Items 704, 706: the tag Trial and the lantern rating.
func test_tag_trial_has_an_ally() -> void:
	var p: Dictionary = BattlePuzzle.by_id("current_trial_3")
	var m: BattleModel = BattlePuzzle.build_model(p)
	assert_eq(m.active_spirling(0).data.species_name, "Riptail")
	assert_eq(m.partner_name, "Cartographer Kestra")
	assert_eq(m.slot_count(1), 2, "2 against 2")
	assert_eq(str(BattlePuzzle.goals(p)[0].type), "no_faint")
	# Single-target arts become one choice per foe.
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	var targets: Dictionary = {}
	for a: BattleAction in BattlePuzzle.choices(at):
		if a.kind == BattleAction.Kind.MOVE:
			targets[a.target_slot] = true
	assert_true(targets.has(0) and targets.has(1))

func test_lanterns() -> void:
	var p: Dictionary = BattlePuzzle.by_id("ember_trial_1")
	var r: Dictionary = BattlePuzzle.search(p)
	var at: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	for d: Dictionary in r.solution:
		BattlePuzzle.play(p, at, BattleReplay.action_from_dict(d))
	assert_gte(BattlePuzzle.lanterns(p, at), 2)
	var slow: Dictionary = p.duplicate(true)
	slow["best_turns"] = at.turns() - 1
	assert_eq(BattlePuzzle.lanterns(slow, at), 2, "slower than the best line")
	slow["best_turns"] = at.turns()
	assert_eq(BattlePuzzle.lanterns(slow, at), 3)
	var lost: BattlePuzzle.Attempt = BattlePuzzle.start(p)
	assert_eq(BattlePuzzle.lanterns(p, lost), 0)
