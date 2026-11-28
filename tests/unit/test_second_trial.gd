extends GutTest
## Plan area 2, items 682-684: the Warden Second Trial.

const BOTH: Dictionary = {"rift_cinder_sealed": true, "rift_tide_sealed": true}

func _warden(map_id: String, npc_id: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	for n: Variant in d.npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func _species(def: Dictionary, difficulty: int) -> Array:
	var out: Array = []
	for s: Spirling in TrainerData.build_team(def, "", RandomNumberGenerator.new(), difficulty):
		out.append("%s %d" % [s.data.species_name, s.level])
	return out

func test_orrin_rift_born_team() -> void:
	var def: Dictionary = TrainerData.second_trial_def(_warden("cinder_rift", "warden_orrin"), "cinder_rift")
	assert_eq(_species(def, 3), ["Calderox 30", "Smoldrake 28", "Shalebat 27", "Zippit 27", "Kindlop 26"])
	assert_eq(TrainerData.rule_for(def, 0), "ember_pulse+ash_rain")
	assert_eq(TrainerData.rule_for(def, 3), "ember_pulse+ash_rain")

func test_maelis_teams() -> void:
	var def: Dictionary = TrainerData.second_trial_def(_warden("tide_rift", "warden_maelis"), "tide_rift")
	assert_eq(_species(def, 3), ["Leviarch 31", "Riptail 29", "Tempestrel 29", "Kelphound 28", "Glimmerax 28"])
	assert_eq(_species(def, 1), ["Leviarch 31", "Riptail 29", "Tempestrel 29"], "Tamer: only the first three")
	assert_eq(BattleRules.split_rules(TrainerData.rule_for(def, 1)), ["undertow", "tide_turn"] as Array[String])

func test_opens_after_both_rifts_once() -> void:
	var base: Dictionary = _warden("cinder_rift", "warden_orrin")
	var flags: Dictionary = {TrainerData.beaten_flag(base, "cinder_rift"): true}
	assert_false(TrainerData.can_second_trial(base, "cinder_rift", flags), "needs both Rifts")
	flags.merge(BOTH)
	assert_true(TrainerData.can_second_trial(base, "cinder_rift", flags))
	var flag: String = TrainerData.beaten_flag(TrainerData.second_trial_def(base, "cinder_rift"), "cinder_rift")
	assert_ne(flag, TrainerData.beaten_flag(base, "cinder_rift"))
	flags[flag] = true
	assert_false(TrainerData.can_second_trial(base, "cinder_rift", flags), "won once, gone")
	assert_false(TrainerData.can_second_trial(base, "cinder_rift", BOTH), "the first fight comes first")

func test_both_rules_run_in_battle() -> void:
	var def: Dictionary = TrainerData.second_trial_def(_warden("cinder_rift", "warden_orrin"), "cinder_rift")
	var rng := RandomNumberGenerator.new()
	var foes: Array[Spirling] = TrainerData.build_team(def, "", rng, 1)
	var m := BattleModel.new([Spirling.new(Database.species("Riptail"), 30, rng)] as Array[Spirling], foes, false, 9, 1)
	m.foe_rule = TrainerData.rule_for(def, 1)
	var rules: Array = []
	for e: BattleEvent in m.start():
		if e.type == BattleEvent.Type.RULE:
			rules.append(str(e.data.rule))
	assert_eq(rules, ["ember_pulse", "ash_rain"])
	assert_eq(m.field, "ash_storm")
