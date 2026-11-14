extends GutTest
## Plan area 6: hit-stop on the last hit of a battle (2265), only first and last of a
## spread art (2266), and the attacker turning toward its target in formation (2336).

func _ev(t: BattleEvent.Type, d: Dictionary = {}) -> BattleEvent:
	return BattleEvent.new(t, d)

func test_single_hit_is_normal() -> void:
	var ev: Array[BattleEvent] = [_ev(BattleEvent.Type.MOVE_USED), _ev(BattleEvent.Type.DAMAGE, {"hp": 5})]
	assert_eq(BattleScene.hitstop_kind(ev, 1), "normal")

func test_battle_ending_hit_is_final() -> void:
	var ev: Array[BattleEvent] = [_ev(BattleEvent.Type.MOVE_USED), _ev(BattleEvent.Type.DAMAGE, {"hp": 0}),
		_ev(BattleEvent.Type.FAINTED), _ev(BattleEvent.Type.XP_GAINED), _ev(BattleEvent.Type.BATTLE_END)]
	assert_eq(BattleScene.hitstop_kind(ev, 1), "final")

func test_faint_without_end_is_normal() -> void:
	var ev: Array[BattleEvent] = [_ev(BattleEvent.Type.MOVE_USED), _ev(BattleEvent.Type.DAMAGE, {"hp": 0}),
		_ev(BattleEvent.Type.FAINTED), _ev(BattleEvent.Type.MOVE_USED), _ev(BattleEvent.Type.DAMAGE, {"hp": 3})]
	assert_eq(BattleScene.hitstop_kind(ev, 1), "normal")

func test_spread_art_stops_on_first_and_last_only() -> void:
	var ev: Array[BattleEvent] = [_ev(BattleEvent.Type.MOVE_USED)]
	for i: int in 4:
		ev.append(_ev(BattleEvent.Type.DAMAGE, {"hp": 5}))
	ev.append(_ev(BattleEvent.Type.MOVE_USED))
	ev.append(_ev(BattleEvent.Type.DAMAGE, {"hp": 5}))
	assert_eq(BattleScene.hitstop_kind(ev, 1), "normal")
	assert_eq(BattleScene.hitstop_kind(ev, 2), "")
	assert_eq(BattleScene.hitstop_kind(ev, 3), "")
	assert_eq(BattleScene.hitstop_kind(ev, 4), "normal")
	assert_eq(BattleScene.hitstop_kind(ev, 6), "normal", "the next art counts on its own")

func test_status_ticks_do_not_count_as_hits() -> void:
	var ev: Array[BattleEvent] = [_ev(BattleEvent.Type.MOVE_USED), _ev(BattleEvent.Type.DAMAGE, {"hp": 5}),
		_ev(BattleEvent.Type.DAMAGE, {"hp": 4, "status_tick": true}), _ev(BattleEvent.Type.DAMAGE, {"hp": 3})]
	assert_eq(BattleScene.hitstop_kind(ev, 1), "normal")
	assert_eq(BattleScene.hitstop_kind(ev, 3), "normal")

func test_final_hitstop_time() -> void:
	assert_almost_eq(Juice.hitstop_time(0.1, BattleScene.FINAL_HITSTOP), 0.12, 0.001)
	assert_almost_eq(Juice.hitstop_time(0.0), Juice.HITSTOP_BASE, 0.001)

func test_turn_toward_other_half() -> void:
	assert_eq(BattleScene.turn_toward(20.0, 120.0, 72.0), 1)
	assert_eq(BattleScene.turn_toward(120.0, 20.0, 72.0), -1)
	assert_eq(BattleScene.turn_toward(20.0, 50.0, 72.0), 0, "same half: no turn")
	assert_eq(BattleScene.turn_toward(100.0, 130.0, 72.0), 0)
