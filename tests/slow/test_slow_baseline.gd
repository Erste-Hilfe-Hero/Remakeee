extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, item 864): the team run at ring 36 (3000
## battles, default seed) against tools/balance/baseline_lv36.json. A balance change that moves a
## species or art by more than 8 points fails here until the same commit writes a new baseline:
##   godot --headless --path . -s res://tools/balance_sim.gd -- --mode team --level 36 --rounds 3000 --json tools/balance/baseline_lv36.json
## Slow (about 50 s), so it runs in the nightly CI job (item 865).

func test_slow_team_run_matches_the_baseline() -> void:
	Database.load_all()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BalanceSim.BASELINE_PATH))
	assert_true(raw is Dictionary, "baseline file")
	var base: Dictionary = raw
	var r: Dictionary = BalanceSim.run_team(int(base.level), int(base.battles), 1234, int(base.get("ai", 2)))
	var cmp: Dictionary = BalanceSim.compare(r, base)
	assert_eq(str(cmp.mismatch), "")
	assert_eq(cmp.species, [], "species moved by more than 8 points: %s" % [cmp.species])
	assert_eq(cmp.moves, [], "arts moved by more than 8 points: %s" % [cmp.moves])

func test_slow_compare_flags_a_shift_over_eight_points() -> void:
	var base: Dictionary = {"mode": "team", "level": 36, "species": {"A": {"wins": 50, "losses": 50, "draws": 0}}, "moves": {}}
	var moved: Dictionary = {"mode": "team", "level": 36, "species": {"A": {"wins": 59, "losses": 41, "draws": 0}}, "moves": {}}
	var held: Dictionary = {"mode": "team", "level": 36, "species": {"A": {"wins": 57, "losses": 43, "draws": 0}}, "moves": {}}
	assert_eq((BalanceSim.compare(moved, base).species as Array).size(), 1, "+9 points is flagged")
	assert_eq((BalanceSim.compare(held, base).species as Array).size(), 0, "+7 points is not")
