extends GutTest
## KAMPF_PLAN_1000 items 978 (performance on older phones) and 980 (memory budget). The budgets
## for the reference phone live in data/battle_budget.json; CI runs the battle code and scales the
## measured time by cpu_factor. The heaviest everyday cases: 2 vs 2 with the Master AI on both
## sides, a Warden rule and a field, and a boss fight against a full front.

const BattleSetup := preload("res://tools/battle_editor/BattleSetup.gd")

var budget: Dictionary = {}

func before_all() -> void:
	budget = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_budget.json"))
	Database.load_all()

func _setups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in int(budget.battles):
		out.append({"player": [["Kindlop", 30], ["Zippit", 30], ["Wickit", 30], ["Mossling", 30]],
			"foe": [["Mossling", 30], ["Wickit", 30], ["Zippit", 30], ["Kindlop", 30]],
			"field": "static_veil", "rule": "ember_pulse", "seed": 100 + i, "ai": 3, "front": [2, 2]})
	out.append({"player": [["Kindlop", 30], ["Zippit", 30], ["Wickit", 30], ["Mossling", 30]], "foe": [["Mossling", 40]],
		"boss": "ashen_heart", "seed": 7, "ai": 3, "front": [4, 1]})
	return out

func test_turns_fit_the_old_phone() -> void:
	var turns: int = 0
	var t0: int = Time.get_ticks_usec()
	for s: Dictionary in _setups():
		var r: Dictionary = BattleSetup.play(s)
		assert_eq(r.errors, PackedStringArray())
		turns += int(r.turns)
	var ms_per_turn: float = (Time.get_ticks_usec() - t0) / 1000.0 / maxi(turns, 1)
	var phone_ms: float = ms_per_turn * float(budget.cpu_factor)
	gut.p("battle turn: %.2f ms here, about %.0f ms on the reference phone (budget %d ms), %d turns" % [ms_per_turn, phone_ms, budget.turn_ms, turns])
	assert_gt(turns, 20)
	assert_lt(phone_ms, float(budget.turn_ms))

func test_battle_data_loads_fast_enough() -> void:
	var t0: int = Time.get_ticks_usec()
	Database.reload_data()
	BattleRules.reload_tables()
	var phone_ms: float = (Time.get_ticks_usec() - t0) / 1000.0 * float(budget.cpu_factor)
	gut.p("battle data load: about %.0f ms on the reference phone (budget %d ms)" % [phone_ms, budget.data_load_ms])
	assert_lt(phone_ms, float(budget.data_load_ms))

func test_battles_stay_in_the_memory_budget() -> void:
	BattleSetup.play(_setups()[0])
	var base: int = OS.get_static_memory_usage()
	var peak: int = 0
	for s: Dictionary in _setups():
		var m: BattleModel = BattleSetup.build(s)
		m.start()
		var brain := BattleAI.new(3)
		while not m.is_finished() and m.turn < BattleSetup.MAX_TURNS:
			if m.needs_player_switch():
				m.submit_switch(brain.choose_replacement(m, BattleModel.Side.PLAYER, m.switch_slot()))
				continue
			var acts: Array[BattleAction] = []
			for slot: int in m.player_slots():
				acts.append(brain.choose(m, BattleModel.Side.PLAYER, slot))
			m.submit_actions(acts)
			peak = maxi(peak, OS.get_static_memory_usage() - base)
	var left: int = OS.get_static_memory_usage() - base
	gut.p("battle memory: peak +%d KB (budget %d MB), left after the battles %d KB (budget %d KB)" % [peak / 1024, budget.memory_mb, left / 1024, budget.leak_kb])
	assert_lt(peak, int(budget.memory_mb) * 1048576)
	assert_lt(left, int(budget.leak_kb) * 1024)
