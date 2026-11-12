class_name BundLife
extends RefCounted
## Bund life (Online 100, area 4): weekly bund goal, level 1-20, donations, board, search. Rules
## shared by the game and LocalBackend; the server does the same in 20261112000060_bund_events.sql
## from server_config.bund_life.

const CONFIG_PATH: String = "res://data/bund_life.json"
const MAX_LEVEL: int = 20

static func config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}

## Level 1-20: how many level floors [param xp] has reached.
static func level_for(xp: int, levels: Array) -> int:
	var n: int = 0
	for floor_xp: Variant in levels:
		n += 1 if xp >= int(floor_xp) else 0
	return clampi(n, 1, maxi(levels.size(), 1))

## Xp the next level needs, or -1 on the last level.
static func next_xp(level: int, levels: Array) -> int:
	return int(levels[level]) if level < levels.size() else -1

## The goal reward band for [param level]: the last one whose "from" it reached.
static func reward_for(level: int, bands: Array) -> Dictionary:
	var best: Dictionary = {"item": "strong_tonic", "count": 1}
	var best_from: int = -1
	for b: Dictionary in bands:
		if int(b.from) <= level and int(b.from) > best_from:
			best = b
			best_from = int(b.from)
	return best

## This week's goal kind and target for a bund of [param members].
static func goal_for(week_no: int, members: int, cfg: Dictionary) -> Dictionary:
	var rot: Array = cfg.get("goal_rotation", [])
	var pick: Dictionary = rot[week_no % rot.size()]
	return {"kind": str(pick.kind), "target": maxi(int(cfg.get("goal_min_target", 40)), int(pick.per_member) * members)}

## Xp for a donation of [param coins] and [param items] pieces.
static func donate_xp(coins: int, items: int, cfg: Dictionary) -> int:
	return coins / maxi(int(cfg.get("donate_coin_step", 100)), 1) * int(cfg.get("donate_coin_xp", 1)) \
		+ items * int(cfg.get("donate_item_xp", 5))

## "Battles won 25/40" style line for the goal of the week.
static func goal_text(goal: Dictionary) -> String:
	var kinds: Dictionary = {"battles": "Battles won", "bonds": "Bonds", "rests": "Rests"}
	return "%s %d/%d" % [Loc.t(str(kinds.get(str(goal.get("kind", "")), "Steps"))), int(goal.get("total", 0)), int(goal.get("target", 0))]

## A language code as players read it ("any" = every language).
static func lang_name(code: String) -> String:
	return Loc.t("Any language") if code == "any" else str(Loc.LANGUAGE_NAMES.get(code, code))
