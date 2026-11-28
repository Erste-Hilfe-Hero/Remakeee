extends GutTest
## BattleReplay keeps the world's touches on a battle (1.3.2): fog, time of day, spark training,
## growth and an RNG already drawn from. A replay of a battle in fog plays out like the battle.

func before_all() -> void:
	Database.load_all()

func _fog_model(seed_value: int) -> BattleModel:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 12)] as Array[Spirling],
		[BattleFixtures.make("Mossling", 12)] as Array[Spirling], true, seed_value, 0)
	m.sight_mult = 0.5
	return m

## Plays [param m] to the end with a greedy player AI; returns the inputs and fills [param lines].
func _play(m: BattleModel, lines: Array[String]) -> Array:
	var inputs: Array = []
	var ai := BattleAI.new(1)
	_note(m.start(), lines)
	var guard: int = 0
	while not m.is_finished() and guard < 200:
		guard += 1
		if m.needs_player_switch():
			var idx: int = m.swap_candidates(BattleModel.Side.PLAYER)[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			_note(m.submit_switch(idx), lines)
			continue
		var act: BattleAction = ai.choose(m, BattleModel.Side.PLAYER)
		if act.kind != BattleAction.Kind.MOVE:
			act = BattleAction.new()
			act.side = BattleModel.Side.PLAYER
			act.kind = BattleAction.Kind.MOVE
			act.move_index = 0
		inputs.append(BattleReplay.action_to_dict(act))
		_note(m.submit_turn(act), lines)
	return inputs

func _note(events: Array[BattleEvent], lines: Array[String]) -> void:
	for ev: BattleEvent in events:
		lines.append("%d %s" % [ev.type, ev.describe()])

## Replays [param snap] and returns the lines of the played-back battle.
func _replay_log(snap: Dictionary, out: Array) -> Array[String]:
	var lines: Array[String] = []
	var m: BattleModel = BattleReplay.build_model(snap)
	assert_not_null(m)
	_note(m.start(), lines)
	for v: Variant in snap.inputs:
		if m.is_finished():
			break
		var d: Dictionary = v
		if str(d.get("t", "")) == "switch":
			_note(m.submit_switch(int(d.i)), lines)
		else:
			_note(m.submit_turn(BattleReplay.action_from_dict(d)), lines)
	out.append(m)
	return lines

func test_a_battle_in_fog_replays_with_the_same_vigor_and_log() -> void:
	for sd: int in [7, 11, 23]:
		var live: BattleModel = _fog_model(sd)
		var snap: Dictionary = BattleReplay.snapshot(live, "battle", "lake")
		var live_log: Array[String] = []
		snap["inputs"] = _play(live, live_log)
		assert_true(live.is_finished())
		var out: Array = []
		var replay_log: Array[String] = _replay_log(snap, out)
		var again: BattleModel = out[0]
		assert_eq(again.sight_mult, 0.5)
		assert_eq(BattleReferee.claim_of(again), BattleReferee.claim_of(live), "seed %d" % sd)
		assert_eq(replay_log, live_log, "seed %d" % sd)

func test_the_referee_accepts_a_battle_fought_in_fog() -> void:
	var live: BattleModel = _fog_model(5)
	var snap: Dictionary = BattleReplay.snapshot(live, "battle", "lake")
	var lines: Array[String] = []
	snap["inputs"] = _play(live, lines)
	var r: Dictionary = BattleReferee.check(JSON.parse_string(JSON.stringify(snap)), BattleReferee.claim_of(live))
	assert_eq(r.verdict, BattleReferee.OK, str(r))

func test_day_spark_and_growth_go_along() -> void:
	var m: BattleModel = _fog_model(3)
	m.day_phase = DayCycle.Phase.NIGHT
	m.battle_spark_chance = 0.25
	m.xp_mult = 1.5
	m.ring_scaled_growth = true
	var back: BattleModel = BattleReplay.build_model(BattleReplay.snapshot(m, "battle", "lake"))
	assert_eq(back.day_phase, DayCycle.Phase.NIGHT)
	assert_eq(back.battle_spark_chance, 0.25)
	assert_eq(back.xp_mult, 1.5)
	assert_true(back.ring_scaled_growth)

func test_an_rng_already_drawn_from_plays_back_the_same_rolls() -> void:
	var m: BattleModel = _fog_model(9)
	var plain: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	assert_false(plain.has("rng_state"), "a fresh RNG adds no key")
	m.rng.randi()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(BattleReplay.snapshot(m, "battle", "lake")))
	var back: BattleModel = BattleReplay.build_model(snap)
	assert_eq(back.rng.state, m.rng.state)
	assert_eq(back.rng.randi(), m.rng.randi())

func test_an_old_snapshot_without_the_keys_keeps_the_old_defaults() -> void:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 12)] as Array[Spirling],
		[BattleFixtures.make("Mossling", 12)] as Array[Spirling], true, 4, 0)
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	for k: String in ["sight", "day", "spark", "xp_mult", "ring_growth", "rng_state"]:
		assert_false(snap.has(k), k)
	var back: BattleModel = BattleReplay.build_model(snap)
	assert_eq(back.sight_mult, 1.0)
	assert_eq(back.day_phase, -1)
	assert_eq(back.battle_spark_chance, 0.0)
	assert_eq(back.xp_mult, 1.0)
	assert_false(back.ring_scaled_growth)
