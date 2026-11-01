extends GutTest
## Battles with several Spirlings per side: N vs M slots, targeting, sweeps, faint refills,
## tag battles with an ally Tamer, Rift bosses, wild hordes (Echo call only vs wild foes),
## replays and the story set pieces in the map data.

const Side := BattleModel.Side
const T := BattleEvent.Type

func before_all() -> void:
	Database.load_all()

func _p(names: Array[String], level: int = 15) -> Array[Spirling]:
	var out: Array[Spirling] = []
	for n: String in names:
		out.append(BattleFixtures.make(n, level))
	return out

func _model(mine: Array[Spirling], theirs: Array[Spirling], front: Array[int], wild: bool = false, seed_value: int = 11, ai: int = 1) -> BattleModel:
	var m := BattleModel.new(mine, theirs, wild, seed_value, ai)
	m.front_size = front
	return m

## Plays a battle to the end with greedy AI on the player side too. Returns the event log.
func _auto(m: BattleModel) -> Array[BattleEvent]:
	var brain := BattleAI.new(1)
	var log: Array[BattleEvent] = []
	log.append_array(m.start())
	var guard: int = 0
	while not m.is_finished() and guard < 300:
		guard += 1
		if m.needs_player_switch():
			log.append_array(m.submit_switch(m.swap_candidates(Side.PLAYER, m.switch_slot())[0]))
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, Side.PLAYER, slot))
		log.append_array(m.submit_actions(acts))
	assert_true(m.is_finished(), "battle must end")
	return log

func _count(events: Array[BattleEvent], t: BattleEvent.Type) -> int:
	return events.filter(func(e: BattleEvent) -> bool: return e.type == t).size()

# --- Formats ---------------------------------------------------------------------

func test_uneven_formats_fill_their_slots() -> void:
	for f: Array in [[3, 3], [4, 1], [4, 2], [2, 4], [1, 3]]:
		var m := _model(_p(["Kindlop", "Puddlet", "Mossling", "Zippit", "Zephlet"]), _p(["Shalebat", "Wickit", "Kelpup", "Mirkmole", "Zephlet"]), [int(f[0]), int(f[1])])
		var events: Array[BattleEvent] = m.start()
		assert_eq(m.slot_count(Side.PLAYER), int(f[0]), "player slots for %s" % [f])
		assert_eq(m.slot_count(Side.FOE), int(f[1]), "foe slots for %s" % [f])
		assert_eq(_count(events, T.SEND_OUT), int(f[0]) + int(f[1]))
		assert_true(m.is_multi())

func test_front_never_exceeds_the_party_or_the_cap() -> void:
	var m := _model(_p(["Kindlop", "Puddlet"]), _p(["Shalebat", "Wickit", "Kelpup", "Mirkmole", "Zephlet", "Zippit"]), [4, 6])
	m.start()
	assert_eq(m.slot_count(Side.PLAYER), 2, "a party of two fields two")
	assert_eq(m.slot_count(Side.FOE), BattleRules.MAX_FRONT, "never more than four per side")

func test_one_v_one_is_unchanged_by_default() -> void:
	var m := BattleFixtures.model(_p(["Kindlop", "Puddlet"]), _p(["Zippit"]))
	assert_false(m.is_multi())
	assert_eq(m.slot_count(Side.PLAYER), 1)
	assert_eq(m.active[Side.PLAYER], 0)

func test_uneven_battles_reach_an_outcome() -> void:
	for f: Array in [[3, 3], [4, 1], [4, 2], [2, 4]]:
		var m := _model(_p(["Kindlop", "Puddlet", "Mossling", "Zippit"]), _p(["Shalebat", "Wickit", "Kelpup", "Mirkmole"], 14), [int(f[0]), int(f[1])])
		var log: Array[BattleEvent] = _auto(m)
		assert_eq(log[log.size() - 1].type, T.BATTLE_END)
		assert_ne(m.outcome, BattleModel.Outcome.NONE)

func test_same_seed_same_multi_battle() -> void:
	var a: Array[BattleEvent] = _auto(_model(_p(["Kindlop", "Puddlet", "Mossling"]), _p(["Shalebat", "Wickit", "Kelpup"]), [3, 3], false, 99))
	var b: Array[BattleEvent] = _auto(_model(_p(["Kindlop", "Puddlet", "Mossling"]), _p(["Shalebat", "Wickit", "Kelpup"]), [3, 3], false, 99))
	assert_eq(a.size(), b.size())
	for i: int in a.size():
		assert_eq(a[i].describe(), b[i].describe())

# --- Targeting and sweeps ----------------------------------------------------------

## A sure-hit sweep built in code, so misses never blur the counts.
func _sweep(power: int = 40) -> MoveData:
	var mv: MoveData = BattleFixtures.move(Elements.E.STONE, power)
	mv.target = "foes"
	mv.energy_cost = 1
	return mv

func _with_move(species: String, level: int, mv: MoveData) -> Spirling:
	var s: Spirling = BattleFixtures.make(species, level)
	s.moves = [mv] as Array[MoveData]
	return s

func test_single_target_move_hits_the_chosen_foe() -> void:
	var m := _model([BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])], _p(["Mossling", "Zephlet"]), [1, 2])
	m.start()
	var events: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(Side.PLAYER, 0, 0, 1),
		BattleAction.make_rest(Side.FOE, 0), BattleAction.make_rest(Side.FOE, 1)] as Array[BattleAction])
	var hits: Array = events.filter(func(e: BattleEvent) -> bool: return e.type == T.DAMAGE and int(e.data.side) == Side.FOE)
	assert_eq(hits.size(), 1)
	assert_eq(int(hits[0].data.slot), 1, "the aimed slot takes the hit")

func test_aim_at_a_fallen_foe_moves_to_the_next() -> void:
	var m := _model([BattleFixtures.make("Kindlop", 20, ["Cinder Nip"])], _p(["Mossling", "Zephlet"]), [1, 2])
	m.start()
	(m.party(Side.FOE)[1] as Spirling).hp = 0
	assert_eq(m.move_targets(Side.PLAYER, Database.move("Cinder Nip"), 1), [0] as Array[int])

func test_sweep_hits_every_foe_for_less() -> void:
	var quake: MoveData = Database.move("Quake Stomp")
	assert_true(quake.is_area(), "Quake Stomp sweeps the field")
	var solo := _model([_with_move("Calderox", 15, _sweep())], _p(["Zephlet"], 30), [1, 1], false, 5)
	solo.start()
	var one: Array[BattleEvent] = solo.submit_actions([BattleAction.make_move(Side.PLAYER, 0), BattleAction.make_rest(Side.FOE)] as Array[BattleAction])
	var crowd := _model([_with_move("Calderox", 15, _sweep())], _p(["Zephlet", "Zephlet", "Zephlet"], 30), [1, 3], false, 5)
	crowd.start()
	var acts: Array[BattleAction] = [BattleAction.make_move(Side.PLAYER, 0)]
	for slot: int in 3:
		acts.append(BattleAction.make_rest(Side.FOE, slot))
	var many: Array[BattleEvent] = crowd.submit_actions(acts)
	var hit_one: Array = one.filter(func(e: BattleEvent) -> bool: return e.type == T.DAMAGE)
	var hit_many: Array = many.filter(func(e: BattleEvent) -> bool: return e.type == T.DAMAGE and int(e.data.side) == Side.FOE)
	var hit_slots: Array = hit_many.map(func(e: BattleEvent) -> int: return int(e.data.slot))
	hit_slots.sort()
	assert_eq(hit_slots, [0, 1, 2], "a sweep reaches every foe")
	for e: BattleEvent in hit_many:
		assert_lt(int(e.data.amount), int(hit_one[0].data.amount), "each foe takes the spread share")
	var used: BattleEvent = BattleFixtures.first_of(many, T.MOVE_USED)
	assert_true(bool(used.data.area))
	assert_string_contains(used.describe(), "sweeps")

func test_sweep_self_effects_apply_once() -> void:
	var fx: Dictionary = {"id": &"stat_change", "stat": "atk", "self": true}
	assert_true(BattleModel._is_self_effect(fx))
	assert_false(BattleModel._is_self_effect({"id": &"stat_change", "self": false}))
	assert_true(BattleModel._is_self_effect({"id": &"heal_self"}))
	assert_false(BattleModel._is_self_effect({"id": &"drain"}))

func test_status_sweep_reaches_all_foes() -> void:
	var m := _model([BattleFixtures.make("Zippit", 25, ["Charged Mist"])], _p(["Mossling", "Puddlet"]), [1, 2], false, 3)
	m.start()
	(m.party(Side.PLAYER)[0] as Spirling).energy = 10
	var mv: MoveData = Database.move("Charged Mist")
	assert_true(mv.is_area())
	assert_eq(m.move_targets(Side.PLAYER, mv), [0, 1] as Array[int])

func test_ai_aims_at_the_weaker_matchup() -> void:
	# Kindlop's Ember move is strong into Mossling (Bloom) and weak into Puddlet (Tide).
	var m := _model(_p(["Puddlet", "Mossling"]), [BattleFixtures.make("Kindlop", 15, ["Cinder Nip"])], [2, 1])
	m.start()
	var a: BattleAction = BattleAI.new(1).choose(m, Side.FOE, 0)
	assert_eq(a.kind, BattleAction.Kind.MOVE)
	assert_eq(a.target_slot, 1, "greedy AI aims at the Bloom Spirling")

func test_random_ai_picks_a_standing_target() -> void:
	var m := _model(_p(["Puddlet", "Mossling", "Zippit"]), _p(["Kindlop"]), [3, 1], true, 8, 0)
	m.start()
	for i: int in 10:
		var a: BattleAction = BattleAI.new(0).choose(m, Side.FOE, 0)
		if a.kind == BattleAction.Kind.MOVE:
			assert_true(a.target_slot in m.standing_slots(Side.PLAYER))

# --- Faints and refills ------------------------------------------------------------

func test_fallen_player_slot_waits_for_a_pick() -> void:
	var m := _model(_p(["Kindlop", "Puddlet", "Mossling"]), [_with_move("Calderox", 40, _sweep())], [2, 1], false, 2)
	m.start()
	for s: Spirling in m.party(Side.PLAYER):
		s.hp = 1
	m.submit_actions([BattleAction.make_rest(Side.PLAYER, 0), BattleAction.make_rest(Side.PLAYER, 1), BattleAction.make_move(Side.FOE, 0)] as Array[BattleAction])
	assert_true(m.needs_player_switch(), "two slots fell, one Spirling waits on the bench")
	assert_eq(m.switch_slot(), 0)
	m.submit_switch(2)
	assert_false(m.needs_player_switch(), "no one is left for the second slot")
	assert_eq(m.active_index(Side.PLAYER, 0), 2)
	assert_eq(m.active_index(Side.PLAYER, 1), -1, "the empty slot stays empty")
	assert_eq(m.player_slots(), [0] as Array[int])

func test_foe_reserves_step_into_gaps() -> void:
	var m := _model([_with_move("Calderox", 40, _sweep())], _p(["Zippit", "Zippit", "Wickit"], 5), [1, 2], false, 2)
	m.start()
	for slot: int in 2:
		(m.active_spirling(Side.FOE, slot) as Spirling).hp = 1
	var events: Array[BattleEvent] = m.submit_actions([BattleAction.make_move(Side.PLAYER, 0)] as Array[BattleAction])
	assert_eq(_count(events, T.FAINTED), 2)
	assert_eq(_count(events, T.XP_GAINED), 2, "each fallen foe pays XP once")
	assert_eq(m.active_index(Side.FOE, 0), 2, "the reserve steps into the first gap")
	assert_eq(m.active_index(Side.FOE, 1), -1)
	assert_eq(m.phase, BattleModel.Phase.CHOOSE_ACTIONS)

func test_two_slots_cannot_swap_to_the_same_bench_spirling() -> void:
	var m := _model(_p(["Kindlop", "Puddlet", "Mossling"]), _p(["Zippit", "Wickit"]), [2, 2])
	m.start()
	assert_eq(m.swap_candidates(Side.PLAYER, 0), [2] as Array[int])
	var events: Array[BattleEvent] = m.submit_actions([BattleAction.make_swap(Side.PLAYER, 2, 0), BattleAction.make_swap(Side.PLAYER, 2, 1),
		BattleAction.make_rest(Side.FOE, 0), BattleAction.make_rest(Side.FOE, 1)] as Array[BattleAction])
	assert_eq(_count(events, T.SWAP_IN), 1, "the second swap finds the Spirling already on the field")

# --- Tag battles ---------------------------------------------------------------------

func _tag_model(seed_value: int = 21) -> BattleModel:
	var m := _model(_p(["Kindlop", "Puddlet"], 13), _p(["Shalebat", "Kelpup", "Mirkmole"], 13), [1, 2], false, seed_value)
	m.set_partner("Cartographer Kestra", _p(["Zephlet", "Zippit"], 13), 1)
	return m

func test_partner_fights_beside_the_player() -> void:
	var m := _tag_model()
	var events: Array[BattleEvent] = m.start()
	assert_eq(m.slot_count(Side.PLAYER), 2)
	assert_true(m.is_partner_slot(Side.PLAYER, 1))
	assert_eq(m.player_slots(), [0] as Array[int], "the player only picks for their own Spirling")
	var p: BattleEvent = BattleFixtures.first_of(events, T.PARTNER)
	assert_not_null(p)
	assert_eq(p.describe(), "Cartographer Kestra fights at your side!")
	# The ally acts on its own when the player submits only their action.
	var turn: Array[BattleEvent] = m.submit_actions([BattleAction.make_rest(Side.PLAYER, 0)] as Array[BattleAction])
	var ally_moves: Array = turn.filter(func(e: BattleEvent) -> bool: return e.type == T.MOVE_USED and int(e.data.side) == Side.PLAYER and int(e.data.slot) == 1)
	assert_eq(ally_moves.size(), 1, "Kestra's Spirling chose a move itself")

func test_partner_spirlings_are_not_the_players() -> void:
	var m := _tag_model()
	m.start()
	assert_eq(m.swap_candidates(Side.PLAYER, 0), [1] as Array[int], "you swap only to your own bench")
	assert_eq(m.swap_candidates(Side.PLAYER, 1), [3] as Array[int], "Kestra swaps only to hers")
	m.inventory = {"tonic": 1}
	assert_false(m.is_legal(BattleAction.make_item(Side.PLAYER, "tonic", 2)), "no items on the ally's Spirlings")
	for a: BattleAction in m.legal_actions(Side.PLAYER, 1):
		assert_ne(a.kind, BattleAction.Kind.ITEM)

func test_tag_battle_loss_counts_only_your_team() -> void:
	var m := _tag_model()
	m.start()
	assert_eq(m.own_alive_count(), 2)
	(m.party(Side.PLAYER)[0] as Spirling).hp = 0
	(m.party(Side.PLAYER)[1] as Spirling).hp = 0
	assert_eq(m.own_alive_count(), 0)
	assert_eq(m.alive_count(Side.PLAYER), 2, "Kestra still stands, but it is your fight")

func test_tag_battle_xp_goes_to_your_team_only() -> void:
	var m := _tag_model(4)
	var log: Array[BattleEvent] = _auto(m)
	for e: BattleEvent in log:
		if e.type == T.XP_GAINED:
			assert_lt(int(e.data.index), m.partner_start, "XP only for your own Spirlings")

func test_tag_battles_play_to_the_end() -> void:
	for seed_value: int in [1, 2, 3]:
		var log: Array[BattleEvent] = _auto(_tag_model(seed_value))
		assert_eq(log[log.size() - 1].type, T.BATTLE_END)

# --- Rift bosses -----------------------------------------------------------------------

func test_boss_scales_with_the_players_field() -> void:
	assert_eq(BattleRules.boss_hp_mult("ashen_heart", 1), 1.0, "a lone Spirling faces a normal-sized boss")
	assert_almost_eq(BattleRules.boss_hp_mult("ashen_heart", 4), 3.2, 0.001)
	assert_eq(BattleRules.boss_actions("ashen_heart", 1), 1)
	assert_eq(BattleRules.boss_actions("ashen_heart", 4), 2)
	assert_eq(BattleRules.boss_actions("nope", 4), 1)

func test_boss_acts_twice_against_four() -> void:
	var boss: Spirling = BattleFixtures.make("Smoldrake", 14)
	var base_hp: int = boss.max_hp()
	var m := _model(_p(["Kindlop", "Puddlet", "Zephlet", "Zippit"], 14), [boss], [4, 1], false, 6)
	m.foe_boss = "ashen_heart"
	var intro: Array[BattleEvent] = m.start()
	assert_gt(boss.max_hp(), base_hp * 3, "the boss swells against four")
	assert_eq(boss.hp, boss.max_hp())
	var b: BattleEvent = BattleFixtures.first_of(intro, T.BOSS)
	assert_not_null(b)
	assert_string_contains(BattleFixtures.first_of(intro, T.BATTLE_START).describe(), "rises from the Rift")
	var acts: Array[BattleAction] = []
	for slot: int in 4:
		acts.append(BattleAction.make_rest(Side.PLAYER, slot))
	var turn: Array[BattleEvent] = m.submit_actions(acts)
	var foe_moves: int = turn.filter(func(e: BattleEvent) -> bool: return int(e.data.get("side", -1)) == Side.FOE and (e.type == T.MOVE_USED or e.type == T.REST or e.type == T.STATUS_PREVENTED)).size()
	assert_eq(foe_moves, 2, "the boss gets two actions per turn")
	var last_foe: int = -1
	var last_player: int = -1
	for i: int in turn.size():
		var e: BattleEvent = turn[i]
		if e.type == T.REST and int(e.data.side) == Side.PLAYER:
			last_player = i
		if (e.type == T.MOVE_USED or e.type == T.REST) and int(e.data.side) == Side.FOE:
			last_foe = i
	assert_gt(last_foe, last_player, "the bonus action comes after everyone else")
	m.outcome = BattleModel.Outcome.WIN
	m.phase = BattleModel.Phase.REWARDS
	m._run()
	assert_eq(boss.hp_mult, 1.0, "the swelling ends with the battle")

func test_boss_battles_play_to_the_end() -> void:
	for f: Array in [[4, 1], [4, 2], [1, 1]]:
		var foes: Array[Spirling] = _p(["Riptail", "Kelpup"], 16)
		var m := _model(_p(["Kindlop", "Puddlet", "Zephlet", "Zippit"], 16), foes, [int(f[0]), int(f[1])], false, 13)
		m.foe_boss = "drowned_heart"
		var log: Array[BattleEvent] = _auto(m)
		assert_eq(log[log.size() - 1].type, T.BATTLE_END)

# --- Wild hordes and the Echo call -------------------------------------------------------

func test_echo_call_only_against_wild_foes() -> void:
	var tamer := _model(_p(["Kindlop", "Puddlet"]), _p(["Zippit", "Wickit"]), [2, 2], false)
	tamer.start()
	for slot: int in 2:
		for a: BattleAction in tamer.legal_actions(Side.PLAYER, slot):
			assert_ne(a.kind, BattleAction.Kind.BOND, "no Echo call against a Tamer's Spirlings")
	assert_false(tamer.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0, "", 0, 1)))
	var tag := _tag_model()
	tag.start()
	assert_false(tag.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0)), "nor in a tag battle")
	var boss := _model(_p(["Kindlop", "Puddlet"]), _p(["Smoldrake"]), [2, 1], false)
	boss.foe_boss = "ashen_heart"
	boss.start()
	assert_false(boss.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0)), "nor against a Rift boss")

func test_horde_bond_takes_one_and_the_rest_fight_on() -> void:
	var swarm: Array[Spirling] = _p(["Mirkmole", "Shalebat", "Wickit", "Mirkmole", "Shalebat"], 5)
	for s: Spirling in swarm:
		s.hp = 1
	var m := _model(_p(["Kindlop", "Puddlet"], 30), swarm, [2, 4], true, 1)
	m.start()
	assert_true(m.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0, "", 0, 2)))
	var target: Spirling = m.active_spirling(Side.FOE, 2)
	var bonded: bool = false
	var guard: int = 0
	while not bonded and guard < 40 and not m.is_finished():
		guard += 1
		m.submit_actions([BattleAction.make_bond(Side.PLAYER, 1.0, "", 0, 2), BattleAction.make_rest(Side.PLAYER, 1)] as Array[BattleAction])
		bonded = m.bonded != null
	assert_true(bonded, "a weakened swarm member bonds sooner or later")
	assert_eq(m.bonded, target, "the aimed Spirling is the one that bonded")
	assert_false(m.is_finished(), "the rest of the swarm fights on")
	assert_eq(m.outcome, BattleModel.Outcome.NONE)
	assert_false(m.is_standing(target))
	assert_eq(m.active_index(Side.FOE, 2), 4, "the swarm's reserve fills the gap")
	assert_false(m.is_legal(BattleAction.make_bond(Side.PLAYER, 1.0)), "one bond per battle")
	for s: Spirling in m.party(Side.PLAYER):
		s.restore()
	var log: Array[BattleEvent] = _auto(m)
	assert_eq(m.outcome, BattleModel.Outcome.WIN)
	assert_eq(m.bonded, target, "the bonded Spirling is kept after the win")
	assert_eq(log[log.size() - 1].type, T.BATTLE_END)

func test_horde_intro_text() -> void:
	var m := _model(_p(["Kindlop", "Puddlet"]), _p(["Mirkmole", "Shalebat", "Wickit", "Mirkmole"]), [2, 4], true)
	var start: BattleEvent = BattleFixtures.first_of(m.start(), T.BATTLE_START)
	assert_eq(start.describe(), "A hushed swarm of 4 Spirlings closes in!")

func test_running_from_a_horde_checks_the_fastest() -> void:
	var m := _model(_p(["Kindlop", "Puddlet"]), _p(["Mirkmole", "Zephlet"]), [2, 2], true)
	m.start()
	assert_true(m.is_legal(BattleAction.make_run(Side.PLAYER, 1)))

# --- Replays -------------------------------------------------------------------------

func test_multi_battle_replay_reproduces_the_outcome() -> void:
	var m := _tag_model(31)
	m.foe_items = {}
	var snap: Dictionary = BattleReplay.snapshot(m, "battle", "lake")
	assert_eq(snap.front, [1, 2])
	assert_eq(str(snap.partner.name), "Cartographer Kestra")
	var brain := BattleAI.new(1)
	m.start()
	var inputs: Array = []
	var guard: int = 0
	while not m.is_finished() and guard < 300:
		guard += 1
		if m.needs_player_switch():
			var idx: int = m.swap_candidates(Side.PLAYER, m.switch_slot())[0]
			inputs.append(BattleReplay.switch_to_dict(idx))
			m.submit_switch(idx)
			continue
		var acts: Array[BattleAction] = []
		for slot: int in m.player_slots():
			acts.append(brain.choose(m, Side.PLAYER, slot))
		inputs.append(BattleReplay.actions_to_dict(acts))
		m.submit_actions(acts)
	snap["inputs"] = inputs
	snap = JSON.parse_string(JSON.stringify(snap))
	assert_eq(BattleReplay.simulate(snap), m.outcome, "the replay ends the same way")

func test_boss_replay_keeps_the_boss() -> void:
	var m := _model(_p(["Kindlop", "Puddlet", "Zephlet"], 14), _p(["Smoldrake"], 14), [3, 1], false, 17)
	m.foe_boss = "ashen_heart"
	var snap: Dictionary = BattleReplay.snapshot(m, "warden", "ember")
	var rebuilt: BattleModel = BattleReplay.build_model(JSON.parse_string(JSON.stringify(snap)))
	assert_eq(rebuilt.foe_boss, "ashen_heart")
	assert_eq(rebuilt.front_size, [3, 1] as Array[int])

# --- Story set pieces --------------------------------------------------------------------

func _npc(map_id: String, npc_id: String) -> Dictionary:
	var m: MapData = MapData.load_map(map_id)
	for n: Dictionary in m.npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_story_has_uneven_battles() -> void:
	var formats: Dictionary = {}
	for entry: Array in [["cinder_rift", "ashen_heart"], ["tide_rift", "drowned_heart"], ["tide_rift", "mystic"], ["saltmarsh", "kestra_tag"], ["murk_hollow", "hush_swarm"]]:
		var def: Dictionary = _npc(entry[0], entry[1])
		assert_false(def.is_empty(), "%s exists" % [entry])
		assert_true(WorldValidator.format_errors(def).is_empty(), "%s has a valid format" % [entry])
		formats[entry[1]] = TrainerData.front(def)
	assert_eq(formats.ashen_heart, [4, 1] as Array[int], "a 4v1 Rift boss")
	assert_eq(formats.drowned_heart, [4, 2] as Array[int], "a 4v2 Rift boss")
	assert_eq(formats.mystic, [3, 3] as Array[int], "a 3v3 duel")
	assert_eq(formats.kestra_tag, [1, 2] as Array[int], "you and Kestra against two")
	assert_eq(formats.hush_swarm, [2, 4] as Array[int], "a horde")

func test_story_battle_info_carries_the_format() -> void:
	var rng := RandomNumberGenerator.new()
	var tag: Dictionary = _npc("saltmarsh", "kestra_tag")
	var info: Dictionary = TrainerData.battle_info(tag, TrainerData.build_team(tag, "Kindlop", rng), 1)
	assert_eq(str(info.partner.name), "Cartographer Kestra")
	assert_false(bool(info.wild))
	var swarm: Dictionary = _npc("murk_hollow", "hush_swarm")
	var sinfo: Dictionary = TrainerData.battle_info(swarm, TrainerData.build_team(swarm, "Kindlop", rng), 1)
	assert_true(bool(sinfo.wild), "the horde is wild, so the Echo call works there")
	assert_eq(int(sinfo.money), 0)
	var heart: Dictionary = _npc("cinder_rift", "ashen_heart")
	var hinfo: Dictionary = TrainerData.battle_info(heart, TrainerData.build_team(heart, "Kindlop", rng), 0)
	assert_eq(str(hinfo.boss), "ashen_heart")
	assert_eq(int(hinfo.ai), TrainerData.WARDEN_MIN_AI, "bosses play at least greedy")
	assert_true(bool(hinfo.warden), "boss fights use the Warden music")

func test_format_errors_catch_bad_data() -> void:
	assert_false(WorldValidator.format_errors({"front": [5, 1]}).is_empty())
	assert_false(WorldValidator.format_errors({"front": [1]}).is_empty())
	assert_false(WorldValidator.format_errors({"boss": "nope"}).is_empty())
	assert_false(WorldValidator.format_errors({"partner": {"name": "X"}}).is_empty())
	assert_false(WorldValidator.format_errors({"wild": true, "partner": {"name": "X", "team": [{"species": "Zippit"}]}}).is_empty())
	assert_true(WorldValidator.format_errors({"front": [2, 2]}).is_empty())

func test_story_set_pieces_have_quests() -> void:
	var text: String = FileAccess.get_file_as_string("res://data/quests.json")
	for flag: String in ["kestra_marsh_tag", "hollow_swarm_cleared", "cinder_heart_mended", "tide_heart_mended"]:
		assert_string_contains(text, flag)
