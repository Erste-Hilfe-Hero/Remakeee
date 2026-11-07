extends GutTest
## 5000-point plan, area 2 (docs/plan5000/02_kampf.md, items 733, 810, 812, 846): the reference
## teams against the Wardens per difficulty. The CI run uses few battles, so the bands get a margin.

const ROUNDS: int = 12
const MARGIN: float = 0.1

static var _result: Dictionary = {}

func before_all() -> void:
	Database.load_all()
	if _result.is_empty():
		_result = BalanceSim.run_warden(ROUNDS, 1234)

## Mean win rate per "section|warden|difficulty" over the reference teams.
func _means() -> Dictionary:
	var sum: Dictionary = {}
	var n: Dictionary = {}
	for row: Dictionary in _result.rows:
		var key: String = "%s|%s|%s" % [row.section, row.warden, row.difficulty]
		sum[key] = float(sum.get(key, 0.0)) + float(row.win_rate)
		n[key] = int(n.get(key, 0)) + 1
	var out: Dictionary = {}
	for k: String in sum:
		out[k] = float(sum[k]) / n[k]
	return out

func test_ref_teams_have_three_teams_per_section_from_real_kinds() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BalanceSim.REF_TEAMS_PATH))
	assert_eq(cfg.sections.keys().size(), 3)
	for sec: String in cfg.sections:
		assert_eq(cfg.sections[sec].teams.size(), 3, sec)
		var starters: Array[String] = []
		for team: Array in cfg.sections[sec].teams.values():
			for e: Dictionary in team:
				assert_not_null(Database.species(str(e.species)), str(e.species))
				assert_lte(int(e.level), int(cfg.sections[sec].cap), "%s stays under the level cap" % e.species)
			starters.append(str(team[0].species))
		assert_eq(starters.size(), 3)

func test_every_team_meets_every_warden_on_every_difficulty() -> void:
	# 3 sections: Orrin, Maelis, both rematches = 4 pairings x 3 teams x 4 difficulties.
	assert_eq(_result.rows.size(), 4 * 3 * 4)
	for row: Dictionary in _result.rows:
		assert_eq(int(row.wins) + int(row.losses) + int(row.draws), ROUNDS)

func test_first_fights_land_in_the_target_bands() -> void:
	var bands: Dictionary = BalanceSim.warden_targets()
	assert_eq(bands.size(), 4)
	var means: Dictionary = _means()
	for key: String in means:
		var parts: PackedStringArray = key.split("|")
		if parts[0] == "post_rifts":
			continue
		var band: Vector2 = bands[parts[2]]
		var wr: float = means[key]
		assert_between(wr, band.x - MARGIN, band.y + MARGIN, "%s: %d%%" % [key, roundi(wr * 100.0)])

func test_rematches_keep_the_difficulty_order() -> void:
	var means: Dictionary = _means()
	for w: String in ["warden_orrin", "warden_maelis"]:
		var last: float = 2.0
		for d: String in TrainerData.DIFFICULTY_KEYS:
			var wr: float = means["post_rifts|%s|%s" % [w, d]]
			assert_lte(wr, last + MARGIN, "%s %s" % [w, d])
			last = wr
		assert_gte(means["post_rifts|%s|story" % w], 0.9)

func test_same_seed_same_result_and_report_flags() -> void:
	var a: Dictionary = BalanceSim.run_warden(2, 99, 2, [0] as Array[int], ["pre_orrin"] as Array[String])
	var b: Dictionary = BalanceSim.run_warden(2, 99, 2, [0] as Array[int], ["pre_orrin"] as Array[String])
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_eq(a.rows.size(), 3)
	var text: String = BalanceSim.warden_report(_result)
	assert_string_contains(text, "| pre_orrin | ember_start | warden_orrin | story |")
