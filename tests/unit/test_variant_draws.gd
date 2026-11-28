extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 799, 800): towers and the weekly
## challenge draw rule variants by seed, and the AI reckons with "No Rest" and "Stage Still".

func before_all() -> void:
	Database.load_all()

func test_draws_are_seeded_compatible_and_capped() -> void:
	for sd: int in 30:
		var ids: Array[String] = BattleRules.draw_variants(sd, 3)
		assert_eq(ids, BattleRules.draw_variants(sd, 3), "same seed, same variants")
		assert_eq(BattleRules.variant_conflict(ids), "", str(ids))
		assert_between(ids.size(), 1, BattleRules.MAX_VARIANTS)
	assert_eq(BattleRules.draw_variants(5, 0), [] as Array[String])
	assert_eq(BattleRules.draw_variants(5, 9).size() <= BattleRules.MAX_VARIANTS, true)

func test_tower_floors_get_variants_from_the_second_section_and_show_them() -> void:
	var t: Dictionary = RiftTower.list()[0]
	var run := RiftTower.new(t, 42)
	assert_eq(run.variants_for(0), [] as Array[String])
	assert_eq(run.floor_card(0), RiftTower.floor_label(t, 0))
	var mid: Array[String] = run.variants_for(RiftTower.SECTION)
	assert_eq(mid.size(), 1)
	assert_eq(mid, RiftTower.new(t, 42).variants_for(RiftTower.SECTION), "same run seed, same variants")
	assert_string_contains(run.floor_card(RiftTower.SECTION), str(BattleRules.variants()[mid[0]].label))
	assert_eq(run.variants_for(RiftTower.SECTION * 2).size(), 2)

func test_weekly_challenge_has_a_seeded_variant_in_its_preview() -> void:
	var a := WeeklyChallenge.new("2026-W45", 30)
	var b := WeeklyChallenge.new("2026-W45", 30)
	assert_true(BattleRules.variants().has(a.variant))
	assert_eq(a.variant, b.variant)
	assert_eq(a.variant_ids(), [a.variant] as Array[String])
	assert_string_contains(a.preview_text(), str(BattleRules.variants()[a.variant].label))
	var seen: Dictionary = {}
	for w: int in range(1, 30):
		seen[WeeklyChallenge.new("2026-W%02d" % w, 30).variant] = true
	assert_gt(seen.size(), 3, "the variant changes from week to week")

func _model(ids: Array[String], my_moves: Array[String]) -> BattleModel:
	var me: Spirling = BattleFixtures.make("Kindlop", 20, my_moves)
	var foe: Spirling = BattleFixtures.make("Mossling", 20, ["Bowl Over"] as Array[String])
	var m := BattleModel.new([me] as Array[Spirling], [foe] as Array[Spirling], false, 7, 2)
	m.variants = ids
	m.start()
	return m

func test_ai_reckons_with_the_energy_gain_of_the_variants() -> void:
	assert_eq(BattleAI.energy_gain(_model([] as Array[String], ["Cinder Dash"] as Array[String])), 1)
	assert_eq(BattleAI.energy_gain(_model(["no_rest"] as Array[String], ["Cinder Dash"] as Array[String])), 3)
	assert_eq(BattleAI.energy_gain(_model(["full_charge"] as Array[String], ["Cinder Dash"] as Array[String])), 0)

func test_ai_scores_the_stage_part_of_an_art_at_zero_under_stage_still() -> void:
	var plain: BattleModel = _model([] as Array[String], ["Glow Knuckle"] as Array[String])
	var still: BattleModel = _model(["stage_still"] as Array[String], ["Glow Knuckle"] as Array[String])
	assert_false(BattleAI.stages_locked(plain))
	assert_true(BattleAI.stages_locked(still))
	var ai := BattleAI.new(2)
	var with_stage: float = ai.score_move(plain, BattleModel.Side.PLAYER, 0)
	var without: float = ai.score_move(still, BattleModel.Side.PLAYER, 0)
	assert_lt(without, with_stage, "the stage bonus is gone under Stage Still")
