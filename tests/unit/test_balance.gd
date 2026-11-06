extends GutTest
## Balancing simulator: reproducible, battles finish, and no species runs away with its stage.

func before_all() -> void:
	Database.load_all()

func test_same_seed_same_result() -> void:
	var only: Array[String] = ["Kindlop", "Puddlet", "Mossling"]
	var a: Dictionary = BalanceSim.run(10, 3, 5, only)
	var b: Dictionary = BalanceSim.run(10, 3, 5, only)
	assert_eq(a.species, b.species)
	assert_eq(a.battles, 18)

func test_stages_and_min_levels() -> void:
	assert_eq(BalanceSim.stage(Database.species("Kindlop")), 1)
	assert_eq(BalanceSim.stage(Database.species("Smoldrake")), 2)
	assert_eq(BalanceSim.stage(Database.species("Calderox")), 3)
	assert_eq(BalanceSim.min_level(Database.species("Kindlop")), 1)
	assert_eq(BalanceSim.min_level(Database.species("Smoldrake")), Database.species("Kindlop").evolve_level)

func test_battles_end_without_stalls() -> void:
	var r: Dictionary = BalanceSim.run(36, 2, 11)
	assert_eq(r.draws, 0, "some battle hit the %d-turn cap" % BalanceSim.MAX_TURNS)

## Guard band: wider than the report's 35-65% flags, so data tweaks get room but runaways fail CI.
func test_no_species_dominates_its_stage() -> void:
	var r: Dictionary = BalanceSim.run(36, 6, 2024)
	for n: String in r.species:
		var wr: float = BalanceSim.win_rate(r.species[n])
		assert_between(wr, 0.25, 0.75, "%s wins %d%% of same-stage fights at Lv36" % [n, int(wr * 100)])

func test_report_lists_every_species() -> void:
	var r: Dictionary = BalanceSim.run(36, 1, 3)
	var text: String = BalanceSim.report(r)
	for n: String in r.species:
		assert_string_contains(text, "| %s |" % n)

# --- Plan area 2: simulator modes and numbers (items 808, 809, 813-815, 849) ----------------

func test_named_switches_and_the_old_positional_form() -> void:
	var sim: GDScript = load("res://tools/balance_sim.gd")
	var named: Dictionary = sim.parse_args(PackedStringArray(["--level", "36", "--mode", "team", "--json", "out.json", "--rounds", "50"]))
	assert_eq(named, {"level": "36", "mode": "team", "json": "out.json", "rounds": "50"})
	var old: Dictionary = sim.parse_args(PackedStringArray(["20", "5", "report.md"]))
	assert_eq(old, {"level": "20", "rounds": "5", "out": "report.md"})

func test_duel_reports_turns_to_ko_and_first_mover_advantage() -> void:
	var r: Dictionary = BalanceSim.run(36, 2, 77)
	assert_true(r.has("ko_turns"))
	assert_between(float(r.first_advantage), 0.0, 1.0)
	var text: String = BalanceSim.report(r)
	assert_string_contains(text, "Turns to KO:")
	assert_string_contains(text, "First-mover advantage")

func test_json_carries_every_number() -> void:
	var r: Dictionary = BalanceSim.run(10, 1, 5, ["Kindlop", "Puddlet", "Mossling"])
	var back: Variant = JSON.parse_string(BalanceSim.to_json(r))
	assert_true(back is Dictionary)
	for key: String in ["species", "moves", "battles", "draws", "avg_turns", "level", "mode", "ko_turns", "first_advantage"]:
		assert_true((back as Dictionary).has(key), key)
	assert_false((back.species as Dictionary).is_empty())
	for n: String in back.species:
		assert_true((back.species[n] as Dictionary).has("win_rate"), n)

func test_team_mode_is_reproducible() -> void:
	var a: Dictionary = BalanceSim.run_team(20, 12, 9)
	var b: Dictionary = BalanceSim.run_team(20, 12, 9)
	assert_eq(a.species, b.species)
	assert_eq(a.moves, b.moves)
	assert_eq(a.battles, 12)

## Item 849: in random teams at ring 36 no species wins under 30% or over 70% of its battles.
func test_team_mode_keeps_every_species_in_band() -> void:
	var r: Dictionary = BalanceSim.run_team(36, 200, 7)
	assert_eq(int(r.draws), 0, "no team battle stalls")
	for n: String in r.species:
		var wr: float = BalanceSim.win_rate(r.species[n])
		# Target band 30-70% (plan item 849).
		assert_between(wr, 0.30, 0.70, "%s wins %d%% of team battles at ring 36" % [n, roundi(wr * 100.0)])
