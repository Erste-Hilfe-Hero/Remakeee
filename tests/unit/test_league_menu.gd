extends GutTest
## The league menu and league battle in the game (plan area 7, items 2675, 2730, 2753, 2691).

var _old_backend: OnlineBackend
var _old_state: Online.State
var _old_flags: Array[String]
var _old_party: Array[Spirling]
var _server: LocalBackend

func before_all() -> void:
	Database.load_all()
	_old_backend = Online.backend
	_old_state = Online.state
	_old_flags = Online.flags.duplicate()
	_old_party = GameState.party.duplicate()

func after_all() -> void:
	Online.backend = _old_backend
	Online.state = _old_state
	Online.flags = _old_flags
	GameState.party = _old_party

func before_each() -> void:
	_server = LocalBackend.new()
	# Fixed seed: the fake server's codes, ids and battle seeds come from its rng.
	_server.rng.seed = 1
	Online.backend = _server
	Online.state = Online.State.ONLINE
	GameState.party = [Spirling.new(Database.species("Kindlop"), 60), Spirling.new(Database.species("Puddlet"), 9),
		Spirling.new(Database.species("Kindlop"), 20)] as Array[Spirling]

func test_hello_lists_the_switched_on_features() -> void:
	_server.switch_user("ann")
	var r: Dictionary = await Online.backend.call_fn("hello", {"p_version": 1})
	assert_eq(r.data.flags, ["league_fair", "league_open"])
	_server.db.flags.trade = {"enabled": true, "min_version": 3}
	assert_false((_server.active_flags(2) as Array).has("trade"))
	assert_true((_server.active_flags(3) as Array).has("trade"))
	Online._take_hello(r.data)
	assert_true(Online.league_on())
	assert_eq(LeagueMenu.shown_leagues(), ["fair", "open"] as Array[String], "fair league first, open right below")

func test_switched_off_leagues_are_hidden() -> void:
	Online.flags.assign(["league_open"])
	assert_eq(LeagueMenu.shown_leagues(), ["open"] as Array[String])
	Online.flags.clear()
	assert_false(Online.league_on(), "no Leagues entry in the menu")

func test_the_fair_league_says_bought_advantages_do_not_count() -> void:
	var text: String = LeagueMenu.status_text("fair", {"joined": true, "tier": 4, "games": 3, "wins": 2, "ring": 50, "state": "running"})
	assert_string_contains(text, LeagueMenu.FAIR_TEXT)
	assert_string_contains(text, "Ember II")
	assert_string_contains(text, "Ring 50")
	assert_string_contains(LeagueMenu.status_text("open", {"joined": false, "state": "closing"}), "do not count")

func test_the_pick_holds_each_kind_once_and_no_stats() -> void:
	var pick: Array = LeagueMenu.pick_of(GameState.party)
	assert_eq(pick.size(), 2)
	assert_eq(pick[0].species, "Kindlop")
	assert_false((pick[0] as Dictionary).has("level"), "the server picks the Ring")

func test_a_found_league_battle_plays_like_the_referee_replays_it() -> void:
	_server.switch_user("ben")
	await Online.backend.call_fn("hello", {"p_version": 1})
	await Online.backend.call_fn("team_set", {"p_team": EchoTeam.snapshot(GameState.party)})
	await Online.backend.call_fn("league_join", {"p_league": "fair", "p_pick": ["Kindlop"]})
	_server.switch_user("ann")
	await Online.backend.call_fn("hello", {"p_version": 1})
	await Online.backend.call_fn("team_set", {"p_team": EchoTeam.snapshot(GameState.party)})
	var j: Dictionary = await Online.backend.call_fn("league_join", {"p_league": "fair", "p_pick": LeagueMenu.pick_of(GameState.party)})
	assert_eq(int(j.data.team[0].level), 50)
	var f: Dictionary = (await Online.backend.call_fn("league_find", {"p_league": "fair", "p_waited": 0})).data
	assert_true(bool(f.found))
	# The game builds the battle the same way as Overworld.league_battle.
	var model: BattleModel = BattleReplay.build_model(BattleReferee.from_expect(f))
	assert_not_null(model)
	assert_eq(model.battle_seed, int(f.seed))
	var inputs: Array = []
	var ai := BattleAI.new(1)
	model.start()
	var guard: int = 0
	while not model.is_finished() and guard < 300:
		guard += 1
		if model.needs_player_switch():
			var idx: int = model.swap_candidates(BattleModel.Side.PLAYER)[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			model.submit_switch(idx)
			continue
		var act: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		inputs.append(BattleReplay.action_to_dict(act))
		model.submit_turn(act)
	var replay: Dictionary = BattleReplay.snapshot(model, "battle", "")
	replay["inputs"] = inputs
	var r: Dictionary = await Online.backend.call_fn("battle_submit", {"p_kind": "league_fair", "p_ref": str(f.match_id),
		"p_replay": replay, "p_claim": BattleReferee.claim_of(model)})
	assert_true(bool(r.data.ok))
	assert_eq((await Online.backend.call_fn("battle_status", {"p_battle_id": r.data.battle_id})).data.status, "ok")
