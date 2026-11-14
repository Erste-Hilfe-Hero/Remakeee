extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 830, 831, 833): runs over several
## seeds, the mirror check and the list of rarely chosen new arts.

func before_all() -> void:
	Database.load_all()

func test_seeds_give_mean_and_spread_per_species() -> void:
	var r: Dictionary = BalanceSim.run_seeds("team", 30, 12, 5, 3, 1)
	assert_eq(int(r.count), 3)
	assert_eq(r.seeds, [5, BalanceSim.nth_seed(5, 1), BalanceSim.nth_seed(5, 2)])
	assert_eq((r.first as Dictionary).species.keys(), r.species.keys())
	for n: String in r.species:
		var row: Dictionary = r.species[n]
		var rates: Array = row.rates
		assert_eq(rates.size(), 3, n)
		assert_almost_eq(float(row.spread), float(rates.max()) - float(rates.min()), 0.002, n)
		assert_eq(bool(row.uncertain), float(row.spread) > BalanceSim.SEED_SPREAD_MAX + 0.0005, n)
		assert_between(float(row.mean), float(rates.min()) - 0.001, float(rates.max()) + 0.001, n)
	var text: String = BalanceSim.seeds_report(r)
	assert_string_contains(text, "Spread over 3 seeds")
	assert_eq(BalanceSim.run_seeds("team", 30, 12, 5, 3, 1).species, r.species, "same seeds, same numbers")

func test_the_tool_reads_seeds_and_mirror() -> void:
	var tool: GDScript = load("res://tools/balance_sim.gd")
	var opts: Dictionary = tool.call("parse_args", PackedStringArray(["--mode", "mirror", "--seeds", "4"]))
	assert_eq(opts.mode, "mirror")
	assert_eq(int(opts.seeds), 4)

func test_a_double_knockout_is_a_draw_in_the_sim() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var mine: Array[Spirling] = [Spirling.new(Database.species("Lumenewt"), 20, rng)]
	var theirs: Array[Spirling] = [Spirling.new(Database.species("Lumenewt"), 20, rng)]
	var m := BattleModel.new(mine, theirs, false, 3, 1)
	m.outcome = BattleModel.Outcome.WIN
	assert_eq(BalanceSim.sim_winner(m), 0)
	mine[0].hp = 0
	assert_eq(BalanceSim.sim_winner(m), -1, "both sides out at once")
	m.outcome = BattleModel.Outcome.LOSS
	assert_eq(BalanceSim.sim_winner(m), 1)

func test_mirror_duels_favour_neither_side() -> void:
	var r: Dictionary = BalanceSim.run_mirror(20, 30, 11)
	assert_eq(r.species.size(), BalanceSim.valid_species(20).size())
	assert_between(float(r.share), BalanceSim.MIRROR_BAND.x, BalanceSim.MIRROR_BAND.y, "player side over all")
	for n: String in r.species:
		var row: Dictionary = r.species[n]
		assert_eq(bool(row.ok), float(row.share) >= BalanceSim.MIRROR_BAND.x and float(row.share) <= BalanceSim.MIRROR_BAND.y, n)
	assert_string_contains(BalanceSim.mirror_report(r), "Player side over all")

func test_rare_new_arts_are_the_carried_ones_under_one_percent() -> void:
	var carried: Array[String] = BalanceSim.carried_new_arts(36)
	assert_gt(carried.size(), 0)
	for art: String in carried:
		assert_true(art in BalanceSim.NEW_ARTS, art)
	var elements: Dictionary = {}
	for e: int in Elements.E.values():
		elements[Elements.element_name(e)] = 1000
	var none: Dictionary = {"level": 36, "elements": elements, "moves": {}}
	assert_eq(BalanceSim.rare_new_arts(none).size(), carried.size(), "never picked counts as 0")
	var moves: Dictionary = {}
	for art: String in carried:
		moves[art] = {"used": 10, "kos": 0}
	moves[carried[0]] = {"used": 9, "kos": 0}
	var rare: Array[Dictionary] = BalanceSim.rare_new_arts({"level": 36, "elements": elements, "moves": moves})
	assert_eq(rare.size(), 1)
	assert_eq(rare[0].art, carried[0])
	var text: String = "\n".join(BalanceSim.rare_arts_report({"level": 36, "elements": elements, "moves": moves}))
	assert_string_contains(text, "| %s |" % carried[0])

func test_double_knockouts_are_kept_apart_from_stalls() -> void:
	var r: Dictionary = BalanceSim.run(36, 2, 11)
	assert_true(r.has("double_kos"))
	var t: Dictionary = BalanceSim.run_team(30, 10, 4)
	assert_true(t.has("double_kos"))
	var draws: int = 0
	for n: String in r.species:
		draws += int(r.species[n].draws)
	assert_eq(draws, 2 * (int(r.draws) + int(r.double_kos)), "every no-winner duel is a draw for both species")
