extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 796, 797): variant banners, the
## variant list of the battle log and replays with variants this version doesn't know.

func before_all() -> void:
	Database.load_all()

func _model(ids: Array[String]) -> BattleModel:
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, 7, 1)
	m.variants = ids
	return m

func test_every_variant_has_its_own_known_seal() -> void:
	var seen: Dictionary = {}
	for id: String in BattleRules.variants():
		var seal: String = str(BattleRules.variants()[id].get("symbol", ""))
		assert_has(BattleRules.VARIANT_SYMBOLS, seal, id)
		assert_false(seen.has(seal), "%s shares its seal" % id)
		seen[seal] = id

func test_battle_start_shows_one_banner_per_variant() -> void:
	var m: BattleModel = _model(["swap_toll", "late_end"] as Array[String])
	var shown: Array[String] = []
	for e: BattleEvent in m.start():
		if e.type == BattleEvent.Type.RULE and e.data.has("variant"):
			shown.append(str(e.data.variant))
			assert_eq(str(e.data.symbol), str(BattleRules.variants()[str(e.data.variant)].symbol))
			assert_string_contains(e.describe(), str(e.data.label))
	assert_eq(shown, ["swap_toll", "late_end"] as Array[String])

func test_no_variant_no_banner_and_no_list() -> void:
	var m: BattleModel = _model([] as Array[String])
	for e: BattleEvent in m.start():
		assert_false(e.type == BattleEvent.Type.RULE and e.data.has("variant"))
	assert_eq(BattleScene.variant_list(m), "")

func test_log_lists_the_variants_in_play() -> void:
	var m: BattleModel = _model(["glass_blades"] as Array[String])
	m.start()
	var text: String = BattleScene.variant_list(m)
	assert_string_contains(text, "Glass Blades")
	assert_string_contains(text, "half its Vigor")

func test_banner_draws_variant_seals_and_falls_back_to_the_diamond() -> void:
	var b := RuleBanner.new()
	add_child_autofree(b)
	b.show_rule("Swap Toll", false, 200, 10, "toll")
	assert_eq(b.symbol, "toll")
	b.show_rule("Undertow", false, 200, 10, "nonsense")
	assert_eq(b.symbol, "")

func test_replay_keeps_variant_ids() -> void:
	var snap: Dictionary = BattleReplay.snapshot(_model(["no_rest"] as Array[String]), "battle", "lake")
	assert_eq(snap.variants, ["no_rest"])
	assert_eq(BattleReplay.problem(snap), "")

func test_replay_with_an_unknown_variant_is_refused_with_a_message() -> void:
	var snap: Dictionary = BattleReplay.snapshot(_model([] as Array[String]), "battle", "lake")
	snap.variants = ["moon_gravity"]
	assert_string_contains(BattleReplay.problem(snap), "moon_gravity")
	assert_null(BattleReplay.build_model(snap))
	assert_null(BattleReplay.run(snap))
	assert_eq(BattleReferee.check(snap, {}).detail.get("reason", ""), "variant")

func test_replay_with_clashing_variants_is_refused() -> void:
	var snap: Dictionary = BattleReplay.snapshot(_model([] as Array[String]), "battle", "lake")
	snap.variants = ["spark_poor", "full_charge"]
	assert_false(BattleReplay.problem(snap).is_empty())
	assert_null(BattleReplay.build_model(snap))
