extends GutTest
## Battle referee (plan area 7, items 2687-2691): plays a battle again from its replay and
## compares winner, Vigor left and rounds with the claim. Same code on the server.

func before_all() -> void:
	Database.load_all()

## A finished battle, its replay (through JSON, as it travels) and the honest claim.
func _battle(seed_value: int = 4242) -> Array:
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 14), Spirling.new(Database.species("Puddlet"), 12)]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 13), Spirling.new(Database.species("Zippit"), 13)]
	var model := BattleModel.new(mine, foes, false, seed_value, 1)
	var snap: Dictionary = BattleReplay.snapshot(model, "battle", "field")
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 200:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var a: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
	var claim: Dictionary = BattleReferee.claim_of(model)
	return [JSON.parse_string(JSON.stringify(snap)), JSON.parse_string(JSON.stringify(claim)), model]

func test_an_honest_battle_is_ok() -> void:
	var b: Array = _battle()
	var r: Dictionary = BattleReferee.check(b[0], b[1])
	assert_eq(r.verdict, BattleReferee.OK, str(r))
	assert_eq(int(r.detail.rounds), (b[2] as BattleModel).turn)

func test_every_changed_value_is_a_mismatch() -> void:
	var b: Array = _battle()
	var claim: Dictionary = b[1]
	var wrong_winner: Dictionary = claim.duplicate(true)
	wrong_winner.winner = "foe" if claim.winner == "player" else "player"
	assert_eq(BattleReferee.check(b[0], wrong_winner).detail.field, "winner")
	var wrong_rounds: Dictionary = claim.duplicate(true)
	wrong_rounds.rounds = int(claim.rounds) + 1
	assert_eq(BattleReferee.check(b[0], wrong_rounds).detail.field, "rounds")
	for side: int in 2:
		var wrong_hp: Dictionary = claim.duplicate(true)
		wrong_hp.hp[side][0] = int(wrong_hp.hp[side][0]) + 1
		var r: Dictionary = BattleReferee.check(b[0], wrong_hp)
		assert_eq(r.verdict, BattleReferee.MISMATCH)
		assert_eq(r.detail.field, "hp")
		assert_eq(int(r.detail.side), side)
	var short: Dictionary = claim.duplicate(true)
	(short.hp[1] as Array).pop_back()
	assert_eq(BattleReferee.check(b[0], short).verdict, BattleReferee.MISMATCH, "one Spirling missing")

func test_changed_inputs_or_seed_are_caught() -> void:
	var b: Array = _battle()
	var other_seed: Dictionary = (b[0] as Dictionary).duplicate(true)
	other_seed.seed = 1
	var other_teams: Dictionary = (b[0] as Dictionary).duplicate(true)
	other_teams.teams[0][0].level = 40
	var verdicts: Array = [BattleReferee.check(other_seed, b[1]).verdict, BattleReferee.check(other_teams, b[1]).verdict]
	assert_true(verdicts.has(BattleReferee.MISMATCH), "a stronger team or another seed changes the result: %s" % str(verdicts))
	assert_eq(BattleReferee.check(other_teams, b[1]).verdict, BattleReferee.MISMATCH)
	var cut: Dictionary = (b[0] as Dictionary).duplicate(true)
	cut.inputs = []
	assert_eq(BattleReferee.check(cut, b[1]).detail.field, "unfinished")

func test_broken_uploads_are_errors_not_crashes() -> void:
	var b: Array = _battle()
	assert_eq(BattleReferee.check("x", b[1]).verdict, BattleReferee.ERROR)
	assert_eq(BattleReferee.check({}, b[1]).verdict, BattleReferee.ERROR)
	assert_eq(BattleReferee.check({"teams": [[1], [2]]}, b[1]).verdict, BattleReferee.ERROR)
	assert_eq(BattleReferee.check({"teams": [[{"species": "Nobody"}], [{"species": "Puddlet"}]]}, b[1]).verdict, BattleReferee.ERROR)
	var many: Dictionary = (b[0] as Dictionary).duplicate(true)
	for i: int in BattleReferee.MAX_INPUTS + 1:
		many.inputs.append({"t": "turn"})
	assert_eq(BattleReferee.check(many, b[1]).detail.reason, "inputs")
	var bad_input: Dictionary = (b[0] as Dictionary).duplicate(true)
	bad_input.inputs = [5]
	assert_eq(BattleReferee.check(bad_input, b[1]).detail.reason, "inputs")
	var bad_front: Dictionary = (b[0] as Dictionary).duplicate(true)
	bad_front.front = [1]
	assert_eq(BattleReferee.check(bad_front, b[1]).detail.reason, "front")
	assert_eq(BattleReferee.check(b[0], "x").verdict, BattleReferee.ERROR)

func test_local_server_judges_like_the_real_one() -> void:
	var s := LocalBackend.new()
	s.switch_user("ann")
	s.call_fn("hello", {"p_version": 1})
	var b: Array = _battle()
	assert_eq(s.call_fn("battle_submit", {"p_kind": "cheat", "p_ref": "", "p_replay": b[0], "p_claim": b[1]}).data.error, "bad_kind")
	assert_eq(s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_ref": "", "p_replay": [], "p_claim": b[1]}).data.error, "bad_battle")
	s.referee_waits = true
	var r: Dictionary = s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_ref": "X", "p_replay": b[0], "p_claim": b[1]}).data
	assert_eq(r.status, "pending")
	var id: int = int(r.battle_id)
	assert_eq(s.call_fn("battle_status", {"p_battle_id": id}).data.status, "pending", "being checked")
	assert_false(s.battle_ok(id), "nothing counts before the referee")
	var bad_claim: Dictionary = (b[1] as Dictionary).duplicate(true)
	bad_claim.rounds = 999
	var id2: int = int(s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_ref": "X", "p_replay": b[0], "p_claim": bad_claim}).data.battle_id)
	assert_eq(s.referee_run(), 2)
	assert_eq(s.call_fn("battle_status", {"p_battle_id": id}).data.status, "ok")
	assert_eq(s.call_fn("battle_status", {"p_battle_id": id2}).data.status, "mismatch")
	assert_true(s.battle_ok(id))
	assert_false(s.battle_ok(id2))
	s.switch_user("ben")
	assert_eq(s.call_fn("battle_status", {"p_battle_id": id}).data.error, "no_such_battle", "only the owner sees it")
	s.switch_user("ann")
	s.call_fn("delete_account")
	assert_true((s.db.get("battles", {}) as Dictionary).is_empty(), "deleting the account removes the battles")

func test_submit_limit_per_hour() -> void:
	var s := LocalBackend.new()
	s.switch_user("ann")
	s.db.config.battle_submit_limit = 2
	var replay: Dictionary = {"teams": [[{}], [{}]]}
	assert_true(bool(s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_replay": replay, "p_claim": {}}).data.ok))
	assert_true(bool(s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_replay": replay, "p_claim": {}}).data.ok))
	assert_eq(s.call_fn("battle_submit", {"p_kind": "echo_duel", "p_replay": replay, "p_claim": {}}).data.error, "slow_down")
