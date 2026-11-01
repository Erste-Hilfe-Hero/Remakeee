class_name WeeklyChallenge
extends RefCounted
## Weekly challenge (item 88): every calendar week the same three echo Tamers for everyone,
## drawn from a seed made from the week number, so friends can compare runs without any
## server. Each week has a field and a Warden-style rule. The prize can be claimed once a week.

const ROUNDS: int = 3
const TEAM_SIZE: int = 3
const PRIZE: int = 400
const REWARDS: Array[String] = ["max_tonic", "spark_charm", "power_brew", "guard_brew", "focus_brew", "dash_brew", "keen_lens", "iron_burr"]

var week: String
var rng := RandomNumberGenerator.new()
var field: String
var rule: String
var level: int

## [param week_key] like "2026-W44"; [param top_level] is the player's strongest level.
func _init(week_key: String, top_level: int) -> void:
	week = week_key
	rng.seed = hash("chimora-weekly-" + week_key)
	var fields: Array = BattleRules.FIELDS.keys()
	fields.sort()
	field = str(fields[rng.randi_range(0, fields.size() - 1)])
	var rules: Array = BattleRules.RULES.keys()
	rules.sort()
	rule = str(rules[rng.randi_range(0, rules.size() - 1)])
	level = clampi(top_level + 2, 8, Spirling.MAX_LEVEL)

## The echo team for round [param i]; the same for everyone in the same week.
func team(i: int) -> Array[Spirling]:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s-%d" % [week, i])
	var pool: Array[SpirlingData] = []
	for sd: SpirlingData in Database.spirlings.values():
		var evo_at: int = BalanceSim.evolve_at(sd)
		if level >= BalanceSim.min_level(sd) and not (evo_at > 0 and level >= evo_at):
			pool.append(sd)
	pool.sort_custom(func(a: SpirlingData, b: SpirlingData) -> bool: return a.dex_id < b.dex_id)
	var out: Array[Spirling] = []
	for k: int in TEAM_SIZE:
		out.append(Spirling.new(pool[r.randi_range(0, pool.size() - 1)], level, r))
	return out

func reward_item() -> String:
	return REWARDS[rng.randi_range(0, REWARDS.size() - 1)]

## ISO-8601 week key ("YYYY-Www") for a unix time.
static func week_key(unix: int) -> String:
	var d: Dictionary = Time.get_date_dict_from_unix_time(unix)
	# ISO weekday: Monday 1 .. Sunday 7. Godot: Sunday 0 .. Saturday 6.
	var wd: int = int(d.weekday)
	if wd == 0:
		wd = 7
	# The Thursday of this week decides the ISO year.
	var thursday: int = unix + (4 - wd) * 86400
	var td: Dictionary = Time.get_date_dict_from_unix_time(thursday)
	var jan1: int = Time.get_unix_time_from_datetime_dict({"year": td.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var day_of_year: int = int((thursday - jan1) / 86400)
	return "%04d-W%02d" % [td.year, day_of_year / 7 + 1]

static func this_week() -> String:
	return week_key(Online.unix_now())
