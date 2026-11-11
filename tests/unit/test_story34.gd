extends GutTest
## Act III and Act IV clan betrayals, trust choices and the Solenne reckoning (data/clans.json).

const ACT_BETRAYALS: Dictionary = {3: ["sable_sale", "marlo_fate", "liss_spy", "fenrick_seal"],
	4: ["basin", "ottilie_throne", "fenrick_throne"]}

func before_each() -> void:
	Database.load_all()
	GameState.new_game(GameState.Difficulty.TAMER, "Mara", 0, Database.STARTERS[0], 1)

func test_several_betrayals_in_acts_three_and_four() -> void:
	for act: int in ACT_BETRAYALS:
		var ids: Array = ACT_BETRAYALS[act]
		assert_gte(ids.size(), 3, "act %d" % act)
		for id: String in ids:
			var b: Dictionary = Trust.betrayal(id)
			assert_eq(int(b.get("act", 0)), act, id)
	for n: int in range(7, 12):
		var found: bool = false
		for id: Variant in Trust.data().betrayals:
			if "clan_b%d" % n in Trust.effects(Trust.betrayal(str(id)), "struck").get("flags", []):
				found = true
		assert_true(found, "clan_b%d is set" % n)

func test_watching_liss_catches_her() -> void:
	var b: Dictionary = Trust.betrayal("liss_spy")
	assert_eq(Trust.betrayal_result(b, {}, {}), "struck")
	assert_eq(Trust.betrayal_result(b, {"c3_liss_watched": true}, {}), "caught")

func test_hearing_both_offers_catches_the_poisoned_wax() -> void:
	var o: Dictionary = Trust.betrayal("ottilie_throne")
	var f: Dictionary = Trust.betrayal("fenrick_throne")
	assert_eq(Trust.betrayal_result(o, {"c4_heard_ottilie": true}, {}), "struck", "one offer is not enough")
	assert_eq(Trust.betrayal_result(o, {"c4_heard_fenrick": true}, {}), "caught")
	assert_eq(Trust.betrayal_result(f, {"c4_heard_ottilie": true}, {}), "caught")
	assert_eq(Trust.betrayal_result(f, {"c4_wax_checked": true}, {}), "caught")

func test_marlo_saves_you_from_fenrick_only_with_trust() -> void:
	var b: Dictionary = Trust.betrayal("fenrick_seal")
	assert_eq(Trust.betrayal_result(b, {}, {}), "caught")
	assert_eq(Trust.betrayal_result(b, {}, {"trust_marlo": -15}), "struck", "one alibi too many")

func test_asking_tobs_nicely_keeps_him_loyal() -> void:
	var d: Dictionary = Trust.favor("tobs_dig")
	var vars: Dictionary = {}
	assert_eq(Trust.resolve(d, Trust.trust_in("tobs", vars), Trust.use_in("tobs", vars), 0.9), "betray")
	Trust.apply_values({"trust": {"tobs": 10}}, vars)
	assert_ne(Trust.resolve(d, Trust.trust_in("tobs", vars), Trust.use_in("tobs", vars), 0.9), "betray")

func test_act_four_figures_have_dialogue_and_the_reckoning_scene_exists() -> void:
	for ref: String in ["clans/ottilie_4", "clans/fenrick_4", "clans/vash_4", "clans/pip_4", "clans/wren_4",
			"clans/kerr", "clans/grell_4", "clans/sable_4", "clans/tobs_4", "clans/reckon_pick", "clans/finale_coda"]:
		assert_true(Dialogue.exists(ref), ref)
	assert_true(FileAccess.file_exists("res://data/scenes/solenne_reckoning.json"))
	for id: String in ["basin_wardens", "throne_guard", "dune_hands", "kerr_haldane"]:
		assert_true(StoryBattles.has(id), id)
	assert_eq(Dialogue.choices_for(Dialogue.get_entry("clans/reckon_pick"), {}).size(), 3, "three endings for the deeds")

func test_clan_data_still_valid() -> void:
	assert_eq(Trust.validate(), PackedStringArray())
