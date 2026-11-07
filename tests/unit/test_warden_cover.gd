extends GutTest
## Plan area 2, items 680-681: Warden cover in the lexicon, Warden profiles from Tamer on.

func _warden(map_id: String, npc_id: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	for n: Variant in d.npcs:
		if str(n.get("id", "")) == npc_id:
			return n
	return {}

func test_cover_spirlings_in_team() -> void:
	for row: Array in [["cinder_rift", "warden_orrin", "Shalebat"], ["tide_rift", "warden_maelis", "Zippit"]]:
		var def: Dictionary = _warden(row[0], row[1])
		var species: Array = []
		for d: int in [1, 2, 3]:
			for e: Variant in TrainerData.team_entries(def, "", d):
				species.append(str(e.species))
		assert_true(row[2] in species, "%s brings %s" % [row[1], row[2]])
		assert_true(Lexicon.has_entry(str(def.get("lexicon", ""))), "%s has a lexicon entry" % row[1])
		assert_string_contains(Lexicon.text(str(def.lexicon)), row[2])

func test_profile_from_tamer() -> void:
	for row: Array in [["cinder_rift", "warden_orrin", "hothead"], ["tide_rift", "warden_maelis", "tactician"]]:
		var def: Dictionary = _warden(row[0], row[1])
		assert_eq(TrainerData.profile_for(def, 0), "", "Story keeps the plain AI")
		assert_eq(TrainerData.profile_tune(def, 0), {})
		for d: int in [1, 2, 3]:
			assert_eq(TrainerData.profile_for(def, d), row[2])
			assert_almost_eq(float(TrainerData.profile_tune(def, d).get("field_w", 0.0)), 1.5, 0.001)

func test_tune_applies_and_replays() -> void:
	var ai := BattleAI.new(2)
	ai.set_profile("hothead", {"field_w": 1.5})
	assert_almost_eq(ai.weight("field_w"), 1.5, 0.001)
	assert_almost_eq(float(BattleAI.profiles().hothead.field_w), 1.0, 0.001, "the shared profile stays as it is")
	ai.set_profile("hothead")
	assert_almost_eq(ai.weight("field_w"), 1.0, 0.001)
	var rng := RandomNumberGenerator.new()
	var m := BattleModel.new([Spirling.new(Database.species("Kindlop"), 10, rng)] as Array[Spirling],
		[Spirling.new(Database.species("Zippit"), 10, rng)] as Array[Spirling], false, 5, 2)
	m.ai.set_profile("tactician", {"field_w": 1.5})
	var back: BattleModel = BattleReplay.build_model(BattleReplay.snapshot(m, "", ""))
	assert_eq(back.ai.profile_id, "tactician")
	assert_almost_eq(back.ai.weight("field_w"), 1.5, 0.001)

func test_lexicon_add_once() -> void:
	var rec: Dictionary = {}
	assert_true(Lexicon.add(rec, "warden_orrin"))
	assert_false(Lexicon.add(rec, "warden_orrin"))
	assert_false(Lexicon.add(rec, "no_such_entry"))
	assert_eq(Lexicon.collected(rec), ["warden_orrin"] as Array[String])

func test_goal_lore_ids_exist() -> void:
	for k: String in BattleGoals.all():
		var lore: String = str((BattleGoals.all()[k] as Dictionary).get("reward", {}).get("lore", ""))
		if not lore.is_empty():
			assert_true(Lexicon.has_entry(lore), lore)
