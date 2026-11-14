extends GutTest
## Turn flow rules of docs/KAMPF_PLAN_1000.md items 6 (turn clock in echo duels), 8 (giving up),
## 9 (swap offer after a foe's knock-out), 10 (the foe names its next Spirling) and 12 (All rest):
## TurnFlow, BattleModel.forfeit / AWAIT_SHIFT, BattleReplay inputs.

var _flags: Dictionary

func before_all() -> void:
	Database.load_all()

func before_each() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "Kindlop")
	_flags = GameState.flags.duplicate()

func after_each() -> void:
	GameState.flags = _flags

func _strong() -> Spirling:
	return BattleFixtures.make("Kindlop", 40, ["Cinder Nip"])

func _weak() -> Spirling:
	var s: Spirling = BattleFixtures.make("Mossling", 5, ["Lichen Lash"])
	s.hp = 1
	return s

## A 1v1 Wayfarer battle: two of yours against two weak foes, ready for the first turn.
func _wayfarer(shift: bool, announce: bool) -> BattleModel:
	var m := BattleModel.new([_strong(), _strong()] as Array[Spirling], [_weak(), _weak()] as Array[Spirling], false, 11, 1)
	m.trainer_name = "Bram"
	m.shift_offer = shift
	m.foe_announce = announce
	m.start()
	return m

## Plays turns with the first art until the battle stops for something else than orders.
func _until_knockout(m: BattleModel) -> Array[BattleEvent]:
	var all: Array[BattleEvent] = []
	for i: int in 6:
		all.append_array(m.submit_turn(BattleAction.make_move(BattleModel.Side.PLAYER, 0)))
		if m.phase != BattleModel.Phase.CHOOSE_ACTIONS or m.party(BattleModel.Side.FOE)[0].is_fainted():
			break
	return all

func _lines(events: Array[BattleEvent], kind: String) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.BATTLE_LINE and str(e.data.get("kind", "")) == kind:
			out.append(e)
	return out

# --- Item 6: turn clock ---

func test_echo_duel_clock_is_sixty_seconds_from_data() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TurnFlow.PATH))
	assert_eq(int(raw.echo_turn_seconds), 60)
	assert_eq(TurnFlow.echo_seconds(), 60)
	assert_eq(TurnFlow.seconds_left(60000, 0), 60)
	assert_eq(TurnFlow.seconds_left(60000, 59001), 1, "a started second still counts")
	assert_eq(TurnFlow.seconds_left(60000, 70000), 0, "never below zero")
	assert_true(TurnFlow.warn_now(10))
	assert_false(TurnFlow.warn_now(11))

func test_echo_duel_passes_the_clock_and_the_battle_takes_it() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var duel: String = src.substr(src.find("func echo_duel"), 2500)
	assert_string_contains(duel, "TurnFlow.CLOCK_META: TurnFlow.echo_seconds()")
	assert_string_contains(src, "model.set_meta(TurnFlow.CLOCK_META")

func test_time_out_rests_everyone_without_orders() -> void:
	var m := BattleModel.new([_strong(), _strong(), _strong()] as Array[Spirling], [_strong(), _strong()] as Array[Spirling], false, 3, 1)
	m.front_size = [2, 2]
	m.start()
	var out: Array[BattleAction] = [BattleAction.make_move(BattleModel.Side.PLAYER, 0, 0)]
	var full: Array[BattleAction] = TurnFlow.fill_rest(m, out)
	assert_eq(full.size(), 2)
	assert_eq(full[0].kind, BattleAction.Kind.MOVE, "an order already given stays")
	assert_eq(full[1].kind, BattleAction.Kind.REST)
	assert_eq(full[1].slot, 1)
	assert_eq(out.size(), 1, "the list passed in is left alone")

# --- Item 12: All rest ---

func test_all_rest_rests_the_whole_formation() -> void:
	var m := BattleModel.new([_strong(), _strong()] as Array[Spirling], [_strong(), _strong()] as Array[Spirling], false, 3, 1)
	m.front_size = [2, 2]
	m.start()
	assert_true(TurnFlow.all_rest_shown(m))
	var all: Array[BattleAction] = TurnFlow.fill_rest(m, [] as Array[BattleAction])
	assert_eq(all.size(), 2)
	for a: BattleAction in all:
		assert_eq(a.kind, BattleAction.Kind.REST)
	m.active_spirling(BattleModel.Side.PLAYER, 1).energy = 2
	var energy: int = 2
	var events: Array[BattleEvent] = m.submit_actions(all)
	var rests: int = 0
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.REST and int(e.data.get("side", -1)) == BattleModel.Side.PLAYER:
			rests += 1
	assert_eq(rests, 2, "both of your Spirlings rest")
	assert_gt(m.active_spirling(BattleModel.Side.PLAYER, 1).energy, energy)

func test_all_rest_not_in_a_single_battle() -> void:
	assert_false(TurnFlow.all_rest_shown(_wayfarer(false, false)))

# --- Item 8: giving up ---

func test_give_up_only_against_a_wayfarer() -> void:
	var wild: BattleModel = BattleFixtures.model([_strong()] as Array[Spirling], [_weak()] as Array[Spirling], true)
	assert_false(TurnFlow.can_forfeit(wild))
	var m: BattleModel = _wayfarer(false, false)
	assert_true(TurnFlow.can_forfeit(m))
	m.set_meta(TurnFlow.NO_FORFEIT_META, true)
	assert_false(TurnFlow.can_forfeit(m), "not in friendly or server-checked battles")

func test_give_up_counts_as_a_loss_without_coins() -> void:
	var m: BattleModel = _wayfarer(false, false)
	m.prize_money = 300
	var events: Array[BattleEvent] = m.forfeit()
	assert_true(m.is_finished())
	assert_eq(m.outcome, BattleModel.Outcome.LOSS)
	var end: BattleEvent = BattleFixtures.first_of(events, BattleEvent.Type.BATTLE_END)
	assert_not_null(end)
	assert_eq(int(end.data.money), 0)
	assert_string_contains(BattleFixtures.first_of(events, BattleEvent.Type.TECHNIQUE).describe(), "Bram")
	assert_false(TurnFlow.can_forfeit(m), "a finished battle cannot be given up again")
	assert_true(m.forfeit().is_empty())

func test_overworld_takes_no_coins_after_a_loss() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/overworld/Overworld.gd")
	var after: String = src.substr(src.find("func _after_battle"))
	assert_string_contains(after, "if outcome == BattleModel.Outcome.WIN and not model.is_wild else 0")
	assert_false(after.substr(0, after.find("\nfunc ", 10)).contains("GameState.money -="), "a loss never costs coins")

func test_command_menu_offers_give_up() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/presenter/CommandMenu.gd")
	assert_string_contains(src, "TurnFlow.can_forfeit(model)")
	assert_string_contains(src, "\"Give up\"")

# --- Item 9: swap offer ---

func test_swap_offer_per_difficulty() -> void:
	assert_true(TurnFlow.shift_offer_on(GameState.Difficulty.STORY, true), "Story always offers")
	assert_true(TurnFlow.shift_offer_on(GameState.Difficulty.TAMER, true), "Wayfarer always offers")
	assert_true(TurnFlow.shift_offer_on(GameState.Difficulty.VETERAN, false))
	assert_false(TurnFlow.shift_offer_on(GameState.Difficulty.VETERAN, true), "Veteran can switch it off")
	assert_false(TurnFlow.shift_offer_on(GameState.Difficulty.RIFT_BORN, false), "never on Rift-Born")
	assert_true(TurnFlow.shift_setting_shown(GameState.Difficulty.VETERAN))
	assert_false(TurnFlow.shift_setting_shown(GameState.Difficulty.STORY))

func test_veteran_switch_follows_the_flag() -> void:
	GameState.difficulty = GameState.Difficulty.VETERAN
	assert_true(TurnFlow.shift_on())
	GameState.flags[TurnFlow.SHIFT_OFF_FLAG] = true
	assert_false(TurnFlow.shift_on())
	GameState.difficulty = GameState.Difficulty.STORY
	assert_true(TurnFlow.shift_on(), "the Veteran switch does not reach Story")

func test_knockout_stops_for_the_swap_offer() -> void:
	var m: BattleModel = _wayfarer(true, false)
	_until_knockout(m)
	assert_true(m.needs_shift_choice())
	assert_eq(m.shift_next, 1)
	assert_eq(m.active_index(BattleModel.Side.FOE), 0, "the named foe has not stepped out yet")
	var events: Array[BattleEvent] = m.submit_shift(1)
	assert_eq(m.phase, BattleModel.Phase.CHOOSE_ACTIONS)
	assert_eq(m.active_index(BattleModel.Side.PLAYER), 1, "your swap came first")
	assert_eq(m.active_index(BattleModel.Side.FOE), 1)
	var order: Array[int] = []
	for e: BattleEvent in events:
		if e.type == BattleEvent.Type.SWAP_IN:
			order.append(int(e.data.get("side", -1)))
	assert_eq(order, [BattleModel.Side.PLAYER, BattleModel.Side.FOE])

func test_staying_or_ordering_on_lets_the_foe_step_out() -> void:
	var m: BattleModel = _wayfarer(true, false)
	_until_knockout(m)
	m.submit_shift(-1)
	assert_eq(m.active_index(BattleModel.Side.PLAYER), 0)
	assert_eq(m.active_index(BattleModel.Side.FOE), 1)
	var n: BattleModel = _wayfarer(true, false)
	_until_knockout(n)
	n.submit_turn(BattleAction.make_rest(BattleModel.Side.PLAYER))
	assert_ne(n.active_index(BattleModel.Side.FOE), 0, "orders without an answer decline the offer")

func test_no_offer_without_the_flag_or_in_the_wild() -> void:
	var m: BattleModel = _wayfarer(false, false)
	_until_knockout(m)
	assert_false(m.needs_shift_choice())
	assert_eq(m.active_index(BattleModel.Side.FOE), 1)

# --- Item 10: announcement ---

func test_foe_names_its_next_spirling() -> void:
	var m: BattleModel = _wayfarer(false, true)
	var lines: Array[BattleEvent] = _lines(_until_knockout(m), "announce")
	assert_eq(lines.size(), 1)
	assert_eq(str(lines[0].data.name), "Bram")
	assert_string_contains(str(lines[0].data.text), m.party(BattleModel.Side.FOE)[1].display_name())
	assert_false(m.needs_shift_choice(), "without the offer the foe steps out at once")

func test_announcement_can_be_switched_off() -> void:
	assert_true(TurnFlow.announce_on())
	GameState.flags[TurnFlow.ANNOUNCE_OFF_FLAG] = true
	assert_false(TurnFlow.announce_on())
	var m: BattleModel = _wayfarer(true, false)
	assert_true(_lines(_until_knockout(m), "announce").is_empty())

# --- Replays and the referee ---

func test_replay_keeps_offer_shift_and_give_up() -> void:
	var m := BattleModel.new([_strong(), _strong()] as Array[Spirling], [_weak(), _weak(), _weak()] as Array[Spirling], false, 11, 1)
	m.trainer_name = "Bram"
	m.shift_offer = true
	m.foe_announce = true
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "field")
	assert_true(bool(snap.shift_offer))
	m.start()
	var inputs: Array = []
	for i: int in 6:
		if m.needs_shift_choice():
			break
		var a := BattleAction.make_move(BattleModel.Side.PLAYER, 0)
		inputs.append(BattleReplay.action_to_dict(a))
		m.submit_turn(a)
	assert_true(m.needs_shift_choice())
	inputs.append(BattleReplay.shift_to_dict(1))
	m.submit_shift(1)
	inputs.append(BattleReplay.forfeit_to_dict())
	m.forfeit()
	snap["inputs"] = inputs
	var again: BattleModel = BattleReplay.run(snap)
	assert_true(again.is_finished())
	assert_eq(again.outcome, BattleModel.Outcome.LOSS)
	assert_eq(again.active_index(BattleModel.Side.PLAYER), 1, "the swap played back")
	assert_eq(again.turn, m.turn)
