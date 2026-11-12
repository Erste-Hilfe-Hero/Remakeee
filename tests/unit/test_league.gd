extends GutTest
## Leagues (plan area 7, items 2730-2735, 2748, 2753-2755, 2769-2772, 2786, 2691) on the local
## stand-in of the server. The same cases as tools/online/sql_test/test_league.sql.

var s: LocalBackend
var ann_code: String
var ben_code: String

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	s.switch_user("ben")
	ben_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 60, "moves": ["Kiln Strike", "Cinder Breath"]},
		{"species": "Smoldrake", "level": 40, "moves": []}]})
	s.switch_user("ann")
	ann_code = s.call_fn("hello", {"p_version": 1}).data.profile.code
	s.call_fn("team_set", {"p_team": [{"species": "Kindlop", "level": 12, "moves": ["Bowl Over"]},
		{"species": "Puddlet", "level": 9, "moves": []}]})

func _call(fn: String, args: Dictionary = {}) -> Variant:
	return s.call_fn(fn, args).data

func test_glicko_matches_the_reference_values() -> void:
	var r: Dictionary = Glicko.rate(1500, 350, 0.06, 1500, 350, 1)
	assert_almost_eq(float(r.rating), 1662.311, 0.01)
	assert_almost_eq(float(r.rd), 290.319, 0.01)
	assert_almost_eq(float(Glicko.rate(1500, 350, 0.06, 1500, 350, 0).rating), 1337.689, 0.01)
	r = Glicko.rate(1500, 200, 0.06, 1400, 30, 1)
	assert_almost_eq(float(r.rating), 1563.564, 0.01)
	assert_almost_eq(float(r.rd), 175.403, 0.01)
	r = Glicko.rate(1700, 80, 0.06, 1300, 100, 0)
	assert_almost_eq(float(r.rating), 1668.426, 0.01)
	assert_almost_eq(float(r.vol), 0.0600085, 0.00001)

func test_tiers_show_names_not_numbers() -> void:
	assert_eq(LeagueRules.tier(1500), 4)
	assert_eq(LeagueRules.tier(900), 0)
	assert_eq(LeagueRules.tier(3000), 14)
	assert_eq(LeagueRules.tier(1269.9), 0)
	assert_eq(LeagueRules.tier(1270), 1)
	assert_eq(LeagueRules.tier_name(0), "Spark I")
	assert_eq(LeagueRules.tier_name(4), "Ember II")
	assert_eq(LeagueRules.tier_name(14), "Beacon III")

func test_fair_rows_use_ring_50_and_learnable_moves_only() -> void:
	assert_true(LeagueRules.learnable(Database.species("Kindlop"), 50).has("Kiln Strike"))
	assert_false(LeagueRules.learnable(Database.species("Kindlop"), 19).has("Kiln Strike"))
	assert_true(LeagueRules.learnable(Database.species("Smoldrake"), 9).has("Dusk Rake"), "earlier form moves count")
	assert_eq(LeagueRules.fair_row("Kindlop", ["Kiln Strike", "Fly Away", "Bowl Over", "Kiln Strike"]),
		{"species": "Kindlop", "level": 50, "moves": ["Kiln Strike", "Bowl Over"]})
	# Without a pick the row takes the default kit at ring 50 (plan area 2 added Glow Knuckle to it,
	# the art set of docs/CONTENT_GAPS.md Smoulder at ring 46).
	assert_eq(LeagueRules.fair_row("Kindlop", []).moves, ["Glow Knuckle", "Cinder Breath", "Kiln Strike", "Smoulder"])

func test_joining_errors_and_same_fair_values_for_everyone() -> void:
	assert_eq(_call("league_join", {"p_league": "gold", "p_pick": []}).error, "bad_league")
	assert_eq(_call("league_join", {"p_league": "fair", "p_pick": []}).error, "empty_team")
	assert_eq(_call("league_join", {"p_league": "fair", "p_pick": ["Nobody"]}).error, "unknown_species")
	assert_eq(_call("league_join", {"p_league": "fair", "p_pick": ["Smoldrake"]}).error, "not_in_team")
	assert_eq(_call("league_join", {"p_league": "fair", "p_pick": ["Kindlop", "Kindlop"]}).error, "duplicate_species")
	assert_eq(_call("league_find", {"p_league": "fair", "p_waited": 0}).error, "not_joined")
	var pick: Array = [{"species": "Kindlop", "moves": ["Kiln Strike", "Cinder Breath"]}]
	var ta: Array = _call("league_join", {"p_league": "fair", "p_pick": pick}).team
	s.switch_user("ben")
	var tb: Array = _call("league_join", {"p_league": "fair", "p_pick": pick}).team
	assert_eq(ta[0], tb[0], "same Spirling, other account and Ring: same fair values (2735)")
	assert_eq(int(ta[0].level), 50)
	# The open league keeps the real Ring (2754).
	assert_eq(int(_call("league_join", {"p_league": "open", "p_pick": ["Kindlop"]}).team[0].level), 60)
	var info: Dictionary = _call("league_info", {"p_league": "fair"})
	assert_true(bool(info.joined))
	assert_eq(int(info.tier), 4)
	assert_eq(info.state, "running")

func _both_join(league: String = "fair") -> void:
	s.switch_user("ben")
	_call("league_join", {"p_league": league, "p_pick": ["Kindlop"]})
	s.switch_user("ann")
	_call("league_join", {"p_league": league, "p_pick": ["Kindlop"]})

## Plays the league battle the server set up, with the AI on both sides, like the game would.
func _play(found: Dictionary) -> Array:
	var expect: Dictionary = {"seed": found.seed, "teams": found.teams, "ai": found.ai, "front": [1, 1], "items_allowed": false}
	var snap: Dictionary = BattleReferee.from_expect(expect)
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
	return [snap, BattleReferee.claim_of(model)]

func test_search_widens_and_a_checked_battle_moves_the_rating() -> void:
	_both_join()
	var f: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 0})
	assert_true(bool(f.found))
	assert_eq(int(f.range), 100)
	assert_eq(int(_call("league_find", {"p_league": "fair", "p_waited": 25}).range), 200)
	assert_eq(int(_call("league_find", {"p_league": "fair", "p_waited": 999}).range), 400)
	f = _call("league_find", {"p_league": "fair", "p_waited": 0})
	var played: Array = _play(f)
	assert_eq(_call("battle_submit", {"p_kind": "league_fair", "p_ref": "999", "p_replay": played[0], "p_claim": played[1]}).error, "no_such_match")
	s.referee_waits = true
	var r: Dictionary = _call("battle_submit", {"p_kind": "league_fair", "p_ref": str(f.match_id), "p_replay": played[0], "p_claim": played[1]})
	assert_true(bool(r.ok))
	assert_eq(_call("battle_submit", {"p_kind": "league_fair", "p_ref": str(f.match_id), "p_replay": played[0], "p_claim": played[1]}).error,
		"match_closed", "one battle per match")
	assert_eq(int(_call("league_info", {"p_league": "fair"}).games), 0, "nothing counts before the referee")
	s.referee_run()
	assert_eq(_call("battle_status", {"p_battle_id": r.battle_id}).status, "ok")
	var info: Dictionary = _call("league_info", {"p_league": "fair"})
	assert_eq(int(info.games), 1)
	var won: bool = played[1].winner == "player"
	assert_eq(int(info.wins), 1 if won else 0)
	var e: Dictionary = s.league_entry("fair", int(info.season), "ann")
	assert_almost_eq(float(e.rating), 1662.311 if won else 1337.689, 0.01)
	assert_eq(float(s.league_entry("fair", int(info.season), "ben").rating), 1500.0, "the echo owner is not rated")
	assert_null(s.league_entry("open", int(info.season), "ann"), "leagues are separate")

func test_a_changed_team_never_counts() -> void:
	_both_join()
	var f: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 0})
	var played: Array = _play(f)
	# A cheater uploads a stronger team; the referee uses the server's teams and seed instead.
	var forged: Dictionary = (played[0] as Dictionary).duplicate(true)
	forged.teams[0][0].level = 60
	forged.seed = 1
	var claim: Dictionary = (played[1] as Dictionary).duplicate(true)
	claim["expect"] = {"seed": 1}
	var r: Dictionary = _call("battle_submit", {"p_kind": "league_fair", "p_ref": str(f.match_id), "p_replay": forged, "p_claim": claim})
	assert_eq(_call("battle_status", {"p_battle_id": r.battle_id}).status, "ok", "judged on the server's battle, so the honest claim holds")
	var f2: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 999})
	var p2: Array = _play(f2)
	var lie: Dictionary = (p2[1] as Dictionary).duplicate(true)
	lie.winner = "foe" if lie.winner == "player" else "player"
	var games_before: int = int(_call("league_info", {"p_league": "fair"}).games)
	r = _call("battle_submit", {"p_kind": "league_fair", "p_ref": str(f2.match_id), "p_replay": p2[0], "p_claim": lie})
	assert_eq(_call("battle_status", {"p_battle_id": r.battle_id}).status, "mismatch")
	assert_eq(int(_call("league_info", {"p_league": "fair"}).games), games_before, "a mismatch is not rated")

func test_closing_time_paused_seasons_and_new_seasons() -> void:
	_both_join()
	var sn: Dictionary = s.league_season()
	sn.ends_at = s.now() + 600
	assert_eq(_call("league_info", {"p_league": "fair"}).state, "closing")
	var f: Dictionary = _call("league_find", {"p_league": "fair", "p_waited": 0})
	assert_false(bool(f.rated))
	var played: Array = _play(f)
	_call("battle_submit", {"p_kind": "league_fair", "p_ref": str(f.match_id), "p_replay": played[0], "p_claim": played[1]})
	assert_eq(int(_call("league_info", {"p_league": "fair"}).games), 0, "the last 30 minutes are not rated")
	sn.state = "paused"
	assert_eq(_call("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]}).error, "season_paused")
	sn.state = "running"
	sn.ends_at = s.now() - 1
	var info: Dictionary = _call("league_info", {"p_league": "fair"})
	assert_false(bool(info.joined), "a new season starts by itself")
	assert_eq(int(info.season), int(sn.id) + 1)

func test_blocked_players_never_meet_and_flags_switch_leagues_off() -> void:
	_both_join()
	_call("block", {"p_code": ben_code})
	assert_false(bool(_call("league_find", {"p_league": "fair", "p_waited": 30}).found))
	s.db.flags.league_open = {"enabled": false, "min_version": 1}
	assert_eq(_call("league_info", {"p_league": "open"}).error, "feature_off")

func test_delete_account_removes_league_rows() -> void:
	_both_join()
	_call("league_find", {"p_league": "fair", "p_waited": 0})
	s.call_fn("delete_account")
	assert_true((s.db.league_fair as Dictionary).keys().all(func(k: String) -> bool: return not k.ends_with("|ann")))
	assert_true((s.db.league_matches as Dictionary).is_empty())
