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

## Endless stretch after the top floor (plan 3264-3265): echoes one ring stronger per floor up
## to ring ENDLESS_MAX_RING; every floor past this week's best pays ENDLESS_WAYMARKS, at most
## ENDLESS_WEEK_CAP a week.
const ENDLESS_MAX_RING: int = 60
const ENDLESS_WAYMARKS: int = 2
const ENDLESS_WEEK_CAP: int = 100
const DATA_PATH: String = "res://data/endgame.json"

static var _names: Array[String] = []

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
	return clampi(cap_level - 9 + floor_index / 3, 5, Spirling.STORY_RING)

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

## The 40 echo Wayfarer names of data/endgame.json (plan 3273).
static func names() -> Array[String]:
	if _names.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for n: Variant in (d as Dictionary).get("wanderer_names", []):
					_names.append(str(n))
	return _names

## Name of the echo on floor [param floor_index] of this run, the same for the same seed.
func echo_name(floor_index: int) -> String:
	var all: Array[String] = names()
	if all.is_empty():
		return "Echo Wayfarer %d" % (floor_index + 1)
	return "Echo %s" % all[absi(hash([seed_value, floor_index, 1])) % all.size()]

static func endless_open() -> bool:
	return GameState.has_flag("gauntlet_clear")

## Ring on endless floor [param k] (0-based): one above the top floor's ring per floor, capped.
func endless_level(k: int) -> int:
	return mini(level_for(FLOORS - 1) + 1 + k, ENDLESS_MAX_RING)

func endless_team(k: int) -> Array[Spirling]:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, k, 2])
	var lvl: int = endless_level(k)
	var pool: Array[SpirlingData] = _pool(lvl)
	var out: Array[Spirling] = []
	for i: int in TEAM_SIZE:
		out.append(Spirling.new(pool[r.randi_range(0, pool.size() - 1)], lvl, r))
	return out

static func endless_best() -> int:
	return int(GameState.records.get("endless_best", 0))

## Books [param floors] endless floors cleared in one run: best ever and this week's Waymarks.
static func pay_endless(floors: int) -> Array[String]:
	GameState.records["endless_best"] = maxi(endless_best(), floors)
	var wk: String = WeeklyChallenge.this_week()
	var rec: Dictionary = GameState.records.get("endless_week", {})
	if str(rec.get("week", "")) != wk and not GameState.time_went_back(str(rec.get("week", "")), wk):
		rec = {"week": wk, "floor": 0, "paid": 0}
	var new_floors: int = maxi(0, floors - int(rec.get("floor", 0)))
	rec["floor"] = maxi(int(rec.get("floor", 0)), floors)
	var amount: int = mini(new_floors * ENDLESS_WAYMARKS, maxi(0, ENDLESS_WEEK_CAP - int(rec.get("paid", 0))))
	rec["paid"] = int(rec.get("paid", 0)) + amount
	GameState.records["endless_week"] = rec
	return Waymarks.reward_lines(Waymarks.earn(amount, "tower")) if amount > 0 else ([] as Array[String])
