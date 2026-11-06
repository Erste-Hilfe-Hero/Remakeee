class_name Gauntlet
extends RefCounted
## Lighthouse stair (item 46, plan area 8): FLOORS echo Wayfarers in three sections of SECTION
## floors. There is no healing inside a section; after every tenth floor a rest point heals the
## team and saves the run, so a later climb can start from there. Echo rings follow the story
## ring cap (GameState.progress_cap()), not the strongest Spirling, so grinding one Spirling up
## does not help. Every floor pays Waymarks the first time it is cleared.

const FLOORS: int = 30
const SECTION: int = 10
const TEAM_SIZE: int = 3
const BASE_PRIZE: int = 100
const PRIZE_STEP: int = 20
## Waymarks for clearing a floor the first time, and for every tenth floor.
const FLOOR_WAYMARKS: int = 5
const SECTION_WAYMARKS: int = 50
const REWARDS: Array[String] = ["echo_ember", "echo_tide", "echo_bloom", "echo_volt", "echo_stone", "echo_gale", "echo_lumen", "echo_umbra", "spark_charm", "max_tonic"]

var rng := RandomNumberGenerator.new()
var cap_level: int = 12
var seed_value: int = 0

## [param p_cap] is the story ring cap (GameState.progress_cap()).
func _init(p_seed: int, p_cap: int) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	cap_level = p_cap

## Fully evolved-for-their-level forms only, so echoes never field a Lv50 base form.
func _pool(level: int) -> Array[SpirlingData]:
	var out: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if level >= BalanceSim.min_level(sd) and not (evo_at > 0 and level >= evo_at):
			out.append(sd)
	if out.is_empty():
		out.assign(Database.spirlings.values())
	out.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	return out

## Ring of the echoes on floor [param floor_index] (0-based): from cap - 9 up to the cap on floor 30.
func level_for(floor_index: int) -> int:
	return clampi(cap_level - 9 + floor_index / 3, 5, Spirling.MAX_LEVEL)

## Trainer AI per section: greedy, lookahead, master.
static func ai_for(floor_index: int) -> int:
	return clampi(1 + floor_index / SECTION, 1, 3)

## The echo team for a floor; the same for the same run seed and floor.
func team(floor_index: int) -> Array[Spirling]:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d-%d" % [seed_value, floor_index])
	var lvl: int = level_for(floor_index)
	var pool: Array[SpirlingData] = _pool(lvl)
	var out: Array[Spirling] = []
	for i: int in TEAM_SIZE:
		out.append(Spirling.new(pool[r.randi_range(0, pool.size() - 1)], lvl, r))
	return out

func prize(floor_index: int) -> int:
	return BASE_PRIZE + PRIZE_STEP * floor_index

func reward_item() -> String:
	return REWARDS[rng.randi_range(0, REWARDS.size() - 1)]

static func is_rest_point(floors_cleared: int) -> bool:
	return floors_cleared > 0 and floors_cleared % SECTION == 0 and floors_cleared < FLOORS

## The floor (0-based) a climb can start from: the last rest point reached, or 0.
static func checkpoint() -> int:
	return clampi(int((GameState.records.get("tower_run", {}) as Dictionary).get("floor", 0)), 0, FLOORS - SECTION)

static func save_checkpoint(floors_cleared: int, p_seed: int) -> void:
	GameState.records["tower_run"] = {"floor": floors_cleared, "seed": p_seed}

static func clear_checkpoint() -> void:
	GameState.records.erase("tower_run")

## Seed of the saved run, so a continued climb meets the same echoes.
static func checkpoint_seed() -> int:
	return int((GameState.records.get("tower_run", {}) as Dictionary).get("seed", 0))

## Pays Waymarks the first time floor [param floors_cleared] (1-based) is cleared.
## Returns the reward lines (empty if this floor already paid).
static func pay_floor(floors_cleared: int) -> Array[String]:
	var paid: int = int(GameState.records.get("tower_paid", 0))
	if floors_cleared <= paid:
		return []
	GameState.records["tower_paid"] = floors_cleared
	var amount: int = SECTION_WAYMARKS if floors_cleared % SECTION == 0 else FLOOR_WAYMARKS
	return Waymarks.reward_lines(Waymarks.earn(amount, "tower"))

static func best() -> int:
	return clampi(int(GameState.records.get("gauntlet_best", 0)), 0, FLOORS)
