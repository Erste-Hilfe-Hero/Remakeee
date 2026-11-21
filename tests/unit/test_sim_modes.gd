extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 817, 818, 820, 821): simulator
## modes ladder, mono and goals, and the --field / --variant switches.

const SimTool: GDScript = preload("res://tools/balance_sim.gd")

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	BalanceSim.sim_field = ""
	BalanceSim.sim_variants = []

func test_ladder_has_a_row_per_tier_with_its_target_and_is_seeded() -> void:
	var r: Dictionary = BalanceSim.run_ladder(20, 6, 3)
	assert_eq(r.tiers.keys(), ["1", "2", "3"])
	for k: String in r.tiers:
		assert_between(float(r.tiers[k].rate), 0.0, 1.0)
		assert_eq(float(r.tiers[k].target), float(BalanceSim.LADDER_TARGETS[int(k)]))
	assert_eq(BalanceSim.run_ladder(20, 6, 3), r, "same seed, same ladder")
	assert_string_contains(BalanceSim.ladder_report(r), "| 3 | 2 |")

func test_mono_counts_every_element_with_species_and_flags_the_band() -> void:
	var pools: Dictionary = BalanceSim.mono_pools(36)
	assert_gte(pools.size(), 6)
	var r: Dictionary = BalanceSim.run_mono(36, 16, 5)
	var games: int = 0
	for e: String in r.elements:
		var row: Dictionary = r.elements[e]
		games += int(row.wins) + int(row.losses) + int(row.draws)
		var wr: float = float(row.win_rate)
		assert_eq(bool(row.ok), wr >= BalanceSim.MONO_BAND.x and wr <= BalanceSim.MONO_BAND.y, e)
	assert_eq(games, 32, "every battle counts for both elements")
	assert_string_contains(BalanceSim.mono_report(r), "| Element |")

func test_goals_mode_rates_every_goal() -> void:
	var r: Dictionary = BalanceSim.run_goals(2, 1234)
	assert_eq(r.goals.size(), BattleGoals.all().size())
	assert_string_contains(BalanceSim.goals_report(r), "crowcrest/lio")

func test_field_and_variant_switches_reach_every_battle() -> void:
	assert_eq(SimTool.apply_switches(BalanceSim, {"field": "high_tide", "variant": "glass_blades, late_end"}), "")
	assert_eq(BalanceSim.sim_field, "high_tide")
	assert_eq(BalanceSim.sim_variants, ["glass_blades", "late_end"] as Array[String])
	var m := BattleModel.new([BattleFixtures.make("Kindlop", 20)] as Array[Spirling], [BattleFixtures.make("Mossling", 20)] as Array[Spirling], false, 1, 1)
	BalanceSim._apply_switches(m)
	assert_eq(m.field, "high_tide")
	assert_eq(m.variants, ["glass_blades", "late_end"] as Array[String])

func test_bad_switches_are_refused() -> void:
	assert_string_contains(SimTool.apply_switches(BalanceSim, {"field": "moon_dust"}), "moon_dust")
	assert_false(SimTool.apply_switches(BalanceSim, {"variant": "spark_poor,full_charge"}).is_empty())
	assert_false(SimTool.apply_switches(BalanceSim, {"variant": "nope"}).is_empty())
