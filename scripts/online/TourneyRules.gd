class_name TourneyRules
extends RefCounted
## The weekend tournament (Online 100, points 62, 74, 80): 8 players, knockout. Shared by the game
## and LocalTourney; the server does the same in 20261113000030_tourney_watch.sql from
## server_config.tourney (data/tourney.json).

const CONFIG_PATH: String = "res://data/tourney.json"
const DEFAULTS: Dictionary = {"days": [6, 7], "size": 8, "round_hours": 6, "finals_rows": 10, "keep_days": 35,
	"rewards": [{"item": "spark_charm", "count": 1}, {"item": "max_tonic", "count": 2}, {"item": "revival_leaf", "count": 1},
		{"item": "strong_tonic", "count": 1}]}
## How far a player came, by reward tier.
const TIER_TEXT: Array[String] = ["Winner", "Final", "Semi-final", "Took part"]

static func config() -> Dictionary:
	var c: Dictionary = DEFAULTS.duplicate(true)
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var v: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if v is Dictionary:
		c.merge(v, true)
	return c

## Rounds of a knockout with [param size] players (8 players: 3).
static func rounds(size: int) -> int:
	var n: int = 0
	var left: int = maxi(size, 2)
	while left > 1:
		left = (left + 1) / 2
		n += 1
	return n

## True on a tournament day (ISO weekday 1 = Monday ... 7 = Sunday, UTC).
static func is_day(cfg: Dictionary, unix: int) -> bool:
	var wd: int = int(Time.get_datetime_dict_from_unix_time(unix).weekday)
	return (cfg.get("days", [6, 7]) as Array).has(7 if wd == 0 else wd)

## True when result [param a] beats [param b]: a win, then more damage, then fewer rounds, then the
## earlier place. Results are {won, damage, rounds, place}.
static func beats(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.won) != bool(b.won):
		return bool(a.won)
	if int(a.damage) != int(b.damage):
		return int(a.damage) > int(b.damage)
	if int(a.rounds) != int(b.rounds):
		return int(a.rounds) < int(b.rounds)
	return int(a.place) < int(b.place)

## Reward tier from the round a player went out in (0 = never, the winner).
static func tier(cfg: Dictionary, total_rounds: int, out_round: int) -> int:
	if out_round == 0:
		return 0
	return mini(total_rounds - out_round + 1, (cfg.get("rewards", []) as Array).size() - 1)

## "Quarter-final", "Semi-final", "Final" for round [param r] of [param total].
static func round_name(r: int, total: int) -> String:
	match total - r:
		0: return "Final"
		1: return "Semi-final"
		2: return "Quarter-final"
	return "Round %d" % r
