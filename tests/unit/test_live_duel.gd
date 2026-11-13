extends GutTest
## Live duels (Online 100, area 1) on the local stand-in server. The same cases as
## tools/online/sql_test/test_live_duel.sql.

var s: LocalBackend
var codes: Dictionary = {}

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	s.rng.seed = 1
	s.db.flags["live_duel"] = {"enabled": true, "min_version": 1}
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	_as("ann", "team_set", {"p_team": [{"species": "Kindlop", "level": 12}, {"species": "Puddlet", "level": 9},
		{"species": "Zippit", "level": 9}, {"species": "Wickit", "level": 5}]})
	_as("ben", "team_set", {"p_team": [{"species": "Zippit", "level": 20}, {"species": "Kindlop", "level": 15},
		{"species": "Puddlet", "level": 9}]})
	_as("ben", "friend_request", {"p_code": codes.ann})
	_as("ann", "friend_respond", {"p_code": codes.ben, "p_accept": true})

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func test_the_config_is_the_data_file() -> void:
	assert_eq(s.live_cfg(), LiveDuel.config())
	assert_eq(int(LiveDuel.config().turn_seconds), 30)
	assert_eq(LiveDuel.EMOTES.size(), int(LiveDuel.config().emotes))

func test_picks_are_three_distinct_shown_slots() -> void:
	assert_eq(LiveDuel.check_pick([2, 0, 1], 3, 3), [2, 0, 1])
	assert_null(LiveDuel.check_pick([0, 0, 1], 3, 3))
	assert_null(LiveDuel.check_pick([0, 1], 3, 3))
	assert_null(LiveDuel.check_pick([0, 1, 3], 3, 3))
	assert_null(LiveDuel.check_pick([0, 1, 1.5], 3, 3))
	assert_null(LiveDuel.check_pick("x", 3, 3))

func test_a_whole_duel_with_simultaneous_rounds_emotes_and_rematch() -> void:
	assert_eq(_as("ann", "live_invite", {"p_code": codes.cid}).error, "not_friends")
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	assert_eq(_as("ann", "live_answer", {"p_id": id, "p_accept": true}).error, "no_such_duel", "only the friend answers")
	assert_eq(_as("cid", "live_state", {"p_id": id}).error, "no_such_duel")
	var r: Dictionary = _as("ben", "live_answer", {"p_id": id, "p_accept": true})
	assert_eq(r.state, "picking")
	assert_eq((r.show[0] as Array).size(), 4)
	assert_eq(_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 3]}).error, "bad_pick")
	assert_true(bool(_as("ben", "live_pick", {"p_id": id, "p_pick": [2, 0, 1]}).picked[1]))
	assert_eq(_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]}).error, "duel_closed")
	r = _as("ann", "live_pick", {"p_id": id, "p_pick": [3, 1, 0]})
	assert_eq(r.state, "running")
	assert_eq(int(r.round), 1)
	assert_eq(r.teams[0][0].species, "Wickit")
	assert_eq(r.teams[1][0].species, "Puddlet")
	assert_eq(_as("ann", "live_move", {"p_id": id, "p_round": 2, "p_input": {"kind": "move", "slot": 0}}).error, "wrong_round")
	assert_eq(int(_as("ann", "live_move", {"p_id": id, "p_round": 1, "p_input": {"kind": "move", "slot": 0}}).round), 1)
	assert_eq(_as("ann", "live_move", {"p_id": id, "p_round": 1, "p_input": {"kind": "move", "slot": 1}}).error, "already_moved")
	assert_true(bool(_as("ann", "live_emote", {"p_id": id, "p_emote": 2}).ok))
	assert_eq(_as("ann", "live_emote", {"p_id": id, "p_emote": 99}).error, "bad_emote")
	r = _as("ben", "live_move", {"p_id": id, "p_round": 1, "p_input": {"kind": "move", "slot": 2}})
	assert_eq(int(r.round), 2)
	assert_eq(int(r.moves["1"][1].slot), 2)
	assert_eq(int(r.emotes[0].emote), 2)
	# The referee plays the kept rounds (point 3): one round of rests ends nothing, whatever a phone says.
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": 1}).state, "running")
	assert_eq(_as("ann", "live_finish", {"p_id": id, "p_winner": 1}).error, "not_over")
	r = _as("ben", "live_forfeit", {"p_id": id})
	assert_eq(r.state, "done")
	assert_eq(int(r.winner), 0)
	assert_eq(LiveDuel.result_text(0, 1, "played"), "You lose.")
	assert_true(bool(_as("ann", "live_rematch", {"p_id": id}).ok))

func test_timeouts_and_forfeit() -> void:
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	s.clock_offset += 90 + 61
	var r: Dictionary = _as("ann", "live_state", {"p_id": id})
	assert_eq(r.reason, "timeout")
	assert_eq(int(r.winner), 1, "the side that stayed away loses")
	var id2: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	assert_eq(_as("ann", "live_forfeit", {"p_id": id2}).error, "duel_closed", "not before it starts")
	_as("ben", "live_answer", {"p_id": id2, "p_accept": true})
	r = _as("ben", "live_forfeit", {"p_id": id2})
	assert_eq(r.reason, "forfeit")
	assert_eq(int(r.winner), 0)
	s.clock_offset += 11 * 60
	var id3: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	s.clock_offset += 11 * 60
	assert_eq(_as("ben", "live_answer", {"p_id": id3, "p_accept": true}).error, "duel_closed", "invites run out")

func test_the_menu_texts() -> void:
	assert_eq(LiveDuelMenu.actions({"state": "invited", "side": 1}), ["Accept", "Decline"] as Array[String])
	assert_eq(LiveDuelMenu.actions({"state": "picking", "side": 0, "picked": [false, true]}),
		["Pick 3", "Take a borrowed Spirling along", "Give up"] as Array[String])
	assert_eq(LiveDuelMenu.actions({"state": "done", "side": 0}), ["Rematch", "Save a result picture", "Report the rival..."] as Array[String])
	var t: String = LiveDuelMenu.state_text({"state": "running", "side": 0, "round": 3, "deadline": 1020, "emotes": [{"side": 1, "emote": 0}]}, 1000)
	assert_string_contains(t, "20 s")
	assert_string_contains(t, "Hello!")
	assert_eq(LiveDuel.summary(["Kindlop"], [40], [15]), ["Kindlop took 25 damage"] as Array[String])
