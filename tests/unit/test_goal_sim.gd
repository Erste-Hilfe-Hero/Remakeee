extends GutTest
## Plan area 2, item 768: every bonus goal is reachable on Tamer. The reference team of
## tools/balance/goal_teams.json meets it in at least 20 % of 20 simulated battles.

const ROUNDS: int = 20
const MIN_RATE: float = 0.2

func test_every_goal_has_a_reference_team() -> void:
	var teams: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BalanceSim.GOAL_TEAMS_PATH)).teams
	for key: String in BattleGoals.all():
		assert_true(teams.has(key), "reference team for %s" % key)

func test_every_goal_is_met_often_enough_on_tamer() -> void:
	for key: String in BattleGoals.all():
		var rate: float = BalanceSim.goal_rate(key, ROUNDS, 1234)
		assert_gte(rate, MIN_RATE, "%s met in %d %% of battles" % [key, roundi(rate * 100.0)])
