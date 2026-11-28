extends GutTest
## docs/KAMPF_PLAN_1000.md items 340 (field in live duels), 375 (two on two echo duel), 386 (auto
## aim), 389 (acting order) and 396 (one-hand aiming). The live duel cases match
## tools/online/sql_test/test_live_field.sql.

const Side := BattleModel.Side

var s: LocalBackend
var codes: Dictionary = {}
var _auto_aim: bool
var _one_hand: bool

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	_auto_aim = GameState.auto_aim
	_one_hand = GameState.one_hand

func after_each() -> void:
	GameState.auto_aim = _auto_aim
	GameState.one_hand = _one_hand

func _mk(name: String, moves: Array[String] = [], level: int = 30) -> Spirling:
	return BattleFixtures.make(name, level, moves)

func _model(mine: Array[Spirling], theirs: Array[Spirling], front: Array[int]) -> BattleModel:
	var m := BattleModel.new(mine, theirs, false, 11, 0)
	m.front_size = front
	return m

func _backend() -> void:
	s = LocalBackend.new()
	s.rng.seed = 1
	s.db.flags["live_duel"] = {"enabled": true, "min_version": 1}
	for who: String in ["ann", "ben"]:
		s.switch_user(who)
		codes[who] = s.call_fn("hello", {"p_version": 1}).data.profile.code
	_as("ann", "team_set", {"p_team": [{"species": "Kindlop", "level": 12}, {"species": "Puddlet", "level": 9},
		{"species": "Zippit", "level": 9}]})
	_as("ben", "team_set", {"p_team": [{"species": "Zippit", "level": 20}, {"species": "Kindlop", "level": 15},
		{"species": "Puddlet", "level": 9}]})
	_as("ben", "friend_request", {"p_code": codes.ann})
	_as("ann", "friend_respond", {"p_code": codes.ben, "p_accept": true})

func _as(who: String, fn: String, args: Dictionary = {}) -> Dictionary:
	s.switch_user(who)
	return s.call_fn(fn, args).data

# --- 340: the field of a live duel -----------------------------------------------------------------

func test_live_duel_fields_come_from_the_data_file() -> void:
	var f: Array[String] = LiveDuel.fields()
	assert_eq(f[0], "", "no field comes first")
	assert_true(f.size() > 1)
	for name: String in f.slice(1):
		assert_true(BattleRules.FIELDS.has(name), name)
	assert_eq(LiveDuel.field_names().size(), f.size())
	assert_eq(LiveDuel.field_ok("high_tide"), "high_tide")
	assert_eq(LiveDuel.field_ok(""), "")
	assert_null(LiveDuel.field_ok("lava_lake"))
	assert_null(LiveDuel.field_ok("high_tide", {"fields": []}), "only the listed fields")
	assert_eq(LiveDuel.field_label(""), "No field")

func test_inviter_picks_the_field_and_everyone_plays_on_it() -> void:
	_backend()
	assert_eq(_as("ann", "live_invite", {"p_code": codes.ben, "p_field": "lava_lake"}).error, "bad_field")
	var plain: int = int(_as("ann", "live_invite", {"p_code": codes.ben}).id)
	assert_eq(str(_as("ann", "live_state", {"p_id": plain}).field), "", "no field by default")
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben, "p_field": "high_tide"}).id)
	assert_eq(str(_as("ben", "live_state", {"p_id": id}).field), "high_tide", "the friend sees it")
	_as("ben", "live_answer", {"p_id": id, "p_accept": true})
	_as("ben", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	var st: Dictionary = _as("ann", "live_pick", {"p_id": id, "p_pick": [0, 1, 2]})
	assert_eq(st.state, "running")
	assert_eq(LiveDuelSim.of(st).model.field, "high_tide", "both phones and watchers play on the field")
	var more: LocalLiveMore = s.get_meta("live_more")
	var expect: Dictionary = more.expect(s._table("live_duels", {})[str(id)], 1)
	assert_eq(expect.field, "high_tide", "the referee too")
	assert_eq(BattleReferee.from_expect(expect).field, "high_tide")
	assert_eq(BattleReferee.from_expect({"field": "lava_lake"}).field, "", "an unknown field counts as none")
	assert_eq(BattleReferee.from_expect({}).field, "", "league battles stay without")

func test_a_rematch_keeps_the_field() -> void:
	_backend()
	var id: int = int(_as("ann", "live_invite", {"p_code": codes.ben, "p_field": "ash_storm"}).id)
	(s._table("live_duels", {})[str(id)] as Dictionary).state = "done"
	var again: int = int(_as("ben", "live_rematch", {"p_id": id}).id)
	assert_eq(str(_as("ann", "live_state", {"p_id": again}).field), "ash_storm")

func test_state_text_names_the_field() -> void:
	var d: Dictionary = {"state": "invited", "side": 0, "emotes": [], "field": "high_tide"}
	assert_string_contains(LiveDuelMenu.state_text(d, 0), "Field: High Tide")
	d.field = ""
	assert_false(LiveDuelMenu.state_text(d, 0).contains("Field"))

# --- 375: two on two with a friend's echo --------------------------------------------------------

func test_echo_duel_two_on_two_with_a_second_friends_echo() -> void:
	var partner_team: Array[Spirling] = [_mk("Zippit", [], 12), _mk("Wickit", [], 70)]
	var partner: Dictionary = {"name": "Ben's echo", "echo": partner_team, "front": 1, "ai": EchoTeam.PARTNER_AI}
	var p: Dictionary = EchoTeam.duel_partner(partner, 40)
	assert_eq(int(p.front), 1)
	assert_eq(int(p.ai), EchoTeam.DUEL_AI, "the partner fights with the duel AI")
	for sp: Spirling in p.echo:
		assert_eq(sp.level, 40, "the partner fights on the duel Ring too")
	assert_eq(partner_team[1].level, 70, "the friend's echo itself is not changed")
	var m := _model([_mk("Kindlop")] as Array[Spirling], [_mk("Puddlet"), _mk("Mossling"), _mk("Zippit")] as Array[Spirling], EchoTeam.DOUBLE_FRONT)
	m.set_partner(str(p.name), p.echo, int(p.front), int(p.ai))
	m.start()
	assert_true(m.is_multi())
	assert_eq(m.slot_count(Side.PLAYER), 2, "you and the partner")
	assert_eq(m.slot_count(Side.FOE), 2, "the echo fields two")
	assert_true(m.is_partner_slot(Side.PLAYER, 1))

# --- 386: auto aim --------------------------------------------------------------------------------

func test_auto_aim_takes_the_best_foe_for_damaging_arts_only() -> void:
	var me: Spirling = _mk("Puddlet", ["Fizz Pop"])
	var m := _model([me] as Array[Spirling], [_mk("Mossling"), _mk("Kindlop")] as Array[Spirling], [1, 2])
	m.start()
	assert_eq(MultiRules.auto_aim(m, me, me.moves[0], false), -1, "off: the player picks")
	assert_eq(MultiRules.auto_aim(m, me, me.moves[0], true), 1, "Tide goes at the Ember foe")
	var status: MoveData = MoveData.new()
	status.kind = MoveData.Kind.STATUS
	assert_eq(MultiRules.auto_aim(m, me, status, true), -1, "a status art is aimed by hand")
	assert_eq(MultiRules.auto_aim(m, null, me.moves[0], true), -1, "a bond is aimed by hand")

func test_auto_aim_is_a_battle_setting_and_saved() -> void:
	GameState.auto_aim = false
	var keys: Array[String] = []
	for r: Array in BattleComfort.option_rows():
		keys.append(str(r[0]))
	assert_true("aim" in keys)
	assert_true(BattleComfort.toggle_option("aim"))
	assert_true(GameState.auto_aim)
	var d: Dictionary = GameState.settings_to_dict()
	GameState.auto_aim = false
	GameState.settings_from_dict(d)
	assert_true(GameState.auto_aim, "kept with the settings")

# --- 389: acting order ----------------------------------------------------------------------------

func test_acting_order_by_pace_in_multi_battles() -> void:
	var m := _model([_mk("Kindlop", [], 10), _mk("Zippit", [], 40)] as Array[Spirling], [_mk("Puddlet", [], 20), _mk("Mossling", [], 30)] as Array[Spirling], [2, 2])
	m.start()
	var order: Array[Dictionary] = MultiRules.pace_order(m)
	assert_eq(order.size(), 4)
	for i: int in order.size() - 1:
		assert_true(int(order[i].pace) >= int(order[i + 1].pace), "fastest first")
	var line: String = MultiRules.pace_line(m)
	assert_true(line.begins_with("Acting order "), line)
	for e: Dictionary in order:
		assert_string_contains(line, ("foe " if int(e.side) == Side.FOE else "") + str(e.name))
	var one := _model([_mk("Kindlop")] as Array[Spirling], [_mk("Puddlet")] as Array[Spirling], [1, 1])
	one.start()
	assert_eq(MultiRules.pace_line(one), "", "one on one has the art card's hint")

func test_acting_order_ties_cap_and_dark() -> void:
	var m := _model([_mk("Kindlop"), _mk("Kindlop"), _mk("Kindlop")] as Array[Spirling], [_mk("Kindlop"), _mk("Kindlop"), _mk("Kindlop")] as Array[Spirling], [3, 3])
	m.start()
	var order: Array[Dictionary] = MultiRules.pace_order(m)
	assert_eq(int(order[0].side), Side.PLAYER, "on a tie your side is listed first")
	assert_eq(int(order[0].slot), 0)
	var cap: int = int(MultiRules.data().order_bar.max_names)
	assert_string_contains(MultiRules.pace_line(m), "+%d" % (6 - cap), "the rest as +n")
	m.foe_rule = "night_dark"
	if BattleRules.rule_number(m.foe_rule, "hidden_order") > 0.0:
		assert_eq(MultiRules.pace_line(m), "", "nobody sees the Pace in the dark")

# --- 396: one-hand aiming -------------------------------------------------------------------------

func test_one_hand_aims_from_a_low_list() -> void:
	assert_true(MultiRules.aim_by_list(true, true))
	assert_false(MultiRules.aim_by_list(true, false), "two hands tap the Spirlings")
	assert_false(MultiRules.aim_by_list(false, true), "one on one has nothing to aim")
	assert_eq(MultiRules.hand_top(400.0, 24.0, false), 24.0)
	assert_eq(MultiRules.hand_top(400.0, 24.0, true), 400.0 * MenuHost.ONE_HAND_TOP, "low, in reach of the thumb")
	assert_eq(MultiRules.hand_top(40.0, 24.0, true), 24.0, "never above the margin")
