extends GutTest
## Online 100: the referee decides live duels (3), a borrowed Spirling in a live duel and in a raid
## attempt (45), the live duel in the battle screen (1, 73) and the result picture (76), on the local
## stand-in of the server. The same server cases as tools/online/sql_test/test_live_referee.sql.

var s: LocalBackend
var codes: Dictionary = {}
const TEAM: Array = [{"species": "Kindlop", "level": 40, "moves": []}, {"species": "Puddlet", "level": 40, "moves": []},
	{"species": "Mossling", "level": 40, "moves": []}]
const LENT: String = "Wickit"

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	s = LocalBackend.new()
	for who: String in ["ann", "ben", "cid"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
		s.call_fn("team_set", {"p_team": TEAM})
	for k: String in ["live_duel", "lend", "raid"]:
		s.db.flags[k] = {"enabled": true, "min_version": 1}
	_as("ann", "friend_request", {"p_code": codes.ben})
	_as("ben", "friend_respond", {"p_code": codes.ann, "p_accept": true})
	var f: Dictionary = s.db.friendships[LocalBackend.pair_key(s.uid_for_code(codes.ann), s.uid_for_code(codes.ben))]
	f.points = 30
	f.accepted_at = s.now() - 8 * 86400
	s.switch_user("ann")
	s._saves()["1"] = {"rev": 1, "summary": "", "saved_at": 0, "data": {"inventory": {},
		"party": [{"uid": "m1", "species": LENT, "level": 12, "moves": []}, {"uid": "m2", "species": "Kindlop", "level": 9}], "storage": []}}

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

func _duel() -> int:
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	_as("ann", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	return id

## Both sides take their first choice, for [param rounds] rounds or to the end.
func _play(id: int, rounds: int = 80) -> Dictionary:
	var st: Dictionary = _as("ann", "live_state", {"p_id": id})
	for i: int in rounds:
		var sim: LiveDuelSim = LiveDuelSim.of(st)
		if sim.finished():
			break
		_as("ann", "live_move", {"p_id": id, "p_round": int(st.round), "p_input": sim.choices(0)[0].input})
		st = _as("ben", "live_move", {"p_id": id, "p_round": int(st.round), "p_input": sim.choices(1)[0].input})
		assert_true(bool(st.ok), str(st))
	return _as("ann", "live_state", {"p_id": id})

# --- 3 ---------------------------------------------------------------------------------------------

func test_the_referee_decides_whatever_a_phone_reports() -> void:
	var id: int = _duel()
	var st: Dictionary = _play(id)
	var sim: LiveDuelSim = LiveDuelSim.of(st)
	assert_true(sim.finished())
	assert_true(sim.winner() in [0, 1])
	# Ann reports the wrong winner; the referee plays the kept rounds and takes the real one.
	var done: Dictionary = _as("ann", "live_finish", {"p_id": id, "p_winner": 1 - sim.winner()})
	assert_eq(done.state, "done")
	assert_eq(done.reason, "played")
	assert_eq(int(done.winner), sim.winner())
	assert_false(bool(done.judging))
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": 1 - sim.winner()}).error, "duel_closed")
	assert_eq(int(_as("ben", "live_state", {"p_id": id}).winner), sim.winner(), "no second report can void it")

func test_a_duel_that_is_not_over_goes_on() -> void:
	var id: int = _duel()
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": 1}).error, "not_over", "no finished round yet")
	var st: Dictionary = _play(id, 1)
	assert_false(LiveDuelSim.of(st).finished())
	st = _as("ben", "live_finish", {"p_id": id, "p_winner": 1})
	assert_eq(st.state, "running", "claiming a win does not end it")
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": 1}).error, "not_over", "one check per finished round")
	assert_eq(_as("ann", "live_finish", {"p_id": id, "p_winner": 0}).error, "not_over")
	st = _play(id)
	assert_true(LiveDuelSim.of(st).finished(), "the duel can still be played to its end")
	assert_eq(_as("ben", "live_finish", {"p_id": id, "p_winner": -1}).reason, "played")

func test_the_referee_itself() -> void:
	var id: int = _duel()
	var st: Dictionary = _play(id)
	var d: Dictionary = s._live(id)
	var more: LocalLiveMore = s.get_meta("live_more")
	var whole: Dictionary = BattleReferee.check({}, {"expect": more.expect(d, int(d.round) - 1)})
	assert_eq(whole.verdict, "ok")
	assert_true(bool(whole.detail.finished))
	assert_eq(int(whole.detail.winner), LiveDuelSim.of(st).winner())
	var half: Dictionary = BattleReferee.check({}, {"expect": more.expect(d, 1)})
	assert_eq(half.verdict, "ok")
	assert_false(bool(half.detail.finished))
	assert_eq(int(half.detail.rounds), 1)
	assert_eq(LiveDuelSim.judge({"live": true, "seed": 1, "teams": [[{"species": "Nobody"}], [{"species": "Kindlop"}]], "moves": {}}).verdict, "error")
	assert_eq(LiveDuelSim.judge({"live": true, "seed": 1, "teams": [[]], "moves": {}}).detail.reason, "teams")
	assert_eq(LiveDuelSim.judge({"live": true, "seed": 1, "teams": [["x"], ["y"]], "moves": {}}).detail.reason, "teams")
	# A duel the referee cannot play ends without a winner.
	var broken: Dictionary = s._live(_duel())
	more.judged(broken, {"verdict": "error", "detail": {"reason": "rebuild"}})
	assert_eq(broken.reason, "disputed")
	assert_eq(int(broken.winner), -1)

# --- 45 --------------------------------------------------------------------------------------------

func _lend() -> int:
	var r: Dictionary = _as("ann", "lend_offer", {"p_code": codes.ben, "p_slot": 1, "p_uid": "m1"})
	assert_true(bool(r.ok), str(r))
	return int(r.loan)

func test_a_borrowed_spirling_in_a_live_duel() -> void:
	var loan: int = _lend()
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	assert_eq(_as("ben", "live_borrow", {"p_id": id, "p_loan": loan}).error, "duel_closed", "only while picking")
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	assert_eq(_as("ann", "live_borrow", {"p_id": id, "p_loan": loan}).error, "no_such_loan", "only the borrower")
	assert_eq(_as("ben", "live_borrow", {"p_id": id, "p_loan": 999}).error, "no_such_loan")
	var st: Dictionary = _as("ben", "live_borrow", {"p_id": id, "p_loan": loan})
	assert_eq((st.show[1] as Array).size(), 4)
	assert_eq(st.show[1][3].species, LENT)
	assert_true(bool(st.show[1][3].loan))
	assert_eq((_as("ann", "live_state", {"p_id": id}).show[1] as Array).size(), 4, "the rival sees it too")
	assert_eq(_as("ben", "live_borrow", {"p_id": id, "p_loan": loan}).error, "used")
	assert_eq(_as("ben", "lend_list").borrowed[0].state, "used")
	assert_eq(_as("ben", "lend_list").borrowed[0].used_for, "live_duel")
	_as("ann", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	st = _as("ben", "live_pick", {"p_id": id, "p_pick": [3, 0, 1]})
	assert_eq(st.state, "running")
	assert_eq(st.teams[1][0].species, LENT)
	assert_not_null(LiveDuelSim.of(st), "the duel plays with the borrowed Spirling")
	assert_eq(LiveDuelMenu.actions({"state": "picking", "side": 1, "picked": [false, false], "show": [[], [{"species": LENT, "loan": true}]]}),
		["Pick 3", "Give up"] as Array[String])
	assert_true(LiveDuelMenu.actions({"state": "picking", "side": 0, "picked": [false, false], "show": [[], []]}).has("Take a borrowed Spirling along"))
	assert_string_contains(LiveDuelMenu.loan_line({"mon": {"species": LENT, "level": 12}, "name": "Ann"}), "Wickit Ring 12")

func test_a_borrowed_spirling_in_a_raid_attempt() -> void:
	var loan: int = _lend()
	var raid: int = int(_as("ben", "raid_open", {"p_codes": [codes.ann]}).raid)
	assert_eq(_as("ben", "raid_start_loan", {"p_raid": raid, "p_pick": ["Kindlop"], "p_loan": 999}).error, "no_such_loan")
	assert_eq(_as("ann", "raid_start_loan", {"p_raid": raid, "p_pick": ["Kindlop"], "p_loan": loan}).error, "no_such_loan")
	assert_eq(_as("ben", "raid_start_loan", {"p_raid": raid, "p_pick": ["Kindlop", LENT], "p_loan": loan}).error, "duplicate_species")
	assert_eq(_as("ben", "raid_start_loan", {"p_raid": raid, "p_pick": [], "p_loan": loan}).error, "empty_team", "at least one own Spirling")
	assert_eq(_as("ben", "lend_list").borrowed[0].state, "lent", "a failed start keeps the loan")
	var at: Dictionary = _as("ben", "raid_start_loan", {"p_raid": raid, "p_pick": ["Kindlop", "Puddlet"], "p_loan": loan})
	assert_true(bool(at.ok), str(at))
	assert_eq((at.teams[0] as Array).size(), 3)
	assert_eq(at.teams[0][2].species, LENT)
	assert_eq(int(at.teams[0][2].level), 50, "the fair row like everyone")
	assert_not_null(BattleReplay.build_model(BattleReferee.from_expect(at)))
	assert_eq(_as("ben", "lend_list").borrowed[0].used_for, "raid")
	assert_eq(_as("ben", "raid_start_loan", {"p_raid": raid, "p_pick": ["Kindlop"], "p_loan": loan}).error, "used")
	assert_true(bool(_as("ben", "raid_start", {"p_raid": raid, "p_pick": ["Kindlop"]}).ok), "without a loan as before")
	assert_eq(RaidMenu.pick_with_loan([{"species": "A"}, {"species": "B"}, {"species": "C"}, {"species": "D"}, {"species": "E"}], "B").size(), 4)
	assert_false(RaidMenu.pick_with_loan([{"species": "A"}, {"species": "B"}], "B").any(func(p: Dictionary) -> bool: return p.species == "B"))

# --- 1, 73: the duel in the battle screen -----------------------------------------------------------

func _hp(m: BattleModel) -> Array:
	return [BattleReferee._hp(m, 0), BattleReferee._hp(m, 1)]

func test_the_battle_for_the_screen_plays_like_the_referee() -> void:
	var id: int = _duel()
	var st: Dictionary = _play(id)
	var sim: LiveDuelSim = LiveDuelSim.of(st)
	var m: LiveBattleModel = LiveBattleModel.build(st)
	assert_not_null(m)
	assert_eq(m.feed.size(), 1, "the screen starts in replay mode")
	m.start()
	# No round there yet: the screen gets nothing to play and keeps asking.
	watch_signals(m)
	assert_eq(m.submit_turn(null).size(), 0)
	assert_true(m.waiting)
	assert_signal_emitted(m, "idle")
	assert_eq(m.feed.size(), 2)
	for r: int in range(1, LiveDuelStage.complete_rounds(st) + 1):
		m.rounds.append(st.moves[str(r)])
	var guard: int = 0
	while not m.is_finished() and guard < 200:
		guard += 1
		assert_gt(m.submit_turn(null).size(), 0)
		assert_false(m.needs_player_switch(), "a dropped Spirling is followed at once")
	assert_true(m.is_finished())
	assert_eq(m.played, sim.played)
	assert_eq(m.winner(), sim.winner())
	assert_eq(_hp(m), _hp(sim.model), "the same battle as the referee's")
	assert_eq(m.submit_turn(null).size(), 0)
	# Coming in late: the earlier rounds are played unseen, the rest ends the same way.
	var late: LiveBattleModel = LiveBattleModel.build(st)
	var all: Array = []
	for r: int in range(1, LiveDuelStage.complete_rounds(st) + 1):
		all.append(st.moves[str(r)])
	late.enter(all.slice(0, all.size() - 1))
	assert_eq(late.played, all.size() - 1)
	assert_eq((late.get_meta("intro") as Array).size(), 2)
	late.rounds.append(all[-1])
	late.submit_turn(null)
	assert_eq(_hp(late), _hp(sim.model))
	var open: LiveBattleModel = LiveBattleModel.build(st)
	open.start()
	open.close()
	assert_eq(open.feed.size(), 0, "a closed duel ends the screen's loop")
	assert_eq(open.submit_turn(null).size(), 0)
	assert_null(LiveBattleModel.build({"teams": []}))

func test_stage_rules_and_texts() -> void:
	var id: int = _duel()
	var st: Dictionary = _as("ann", "live_state", {"p_id": id})
	assert_eq(LiveDuelStage.complete_rounds(st), 0)
	assert_false(LiveDuelStage.moved(st))
	st = _as("ann", "live_move", {"p_id": id, "p_round": 1, "p_input": LiveDuelSim.of(st).choices(0)[0].input})
	assert_true(LiveDuelStage.moved(st))
	assert_eq(LiveDuelStage.complete_rounds(_as("ben", "live_state", {"p_id": id})), 0, "the open round is not complete")
	var t: String = LiveDuelStage.bar_text(st, ["You", "Ben"], false, int(st.deadline) - 20)
	assert_string_contains(t, "Top: Ben  Bottom: You")
	assert_string_contains(t, "20 s")
	assert_string_contains(t, "Waiting for your friend")
	st["judging"] = true
	assert_string_contains(LiveDuelStage.bar_text(st, ["You", "Ben"], false, 0), "referee")
	assert_string_contains(LiveDuelStage.bar_text({"state": "running", "round": 4, "emotes": [{"side": 1, "emote": 0, "at": 100}]}, ["Ann", "Ben"], true, 103), "Ben: Hello!")
	assert_eq(LiveDuelStage.result_lines({"winner": 1, "state": "done"}, ["Ann", "Ben"], true)[1], "Ben wins!")
	assert_eq(LiveDuelMenu.actions({"state": "running", "side": 0, "picked": [true, true]}), ["Enter the duel"] as Array[String])
	assert_true(LiveDuelMenu.actions({"state": "done", "side": 0}).has("Save a result picture"))
	for path: String in ["res://scripts/online/LiveDuelStage.gd", "res://scripts/overworld/Overworld.gd", "res://scripts/ui/PauseMenu.gd",
			"res://scripts/ui/RaidMenu.gd", "res://scripts/ui/OnlineReplaysMenu.gd"]:
		assert_true(load(path).can_instantiate(), path)

# --- 76: the result picture -------------------------------------------------------------------------

func test_result_card() -> void:
	var id: int = _duel()
	var st: Dictionary = _play(id)
	st = _as("ann", "live_finish", {"p_id": id, "p_winner": 0})
	var f: Dictionary = ResultCard.facts_of_duel(st, ["You", "Ben"])
	assert_eq(int(f.winner), int(st.winner))
	assert_eq((f.teams[0] as Array).size(), 3)
	assert_eq(int(f.rounds), LiveDuelSim.of(st).played)
	var w: int = int(f.winner)
	assert_eq(ResultCard.headline(f), "%s beats %s" % [f.names[w], f.names[1 - w]])
	assert_eq(ResultCard.headline({"winner": -1, "rounds": 4, "names": ["a", "b"]}), "No winner")
	var loser_left: int = 0
	for row: Dictionary in f.teams[1 - w]:
		loser_left += int(row.left)
	assert_eq(loser_left, 0)
	var card: Control = ResultCard.build(f)
	add_child_autofree(card)
	assert_eq(card.size, Vector2(ResultCard.SIZE))
	assert_eq((card.find_child("headline", true, false) as Label).text, ResultCard.headline(f))
	assert_eq((card.find_child("rounds", true, false) as Label).text, "Rounds: %d" % int(f.rounds))
	var row0: HBoxContainer = card.find_child("team0", true, false)
	assert_eq(row0.get_child_count(), 3)
	assert_not_null((row0.get_child(0) as TextureRect).texture, "the game's own Spirling art")
	assert_string_contains((card.find_child("name%d" % w, true, false) as Label).text, "*")
	# A given-up duel: the server's winner counts.
	var id2: int = _duel()
	var gone: Dictionary = _as("ann", "live_forfeit", {"p_id": id2})
	assert_eq(int(ResultCard.facts_of_duel(gone, ["You", "Ben"]).winner), 1)
	# From a kept replay: played again from seed, teams and inputs.
	var mine: Array[Spirling] = [Spirling.new(Database.species("Kindlop"), 30)]
	var foes: Array[Spirling] = [Spirling.new(Database.species("Mossling"), 5)]
	var model := BattleModel.new(mine, foes, false, 4242, 1)
	var snap: Dictionary = BattleReplay.snapshot(model, "battle", "field")
	model.start()
	var ai := BattleAI.new(1)
	while not model.is_finished():
		var a: BattleAction = ai.choose(model, BattleModel.Side.PLAYER)
		snap.inputs.append(BattleReplay.action_to_dict(a))
		model.submit_turn(a)
	var rf: Dictionary = ResultCard.facts_of_replay(snap, "Raid")
	assert_eq(int(rf.winner), 0 if model.outcome == BattleModel.Outcome.WIN else 1)
	assert_eq(int(rf.rounds), model.turn)
	assert_eq(rf.names[0], "You")
	assert_eq(ResultCard.facts_of_replay({"teams": [[{"species": "Nobody"}], [{"species": "Kindlop"}]]}, "x"), {})

# --- The whole thing: a live duel in the real battle screen ----------------------------------------

func _press(stage: LiveDuelStage, label: String) -> bool:
	if stage._panel == null:
		return false
	for b: Node in stage._panel.find_children("*", "Button", true, false):
		if (b as Button).text == label:
			(b as Button).pressed.emit()
			return true
	return false

func test_a_live_duel_runs_in_the_battle_screen() -> void:
	var old_backend: OnlineBackend = Online.backend
	var old_state: Online.State = Online.state
	var old_speed: int = GameState.battle_speed
	Online.backend = s
	Online.state = Online.State.ONLINE
	GameState.battle_speed = GameState.BATTLE_SPEEDS.size() - 1
	# A short duel: one Spirling each, Ben's much weaker.
	var cfg: Dictionary = LiveDuel.config().duplicate(true)
	cfg["pick"] = 1
	s.db.config["live_duel"] = cfg
	_as("ben", "team_set", {"p_team": [{"species": "Mossling", "level": 3, "moves": []}]})
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	_as("ann", "live_pick", {"p_id": id, "p_pick": [0]})
	_as("ben", "live_pick", {"p_id": id, "p_pick": [0]})
	s.switch_user("ann")
	var stage := LiveDuelStage.new()
	stage.setup({"id": id, "name": "Ben"})
	add_child_autofree(stage)
	watch_signals(stage)
	var asked: int = 0
	var closed: bool = false
	var ticks: int = 0
	while not closed and ticks < 1500:
		ticks += 1
		await get_tree().create_timer(0.1).timeout
		# Ben's phone: first choice, as soon as his round is open.
		var ben: Dictionary = _as("ben", "live_state", {"p_id": id})
		if ben.state == "running" and not LiveDuelStage.moved(ben):
			var sim: LiveDuelSim = LiveDuelSim.of(ben)
			if not sim.finished():
				_as("ben", "live_move", {"p_id": id, "p_round": int(ben.round), "p_input": sim.choices(1)[0].input})
		s.switch_user("ann")
		# Ann plays on the battle screen: the first choice of the list over it.
		if stage._choosing and stage._panel != null:
			var first: Button = stage._panel.find_children("*", "Button", true, false)[0]
			first.pressed.emit()
			asked += 1
		elif stage.ended:
			closed = _press(stage, "Close")
	await get_tree().process_frame
	assert_true(closed, "the duel ran to its result")
	assert_signal_emitted(stage, "finished")
	assert_gt(asked, 0, "the choices were asked on the battle screen")
	assert_true(stage.scene is BattleScene)
	assert_gt(stage.scene.log_lines.size(), 2, "the battle screen played the rounds")
	assert_eq(int(done_winner(id)), 0, "Ann's side wins")
	var done: Dictionary = _as("ann", "live_state", {"p_id": id})
	assert_eq(done.state, "done")
	assert_eq(done.reason, "played", "the referee closed it")
	assert_eq(int(done.winner), stage.model.winner())
	assert_eq(int(done.winner), LiveDuelSim.of(done).winner())
	# A friend watches the finished duel in the same screen.
	_as("cid", "friend_request", {"p_code": codes.ann})
	_as("ann", "friend_respond", {"p_code": codes.cid, "p_accept": true})
	s.switch_user("cid")
	var seat := LiveDuelStage.new()
	seat.setup({"id": id, "watch": true, "names": ["Ann", "Ben"]})
	add_child_autofree(seat)
	closed = false
	ticks = 0
	while not closed and ticks < 1500:
		ticks += 1
		await get_tree().create_timer(0.1).timeout
		assert_false(seat._choosing, "a watcher never chooses")
		if seat.ended:
			closed = _press(seat, "Close")
	assert_true(closed, "the watcher saw it to the end")
	assert_eq(seat.model.winner(), int(done.winner))
	assert_eq(seat.names, _as("cid", "live_watch", {"p_id": id}).names, "the names the server gives")
	# The backdrop draws one empty outline before the screen has its size (headless only).
	for e: Variant in get_errors():
		if e.contains_text("indices.is_empty()"):
			e.handled = true
	Online.backend = old_backend
	Online.state = old_state
	GameState.battle_speed = old_speed

func done_winner(id: int) -> int:
	return int(_as("ann", "live_state", {"p_id": id}).winner)
