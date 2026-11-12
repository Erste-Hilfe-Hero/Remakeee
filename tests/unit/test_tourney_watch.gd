extends GutTest
## The weekend tournament (Online 100, points 62, 74, 80), watching a friend's live duel one move
## behind (73), the hidden open round of a live duel, the playable live duel rounds (1-3, 10) and
## the best league team (77) on the local stand-in of the server. The same cases as
## tools/online/sql_test/test_tourney_watch.sql.

var s: LocalBackend
var codes: Dictionary = {}
const TEAM: Array = [{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []},
	{"species": "Mossling", "level": 40, "moves": []}]
const PICK: Array = ["Kindlop", "Puddlet"]

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid", "dan", "eve"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": TEAM})
	for k: String in ["events", "live_duel", "league_fair"]:
		s.db.flags[k] = {"enabled": true, "min_version": 1}
	s.db.config["tourney"] = {"size": 4, "days": [1, 2, 3, 4, 5, 6, 7]}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _friends(x: String, y: String) -> void:
	_as(x, "friend_request", {"p_code": codes[y]})
	_as(y, "friend_respond", {"p_code": codes[x], "p_accept": true})

func test_rules() -> void:
	var c: Dictionary = TourneyRules.config()
	assert_eq(int(c.size), 8)
	assert_eq(TourneyRules.rounds(8), 3)
	assert_eq(TourneyRules.rounds(4), 2)
	assert_eq((c.rewards as Array).size(), TourneyRules.TIER_TEXT.size())
	for r: Dictionary in c.rewards:
		assert_false(Database.item(str(r.item)).is_empty(), str(r.item))
	assert_eq(TourneyRules.tier(c, 3, 0), 0, "winner")
	assert_eq(TourneyRules.tier(c, 3, 3), 1, "lost the final")
	assert_eq(TourneyRules.tier(c, 3, 2), 2)
	assert_eq(TourneyRules.tier(c, 3, 1), 3)
	assert_eq(TourneyRules.round_name(1, 3), "Quarter-final")
	assert_eq(TourneyRules.round_name(3, 3), "Final")
	assert_true(TourneyRules.beats({"won": true, "damage": 1, "rounds": 9, "place": 2}, {"won": false, "damage": 99, "rounds": 1, "place": 1}))
	assert_true(TourneyRules.beats({"won": true, "damage": 50, "rounds": 9, "place": 2}, {"won": true, "damage": 40, "rounds": 1, "place": 1}))
	assert_true(TourneyRules.beats({"won": true, "damage": 50, "rounds": 3, "place": 2}, {"won": true, "damage": 50, "rounds": 4, "place": 1}))
	assert_true(TourneyRules.beats({"won": false, "damage": 0, "rounds": 999, "place": 1}, {"won": false, "damage": 0, "rounds": 999, "place": 2}))
	assert_true(TourneyRules.is_day({"days": [6, 7]}, 1798848000), "2027-01-02 is a Saturday")
	assert_false(TourneyRules.is_day({"days": [6, 7]}, 1799020800), "Monday")

## Plays the tournament battle of [param who] with the AI and sends it in. Returns the battle model.
func _battle(who: String) -> BattleModel:
	var at: Dictionary = _as(who, "tourney_fight")
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
	var r: Dictionary = _as(who, "battle_submit", {"p_kind": "tourney", "p_ref": str(at.fight_id), "p_replay": snap,
		"p_claim": BattleReferee.claim_of(model)})
	assert_true(bool(r.ok), str(r))
	return model

## Decides the fight of [param who] in the running round without a battle.
func _decided(who: String, won: bool, damage: int = 10) -> void:
	var at: Dictionary = _as(who, "tourney_fight")
	assert_true(bool(at.ok), "%s: %s" % [who, str(at)])
	var f: Dictionary = s.db.tourney_fights[str(int(at.fight_id))]
	f.state = "submitted"
	f.battle_id = 800000 + int(at.fight_id)
	f.replay = {"seed": 1, "teams": f.teams, "inputs": []}
	(s.get_meta("tourney") as LocalTourney).apply(int(f.battle_id), true, {"winner": "player" if won else "foe",
		"foe_damage": damage, "rounds": 5})

func test_knockout_with_four() -> void:
	s.db.config["tourney"]["days"] = []
	assert_eq(_as("ann", "tourney_join", {"p_pick": PICK}).error, "tourney_closed", "weekends only")
	s.db.config["tourney"]["days"] = [1, 2, 3, 4, 5, 6, 7]
	var j: Dictionary = _as("ann", "tourney_join", {"p_pick": PICK})
	assert_eq(j.tourney.state, "signup")
	assert_eq(_as("ann", "tourney_join", {"p_pick": PICK}).error, "joined")
	assert_eq(_as("ann", "tourney_fight").error, "no_tourney")
	_as("ben", "tourney_join", {"p_pick": PICK})
	_as("cid", "tourney_join", {"p_pick": PICK})
	j = _as("dan", "tourney_join", {"p_pick": PICK})
	assert_eq(j.tourney.state, "running", "the last player starts it")
	assert_eq(int(j.tourney.round), 1)
	assert_eq(int(j.tourney.foe.place), 3, "dan (4) meets cid (3)")
	assert_eq(j.tourney.foe.name, "", "strangers have no name")
	assert_eq(j.tourney.foe.team, ["Kindlop", "Puddlet"])
	var eve: Dictionary = _as("eve", "tourney_join", {"p_pick": PICK})
	assert_eq(eve.tourney.state, "signup", "the fifth player opens the next one")
	# Round 1: ann plays a real battle that the referee checks; the others are decided.
	var model: BattleModel = _battle("ann")
	assert_eq(_as("ann", "tourney_fight").error, "fought")
	var ann_won: bool = model.outcome == BattleModel.Outcome.WIN
	assert_eq(_as("ann", "tourney_info").tourney.fight, "won" if ann_won else "lost")
	_decided("ben", not ann_won, 0)
	_decided("cid", true, 30)
	assert_eq(int(_as("cid", "tourney_info").tourney.round), 1, "dan has not fought yet")
	_decided("dan", true, 20)
	var info: Dictionary = _as("cid", "tourney_info")
	assert_eq(int(info.tourney.round), 2, "both won: more damage goes on")
	assert_eq(int(info.tourney.out_round), 0)
	assert_eq(int(_as("dan", "tourney_info").tourney.out_round), 1)
	assert_eq(_as("dan", "tourney_fight").error, "no_tourney")
	# The final: cid wins, the other finalist never plays and the time runs out.
	var first: String = "ann" if ann_won else "ben"
	_decided("cid", true)
	assert_eq(_as("cid", "tourney_info").tourney.state, "running")
	s.db.tourneys["1"].round_ends = s.now() - 1
	info = _as("cid", "tourney_info")
	assert_eq(info.tourney.state, "done")
	assert_true(bool(info.tourney.won))
	assert_eq(int(_as(first, "tourney_info").tourney.out_round), 2)
	# Rewards by how far a player came, once.
	s.switch_user("cid")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}, "party": [], "storage": []}}
	var rw: Dictionary = _as("cid", "tourney_reward", {"p_slot": 1, "p_rev": 1})
	assert_eq(int(rw.tier), 0)
	assert_eq(rw.item, "spark_charm")
	assert_eq(_as("cid", "tourney_reward", {"p_slot": 1, "p_rev": int(rw.rev)}).error, "no_reward")
	s.switch_user("dan")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {}, "party": [], "storage": []}}
	assert_eq(int(_as("dan", "tourney_reward", {"p_slot": 1, "p_rev": 1}).tier), 2, "out in the semi-final of four")
	# 74, 80: everyone can watch the final, also someone who did not play.
	var finals: Array = _as("eve", "tourney_finals").rows
	assert_eq(finals.size(), 1)
	assert_true(bool(finals[0].champion))
	assert_eq(finals[0].name, "")
	var rep: Dictionary = _as("eve", "tourney_replay", {"p_fight": int(finals[0].fight)})
	assert_true(bool(rep.ok))
	assert_true(rep.replay.has("inputs") and rep.replay.has("teams"))
	assert_eq(_as("eve", "tourney_replay", {"p_fight": 1}).error, "no_such_fight", "only finals")

func test_final_replay_plays() -> void:
	s.db.config["tourney"]["size"] = 2
	_as("ann", "tourney_join", {"p_pick": PICK})
	_as("ben", "tourney_join", {"p_pick": PICK})
	var model: BattleModel = _battle("ann")
	_decided("ben", false, 0)
	assert_eq(_as("ann", "tourney_info").tourney.state, "done")
	var rows: Array = _as("cid", "tourney_finals").rows
	assert_eq(rows.size(), 2)
	var mine: Dictionary = rows.filter(func(r: Dictionary) -> bool: return (r.teams[0] as Array).size() == 2 and int(r.rounds) != 5)[0]
	var rep: Dictionary = _as("cid", "tourney_replay", {"p_fight": int(mine.fight)}).replay
	var again: BattleModel = BattleReplay.run(BattleReferee.from_expect(rep, rep.inputs))
	assert_not_null(again)
	assert_eq(again.outcome, model.outcome, "the stored final plays the same way")

func _duel() -> int:
	_friends("ann", "ben")
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	_as("ann", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	return id

func test_live_duel_rounds_play_the_same_on_both_sides() -> void:
	var id: int = _duel()
	var guard: int = 0
	var st: Dictionary = _as("ann", "live_state", {"p_id": id})
	while guard < 80:
		guard += 1
		var sim: LiveDuelSim = LiveDuelSim.of(st)
		assert_not_null(sim)
		if sim.finished():
			break
		var mine: Array = sim.choices(0)
		assert_gt(mine.size(), 0)
		var after: Dictionary = _as("ann", "live_move", {"p_id": id, "p_round": int(st.round), "p_input": mine[0].input})
		assert_true(bool(after.ok), str(after))
		var ben: Dictionary = _as("ben", "live_state", {"p_id": id})
		assert_null(ben.moves[str(int(st.round))][0], "ben does not see ann's choice of the open round")
		var theirs: Array = LiveDuelSim.of(ben).choices(1)
		st = _as("ben", "live_move", {"p_id": id, "p_round": int(st.round), "p_input": theirs[0].input})
		assert_true(bool(st.ok), str(st))
	var a: LiveDuelSim = LiveDuelSim.of(_as("ann", "live_state", {"p_id": id}))
	var b: LiveDuelSim = LiveDuelSim.of(_as("ben", "live_state", {"p_id": id}))
	assert_true(a.finished(), "the duel ends")
	assert_eq(a.winner(), b.winner())
	assert_true(a.winner() in [0, 1])
	assert_eq(a.played, b.played)
	assert_eq(a.summary(0), b.summary(0))
	assert_eq(a.summary(0).size(), 3, "one line per Spirling (point 10)")
	var done: Dictionary = _as("ann", "live_finish", {"p_id": id, "p_winner": a.winner()})
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": b.winner()}).error, "duel_closed", "the referee already closed it")
	assert_eq(done.state, "done")
	assert_eq(int(done.winner), a.winner())

func test_bad_input_rests() -> void:
	var id: int = _duel()
	_as("ann", "live_move", {"p_id": id, "p_round": 1, "p_input": {"k": 2, "i": "max_tonic"}})
	var st: Dictionary = _as("ben", "live_move", {"p_id": id, "p_round": 1, "p_input": {"k": 0, "m": 99}})
	var sim: LiveDuelSim = LiveDuelSim.of(st)
	assert_eq(sim.played, 1, "illegal choices count as a rest")

func test_watching_is_one_move_behind() -> void:
	var id: int = _duel()
	_friends("cid", "ann")
	assert_eq(_as("dan", "live_watch", {"p_id": id}).error, "no_such_duel", "only friends watch")
	assert_eq(_as("ann", "live_watch", {"p_id": id}).error, "no_such_duel", "not the own duel")
	assert_true((_as("dan", "live_watch_list").duels as Array).is_empty())
	var list: Array = _as("cid", "live_watch_list").duels
	assert_eq(list.size(), 1)
	assert_eq(int(list[0].id), id)
	for r: int in [1, 2]:
		_as("ann", "live_move", {"p_id": id, "p_round": r, "p_input": {"k": 5}})
		_as("ben", "live_move", {"p_id": id, "p_round": r, "p_input": {"k": 5}})
	var w: Dictionary = _as("cid", "live_watch", {"p_id": id})
	assert_eq(int(w.side), -1)
	assert_eq(int(w.round), 3)
	assert_eq((w.moves as Dictionary).keys(), ["1"], "round 2 is held back while the duel runs")
	assert_eq(w.names.size(), 2)
	assert_eq(LiveDuelSim.of(w).played, 1)
	_as("ann", "live_forfeit", {"p_id": id})
	assert_eq((_as("cid", "live_watch", {"p_id": id}).moves as Dictionary).size(), 2, "all of it once the duel is over")
	_as("ben", "block", {"p_code": codes.cid})
	assert_eq(_as("cid", "live_watch", {"p_id": id}).error, "no_such_duel", "blocked by a player")

func test_top_league_team() -> void:
	assert_null(_as("ann", "league_top_team", {"p_league": "fair"}).team)
	var sn: int = int(s.league_season().id)
	var t: Dictionary = s._table("league_fair", {})
	t["%d|ben" % sn] = {"team": [{"species": "Kindlop", "level": 50, "moves": ["Ember"]}], "rating": 1900.0, "rd": 50.0, "vol": 0.06, "games": 12, "wins": 9}
	t["%d|cid" % sn] = {"team": [{"species": "Puddlet", "level": 50, "moves": []}], "rating": 2400.0, "rd": 50.0, "vol": 0.06, "games": 2, "wins": 2}
	var r: Dictionary = _as("ann", "league_top_team", {"p_league": "fair"})
	assert_eq(r.team[0].species, "Kindlop", "placement battles first")
	assert_eq(int(r.games), 12)
	assert_false(r.has("name"))
	assert_eq(_as("ann", "league_top_team", {"p_league": "x"}).error, "bad_league")

func test_menu_texts() -> void:
	var d: Dictionary = {"size": 8, "rounds": 3, "day": true, "tourney": {"state": "running", "round": 2, "round_ends": 4600,
		"out_round": 0, "claimed": false, "fight": null, "foe": {"place": 3, "name": "", "team": ["Kindlop", "Puddlet"]},
		"players": [{"place": 1, "me": true, "out_round": 0, "name": "Ann"}, {"place": 2, "me": false, "out_round": 1, "name": ""}]}}
	var t: String = TourneyMenu.info_text(d, 1000)
	assert_string_contains(t, "Semi-final, 1 h left")
	assert_string_contains(t, "Your rival: Wayfarer 3 with Kindlop, Puddlet")
	assert_string_contains(t, "1. You")
	assert_string_contains(t, "2. Wayfarer 2  out")
	assert_eq(TourneyMenu.actions(d), ["Start my battle", "Battles of the week", "Rewards"] as Array[String])
	d.tourney.fight = "submitted"
	assert_eq(TourneyMenu.actions(d), ["Battles of the week", "Rewards"] as Array[String])
	assert_eq(TourneyMenu.actions({"day": true, "tourney": null})[0], "Sign up with my team")
	assert_eq(TourneyMenu.actions({"day": false, "tourney": null}), ["Battles of the week", "Rewards"] as Array[String])
	assert_eq(TourneyMenu.actions({"day": true, "tourney": {"state": "done", "claimed": false, "out_round": 1}})[0], "Take the reward")
	assert_string_contains(TourneyMenu.rewards_text(TourneyRules.config().rewards), "Winner: ")
	assert_eq(TourneyMenu.final_line({"week": "2026-W46", "champion": true, "name": "", "won": true, "rounds": 6,
		"teams": [["Kindlop"], ["Puddlet"]]}), "W46  Champion: Kindlop against Puddlet  (won, 6 rounds)")
	assert_string_contains(LeagueMenu.top_team_text({"games": 12, "team": [{"species": "Kindlop", "moves": ["Ember"]}]}), "Kindlop")
	assert_eq(LiveDuelMenu.actions({"state": "running", "side": 0, "picked": [true, true]})[0], "Enter the duel")
	var id: int = _duel()
	var st: Dictionary = _as("ann", "live_state", {"p_id": id})
	var sim: LiveDuelSim = LiveDuelSim.of(st)
	assert_string_contains(LiveDuelMenu.battle_lines(sim, 1)[-1], "against")
	st["names"] = ["Ann", "Ben"]
	assert_string_contains(LiveDuelMenu.watch_text(st), "Ann against Ben")
	for path: String in ["res://scripts/overworld/Overworld.gd", "res://scripts/ui/FriendsMenu.gd", "res://scripts/ui/PauseMenu.gd"]:
		assert_true(load(path).can_instantiate(), path)
