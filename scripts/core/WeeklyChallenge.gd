class_name WeeklyChallenge
extends RefCounted
## Weekly challenge (item 88, plan area 8): every calendar week the same five echo Wayfarers for everyone,
## drawn from a seed made from the week number, so friends can compare runs without any
## server. Each week has a field and a Warden-style rule. The prize can be claimed once a week.

const ROUNDS: int = 5
const TEAM_SIZE: int = 3
const PRIZE: int = 400
## Waymarks for the first full win of the week (plan 3183).
const WAYMARKS: int = 60
## Interim prizes in coins for reaching round 4 and round 5 (wins so far -> coins), once a week.
const INTERIM: Dictionary = {3: 100, 4: 150}
## Weekly board points per round won; all five plus 100 for full health stay within 400.
const POINTS_PER_ROUND: int = 60
const REWARDS: Array[String] = ["max_tonic", "spark_charm", "power_brew", "guard_brew", "focus_brew", "dash_brew", "keen_lens", "iron_burr"]

var week: String
var rng := RandomNumberGenerator.new()
var field: String
var rule: String
var level: int

## [param week_key] like "2026-W44"; [param cap_level] is the save's ring cap by story progress
## (GameState.progress_cap()), so everyone at the same point of the story meets the same rings.
func _init(week_key: String, cap_level: int) -> void:
	week = week_key
	rng.seed = hash("chimora-weekly-" + week_key)
	var fields: Array = BattleRules.FIELDS.keys()
	fields.sort()
	field = str(fields[rng.randi_range(0, fields.size() - 1)])
	var rules: Array = BattleRules.RULES.keys()
	rules.sort()
	rule = str(rules[rng.randi_range(0, rules.size() - 1)])
	level = clampi(cap_level, 8, Spirling.MAX_LEVEL)

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

## Pays the interim prize for [param wins] rounds won if it is due this week. Returns the coins
## paid (0 if none). [param rec] is this week's record (GameState.records["weekly"]).
static func claim_interim(rec: Dictionary, wins: int) -> int:
	if not INTERIM.has(wins):
		return 0
	var paid: Array = rec.get("interim", [])
	if wins in paid:
		return 0
	paid.append(wins)
	rec["interim"] = paid
	GameState.money += int(INTERIM[wins])
	return int(INTERIM[wins])

## Score line after a round (plan 3185): turns, power left and fainted Spirlings.
static func round_text(round_no: int, turns: int, party: Array[Spirling]) -> String:
	var hp: float = 0.0
	var fainted: int = 0
	for s: Spirling in party:
		hp += s.hp_fraction()
		if s.is_fainted():
			fainted += 1
	var pct: int = int(round(100.0 * hp / maxf(1.0, float(party.size()))))
	return Loc.t("Round %d of %d: %d turns, %d%% power left, %d fainted.") % [round_no, ROUNDS, turns, pct, fainted]

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
