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
