class_name Gauntlet
extends RefCounted
## Post-game tower (item 46): ROUNDS echo Wayfarers in a row, scaled to the player's strongest
## Spirling. Teams are drawn from every species the run's seed picks, so each climb differs.

const ROUNDS: int = 5
const TEAM_SIZE: int = 3
## Echo levels: strongest party level, plus this per round.
const LEVEL_STEP: int = 1
const BASE_PRIZE: int = 300
const REWARDS: Array[String] = ["echo_ember", "echo_tide", "echo_bloom", "echo_volt", "echo_stone", "echo_gale", "echo_lumen", "echo_umbra", "spark_charm", "max_tonic"]

var rng := RandomNumberGenerator.new()
var top_level: int = 5

func _init(seed_value: int, party: Array[Spirling]) -> void:
	rng.seed = seed_value
	for s: Spirling in party:
		top_level = maxi(top_level, s.level)

## Fully evolved-for-their-level forms only, so echoes never field a Lv50 base form.
func _pool(level: int) -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if level >= BalanceSim.min_level(sd) and not (evo_at > 0 and level >= evo_at):
			out.append(sd)
	if out.is_empty():
		out.assign(Database.spirlings.values())
	return out

func level_for(round_index: int) -> int:
	return clampi(top_level + LEVEL_STEP * round_index, 5, Spirling.MAX_LEVEL)

func team(round_index: int) -> Array[Spirling]:
	var lvl: int = level_for(round_index)
	var pool: Array[SpirlingData] = _pool(lvl)
	var out: Array[Spirling] = []
	for i: int in TEAM_SIZE:
		out.append(Spirling.new(pool[rng.randi_range(0, pool.size() - 1)], lvl, rng))
	return out

func prize(round_index: int) -> int:
	return BASE_PRIZE * (round_index + 1)

func reward_item() -> String:
	return REWARDS[rng.randi_range(0, REWARDS.size() - 1)]
