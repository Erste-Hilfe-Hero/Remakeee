extends GutTest
## Raid Rifts (plan area 7, items 2847-2851, 2871, 2691) on the local stand-in of the server,
## with real battles checked by the referee. The same rules as tools/online/sql_test/test_raids.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []}]})
	s.switch_user("ben")
	s.call_fn("friend_request", {"p_code": codes.ann})
	s.switch_user("ann")
	s.call_fn("friend_respond", {"p_code": codes.ben, "p_accept": true})
	s.db.flags["raid"] = {"enabled": true, "min_version": 1}
	# One guardian the AI team can always hurt, so the damage checks never depend on the seed.
	s.db.config["raid_guardians"] = ["Cairnhold"]
	# No legendary guardians here, so the strength never depends on the roll (see test_raid_more.gd).
	s.raid_cfg()["legendary_chance"] = 0

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

## Plays the attempt the server set up with the AI, like the game, and sends it in.
func _fight(who: String, raid: int) -> Dictionary:
	var at: Dictionary = _as(who, "raid_start", {"p_raid": raid, "p_pick": ["Kindlop", "Puddlet"]})
	assert_true(bool(at.ok), str(at))
	var snap: Dictionary = BattleReferee.from_expect(at)
	var model: BattleModel = BattleReplay.build_model(snap)
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 300:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			snap.inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var act: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(act))
		model.submit_turn(act)
	assert_lte(model.turn, 10, "at most 10 rounds")
	var r: Dictionary = _as(who, "battle_submit", {"p_kind": "raid", "p_ref": str(at.attempt_id), "p_replay": snap,
		"p_claim": BattleReferee.claim_of(model)})
	assert_true(bool(r.ok), str(r))
	return {"battle": r, "model": model}

func test_only_friends_or_bund_and_the_right_strength() -> void:
	assert_eq(_as("ann", "raid_open", {"p_codes": [codes.cid]}).error, "no_such_code")
	assert_eq(_as("ann", "raid_open", {"p_codes": []}).error, "bad_party")
	var id: int = int(_as("ann", "raid_open", {"p_codes": [codes.ben]}).raid)
	var r: Dictionary = _as("ann", "raid_list").raids[0]
	assert_eq(int(r.id), id)
	assert_eq(int(r.hp_total), 1200)
	assert_eq(int(r.tries_left), 3)
	assert_eq(s.raid_hp(3), 1680)
	assert_eq(s.raid_hp(4), 2100)
	assert_eq(_as("cid", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]}).error, "no_such_raid")

func test_checked_damage_comes_off_and_never_below_zero() -> void:
	var id: int = int(_as("ann", "raid_open", {"p_codes": [codes.ben]}).raid)
	s.referee_waits = true
	var got: Dictionary = _fight("ann", id)
	var dealt: int = 0
	for sp: Spirling in (got.model as BattleModel).parties[1]:
		dealt += sp.max_hp() - sp.hp
	assert_gt(dealt, 0, "the AI team hurts the guardian")
	assert_eq(int(_as("ann", "raid_list").raids[0].hp_left), 1200, "nothing before the check")
	s.referee_run()
	assert_eq(int(_as("ann", "raid_list").raids[0].hp_left), 1200 - mini(dealt, 1200))
	s.db.raids[str(id)].hp_left = 5
	s.referee_waits = false
	_fight("ben", id)
	var r: Dictionary = _as("ben", "raid_list").raids[0]
	assert_eq(int(r.hp_left), 0)
	assert_true(bool(r.won))
	assert_eq(_as("ben", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]}).error, "raid_closed")

func test_tries_rewards_and_a_tampered_claim() -> void:
	var id: int = int(_as("ann", "raid_open", {"p_codes": [codes.ben]}).raid)
	var at: Dictionary = _as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]})
	var snap: Dictionary = BattleReferee.from_expect(at)
	_as("ann", "battle_submit", {"p_kind": "raid", "p_ref": str(at.attempt_id), "p_replay": snap,
		"p_claim": {"winner": "player", "rounds": 1, "hp": [[1], [0]]}})
	assert_eq(int(_as("ann", "raid_list").raids[0].hp_left), 1200, "a mismatch counts nothing")
	_as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]})
	_as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]})
	assert_eq(_as("ann", "raid_start", {"p_raid": id, "p_pick": ["Kindlop"]}).error, "no_tries")
	# Ben and Ann both above 5 % when the guardian falls: the same reward, once.
	s.db.raid_members["%d|%s" % [id, "ann"]].damage = 600
	s.db.raids[str(id)].hp_left = 600
	_fight("ben", id)
	if int(_as("ben", "raid_list").raids[0].hp_left) == 0:
		var a: Dictionary = _as("ann", "raid_claim", {"p_raid": id})
		var b: Dictionary = _as("ben", "raid_claim", {"p_raid": id})
		if bool(b.get("ok", false)):
			assert_eq(a.item, b.item, "same reward for all")
		assert_eq(_as("ann", "raid_claim", {"p_raid": id}).error, "claimed")

func test_round_limit_in_the_model() -> void:
	var snap: Dictionary = BattleReferee.from_expect({"seed": 7, "round_limit": 2, "teams": [
		[{"species": "Puddlet", "level": 5, "moves": []}], [{"species": "Leviarch", "level": 60, "moves": []}]]})
	var model: BattleModel = BattleReplay.build_model(snap)
	assert_eq(model.round_limit, 2)
	model.start()
	var ai := BattleAI.new(1)
	var guard: int = 0
	while not model.is_finished() and guard < 50:
		guard += 1
		if model.needs_player_switch():
			model.submit_switch(model.swap_candidates(BattleModel.Side.PLAYER)[0])
			continue
		model.submit_turn(ai.choose(model, BattleModel.Side.PLAYER))
	assert_true(model.turn <= 2)

func test_deleting_an_account_keeps_the_raid_for_the_others() -> void:
	var id: int = int(_as("ann", "raid_open", {"p_codes": [codes.ben]}).raid)
	_as("ann", "delete_account")
	assert_eq(int(_as("ben", "raid_list").raids[0].id), id)

func test_menu_texts() -> void:
	assert_string_contains(RaidMenu.raid_line({"guardian": "Leviarch", "hp_left": 600, "hp_total": 1200, "open": true,
		"closes_at": 7200}, 0), "600/1200")
	var t: String = RaidMenu.rewards_text([{"item": "max_tonic", "count": 2, "w": 1}], 5)
	assert_string_contains(t, "100%")
