extends GutTest
## Plan area 7, items 2669-2674, on the local stand-in of the server. The same cases as
## tools/online/sql_test/test_rules.sql, with the same error codes.

var s: LocalBackend
var ann_code: String
var ben_code: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.switch_user("ben")
	ben_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.switch_user("ann")
	ann_code = s.call_fn("hello", {"p_version": 1}).data.profile.code

func _put(slot: int, data: Variant) -> Dictionary:
	return s.call_fn("save_put", {"p_slot": slot, "p_data": data, "p_summary": "", "p_base_rev": 0}).data

func _befriend() -> void:
	s.switch_user("ann")
	s.call_fn("friend_request", {"p_code": ben_code})
	s.switch_user("ben")
	s.call_fn("friend_respond", {"p_code": ann_code, "p_accept": true})

func test_saves_follow_the_real_game_limits() -> void:
	assert_true(bool(_put(1, {"schema": 1, "party": [{"level": 60}, {"level": 1}, {}, {}, {}]}).ok), "team of 5 on Ring 60")
	assert_eq(_put(2, {"schema": 1, "party": [{}, {}, {}, {}, {}, {}]}).error, "implausible", "six in the team")
	assert_eq(_put(2, {"schema": 1, "party": [{"level": 10000}]}).error, "implausible", "Ring 10000, above the save_level_max sanity bound")
	assert_eq(_put(2, {"schema": 1, "party": [{"level": 0}]}).error, "implausible", "Ring 0")
	assert_eq(_put(2, {"schema": 1, "storage": [{"level": 10000}]}).error, "implausible", "storage Ring 10000")
	assert_eq(_put(2, {"schema": 1, "storage": {"a": 1}}).error, "implausible", "storage not a list")
	assert_eq(LocalBackend.save_ok({"party": [{}, {}, {}, {}, {}]}), true)
	assert_eq(LocalBackend.save_ok({"party": [{}, {}, {}, {}, {}, {}]}), false)

func test_saves_need_a_schema_number() -> void:
	assert_eq(_put(2, {"party": []}).error, "schema", "missing")
	assert_eq(_put(2, {"schema": 2, "party": []}).error, "schema", "too new")
	assert_eq(_put(2, {"schema": 0, "party": []}).error, "schema", "zero")
	assert_eq(_put(2, {"schema": 1.5, "party": []}).error, "schema", "not whole")
	assert_eq(_put(2, {"schema": "1", "party": []}).error, "schema", "text")
	assert_true(bool(_put(2, {"schema": 1.0, "party": []}).ok), "JSON numbers come back as floats")
	s.db.config.save_schema_max = 2
	assert_true(bool(_put(3, {"schema": 2, "party": []}).ok), "allowed after a server change")

func test_the_game_sends_its_schema_with_every_save() -> void:
	var old_backend: OnlineBackend = Online.backend
	var old_state: Online.State = Online.state
	Online.backend = s
	Online.state = Online.State.ONLINE
	SaveManager.set_slot(1)
	GameState.new_game(GameState.Difficulty.TAMER, "Ann", 0, "Kindlop")
	SaveManager.save_game()
	assert_true(await Online.push(1, true), "upload accepted")
	var got: Dictionary = s.call_fn("save_get", {"p_slot": 1}).data
	assert_eq(int(got.data.schema), Online.SAVE_SCHEMA)
	Online.backend = old_backend
	Online.state = old_state

func test_echo_teams_follow_the_limits_and_duels_use_the_server_ring() -> void:
	_befriend()
	s.switch_user("ben")
	s.call_fn("team_set", {"p_team": [{"species": "Puddlet", "level": 80}, {}, {}, {}, {}, {"species": "Sixth"}]})
	s.switch_user("ann")
	var t: Dictionary = s.call_fn("friend_team", {"p_code": ben_code}).data
	assert_eq((t.team as Array).size(), 5)
	assert_eq(int(t.team[0].level), 60)
	assert_eq(int(t.duel_ring), 50)
	assert_eq(EchoTeam.duel_ring(t), 50)
	s.db.config.duel_ring = 40
	t = s.call_fn("friend_team", {"p_code": ben_code}).data
	assert_eq(EchoTeam.duel_ring(t), 40, "Ali changes the Ring on the server, no app update")
	assert_eq(EchoTeam.duel_ring({}), EchoTeam.DUEL_LEVEL, "fallback when an old server sends nothing")
	assert_eq(EchoTeam.duel_ring({"duel_ring": 500}), Spirling.STORY_RING, "kept inside the game's limits")

func test_players_are_wanderers() -> void:
	assert_eq(LocalBackend.clean_name("", "ABCDEFGH"), "Wanderer EFGH")
	var p: Dictionary = s.call_fn("profile_set", {"p_name": "B1tch", "p_color": 0, "p_favorite": "", "p_card": {}}).data
	assert_eq(p.name, "Wanderer " + ann_code.right(4))
	s.switch_user("new")
	assert_eq(s.profile_of("new").name, "Wanderer")

func test_feature_flags_are_off_until_switched_on() -> void:
	for key: String in ["live_duel", "trade", "bund", "raid"]:
		assert_false(s.flag_on(key, 99), key)
	assert_false(s.flag_on("nothing", 99))
	assert_true(s.flag_on("league_fair", 1), "leagues are on since the league migration")
	s.db.flags.trade = {"enabled": true, "min_version": 5}
	assert_true(s.flag_on("trade", 5))
	assert_false(s.flag_on("trade", 4), "version gate")
