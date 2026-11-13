extends GutTest
## Battle plan (docs/KAMPF_PLAN_1000.md), "Balance-Werkzeuge und Tests": 10,000 turns of random
## legal actions without an error, and echo duels built from broken or hostile online rows.
## Random actions are cheap (no AI search), so the whole run stays within a few seconds.

const TURNS: int = 10000
const MAX_BATTLE_TURNS: int = 400
const POOL: Array[String] = ["Kindlop", "Smoldrake", "Puddlet", "Riptail", "Mossling", "Thornback", "Zippit",
	"Glimmerax", "Shalebat", "Zephlet", "Wickit", "Lumenewt", "Mirkmole", "Kelpup"]

func before_all() -> void:
	Database.load_all()

func _team(rng: RandomNumberGenerator, n: int) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for i: int in n:
		out.append(BattleFixtures.make(POOL[rng.randi_range(0, POOL.size() - 1)], rng.randi_range(5, 60)))
	return out

## Plays [param m] with random legal actions for both of the player's slots. Returns turns played.
func _play_random(m: BattleModel, rng: RandomNumberGenerator, label: String) -> int:
	var turns: int = 0
	while not m.is_finished() and turns < MAX_BATTLE_TURNS:
		if m.needs_player_switch():
			var c: Array[int] = m.swap_candidates(0, m.switch_slot())
			m.submit_switch(c[rng.randi_range(0, c.size() - 1)])
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			var legal: Array[BattleAction] = m.legal_actions(0, slot)
			assert_false(legal.is_empty(), "%s: a slot always has an action" % label)
			var a: BattleAction = legal[rng.randi_range(0, legal.size() - 1)]
			if a.kind == BattleAction.Kind.RUN or a.kind == BattleAction.Kind.BOND:
				a = BattleAction.make_rest(0, slot)
			acts.append(a)
		m.submit_actions(acts)
		turns += 1
		for side: int in 2:
			for s: Spirling in m.party(side):
				if s.hp < 0 or s.hp > s.max_hp() or s.energy < 0 or s.energy > Spirling.MAX_ENERGY:
					fail_test("%s turn %d: %s out of range (HP %d/%d, Energy %d)" % [label, turns, s.display_name(), s.hp, s.max_hp(), s.energy])
					return turns
	return turns

func test_ten_thousand_random_turns_without_an_error() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 10000
	var fields: Array = [""] + BattleRules.FIELDS.keys()
	var total: int = 0
	var battles: int = 0
	var finished: int = 0
	while total < TURNS:
		var mine: Array[Spirling] = _team(rng, rng.randi_range(1, 5))
		var theirs: Array[Spirling] = _team(rng, rng.randi_range(1, 5))
		var wild: bool = rng.randf() < 0.4
		var m := BattleModel.new(mine, theirs, wild, rng.randi(), rng.randi_range(0, 3))
		m.front_size = [rng.randi_range(1, mini(2, mine.size())), rng.randi_range(1, mini(2, theirs.size()))]
		m.field = str(fields[rng.randi_range(0, fields.size() - 1)])
		if not wild and rng.randf() < 0.2:
			m.foe_boss = BattleRules.BOSSES.keys()[rng.randi_range(0, BattleRules.BOSSES.size() - 1)]
			m.front_size[1] = 1
		m.start()
		total += _play_random(m, rng, "battle %d" % battles)
		finished += 1 if m.is_finished() else 0
		battles += 1
	assert_true(total >= TURNS)
	assert_true(finished >= battles * 0.9, "%d of %d random battles end" % [finished, battles])

## Rows an online echo might bring: good, unknown, wrong types, absurd numbers, junk moves.
func _hostile_rows(rng: RandomNumberGenerator) -> Array:
	var rows: Array = []
	for i: int in rng.randi_range(0, 7):
		match rng.randi_range(0, 6):
			0:
				rows.append({"species": POOL[rng.randi_range(0, POOL.size() - 1)], "level": rng.randi_range(1, 100), "moves": []})
			1:
				rows.append({"species": "NoSuchKind%d" % i, "level": 30})
			2:
				rows.append({"species": POOL[0], "level": -50, "moves": ["Not An Art", 42, null]})
			3:
				rows.append({"species": POOL[1], "level": 1e12, "moves": "Ember Snap"})
			4:
				rows.append("not a row")
			5:
				rows.append({"species": null, "level": "high"})
			_:
				rows.append({"species": POOL[2], "level": 20, "moves": [Database.moves.keys()[0]] as Array})
	return rows

func test_echo_duels_survive_hostile_rows_and_replay_exactly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	var played: int = 0
	for b: int in 40:
		var foes: Array[Spirling] = EchoTeam.build(_hostile_rows(rng), Spirling.STORY_RING, EchoTeam.DUEL_LEVEL if rng.randf() < 0.5 else 0)
		for s: Spirling in foes:
			assert_between(s.level, 1, Spirling.STORY_RING, "echo %d: levels are clamped" % b)
			assert_false(s.moves.is_empty(), "echo %d: every echo knows an art" % b)
		if foes.is_empty():
			continue
		var mine: Array[Spirling] = EchoTeam.duel_copy(_team(rng, rng.randi_range(1, 3)))
		var m := BattleModel.new(mine, foes, false, rng.randi(), EchoTeam.DUEL_AI)
		var snap: Dictionary = BattleReplay.snapshot(m, "", "")
		m.start()
		var inputs: Array = []
		var turns: int = 0
		while not m.is_finished() and turns < MAX_BATTLE_TURNS:
			if m.needs_player_switch():
				var c: Array[int] = m.swap_candidates(0, m.switch_slot())
				var pick: int = c[rng.randi_range(0, c.size() - 1)]
				inputs.append(BattleReplay.switch_to_dict(pick))
				m.submit_switch(pick)
				continue
			var legal: Array[BattleAction] = m.legal_actions(0, 0)
			var a: BattleAction = legal[rng.randi_range(0, legal.size() - 1)]
			if a.kind == BattleAction.Kind.RUN or a.kind == BattleAction.Kind.BOND:
				a = BattleAction.make_rest(0, 0)
			var acts: Array[BattleAction] = [a]
			inputs.append(BattleReplay.actions_to_dict(acts))
			m.submit_actions(acts)
			turns += 1
		snap.inputs = inputs
		assert_eq(BattleReplay.simulate(snap), m.outcome, "echo %d: the referee replays the same result" % b)
		played += 1
	assert_true(played >= 20, "most hostile rows still give an echo to fight")
