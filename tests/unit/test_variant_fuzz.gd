extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, item 798): every rule variant plays 20
## random team battles without a crash and without running into the 60-round limit.

const BATTLES: int = 20
const ROUND_LIMIT: int = 60
const LEVEL: int = 20

func before_all() -> void:
	Database.load_all()

## Plays one random 3-against-3 battle under [param ids]; returns the rounds it took (-1 if unfinished).
func _battle(ids: Array[String], rng: RandomNumberGenerator, pool: Array[String]) -> int:
	var teams: Array[Array] = [[], []]
	for side: int in 2:
		for n: int in 3:
			teams[side].append(Spirling.new(Database.species(pool[rng.randi() % pool.size()]), LEVEL, rng))
	var mine: Array[Spirling] = []
	mine.assign(teams[0])
	var theirs: Array[Spirling] = []
	theirs.assign(teams[1])
	var m := BattleModel.new(mine, theirs, false, rng.randi(), 2)
	m.items_allowed = false
	m.variants = ids
	var brain := BattleAI.new(2)
	m.start()
	var steps: int = 0
	while not m.is_finished() and m.turn < ROUND_LIMIT and steps < ROUND_LIMIT * 4:
		steps += 1
		if m.needs_player_switch():
			m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
			continue
		m.submit_turn(brain.choose(m, BattleModel.Side.PLAYER))
	return m.turn if m.is_finished() else -1

func test_every_variant_survives_twenty_random_battles() -> void:
	var pool: Array[String] = BalanceSim.valid_species(LEVEL)
	assert_gt(pool.size(), 5)
	for id: String in BattleRules.variants():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		var longest: int = 0
		var unfinished: int = 0
		for b: int in BATTLES:
			var rounds: int = _battle([id] as Array[String], rng, pool)
			if rounds < 0:
				unfinished += 1
			longest = maxi(longest, rounds)
		assert_eq(unfinished, 0, "%s: %d of %d battles hit the %d-round limit" % [id, unfinished, BATTLES, ROUND_LIMIT])
		gut.p("%s: longest battle %d rounds" % [id, longest])
