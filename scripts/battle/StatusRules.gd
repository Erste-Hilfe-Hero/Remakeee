class_name StatusRules
extends RefCounted
## The statuses as data. Battle code reads these tables; nothing switches on status names.
## The numbers of the first six are Chimora's own and stay fixed (KAMPF_PLAN_1000 items 187,
## 201-203, pinned by tests/unit/test_status_values.gd): ticks 1/12 of max Vigor, Jolt 20 %,
## Daze x0.7 accuracy, Drowse 2 turns.

const NONE: String = ""

## Per-status rules:
##   tick_div:    lose max_hp / tick_div at end of turn (0 = none)
##   atk_mult / spd_mult / acc_mult: stat multipliers while afflicted
##   skip_chance: chance to lose the turn
##   turns:       [min, max] duration; [0, 0] = until the battle ends
##   blocks_swap: cannot swap out
##   sleeps:      cannot act while turns remain
##   energy_every: the turn's Energy gain is split over this many turns (2 = half the gain)
##   sure_hit:    the next damaging art aimed at it can't miss; the hit wears the status off
##   random_target: with several foes in front its single-target arts strike a random one
##   tag:         the short tag on the name plate (KAMPF_PLAN_1000 item 898); each language
##                gives its own (data/i18n), unique in that language
const RULES: Dictionary[String, Dictionary] = {
	"scorch": {"label": "Scorch", "tag": "SCO", "tick_div": 12, "atk_mult": 0.75, "turns": [0, 0]},
	"soak":   {"label": "Soak", "tag": "SOA",   "spd_mult": 0.5, "turns": [3, 3]},
	"root":   {"label": "Root", "tag": "ROO",   "tick_div": 12, "blocks_swap": true, "turns": [0, 0]},
	"jolt":   {"label": "Jolt", "tag": "JOL",   "skip_chance": 0.2, "turns": [0, 0]},
	"daze":   {"label": "Daze", "tag": "DAZ",   "acc_mult": 0.7, "turns": [3, 3]},
	"drowse": {"label": "Drowse", "tag": "DRO", "sleeps": true, "turns": [2, 2]},
	# Plan items 181-183: three statuses of Chimora's own.
	"spent":  {"label": "Spent", "tag": "SPE",  "energy_every": 2, "turns": [3, 3]},
	"marked": {"label": "Marked", "tag": "MAR", "sure_hit": true, "turns": [3, 3]},
	"muddle": {"label": "Muddle", "tag": "MUD", "random_target": true, "acc_mult": 0.9, "turns": [2, 2]},
}

## A boss (BattleModel.foe_boss) shrugs a status off in half the time (item 190): timed ones last
## half as long (rounded up), open-ended ones end after this many turns.
const BOSS_OPEN_TURNS: int = 4

## Short explanation with the numbers, for the battle guide (item 188).
const TEXTS: Dictionary[String, String] = {
	"scorch": "Loses 1/12 of its max Vigor each turn and its Might drops to 3/4. Lasts until cured.",
	"soak": "Its Pace is halved for 3 turns.",
	"root": "Loses 1/12 of its max Vigor each turn and can't step back. Lasts until cured.",
	"jolt": "Loses its turn 1 time in 5. Lasts until cured.",
	"daze": "Its arts hit only 7 times in 10 for 3 turns.",
	"drowse": "Can't act for 2 turns. Only one Spirling per side may drowse in a Wayfarer duel.",
	"spent": "Gains Energy only every second turn, for 3 turns.",
	"marked": "The next damaging art aimed at it can't miss; that hit wipes the mark off. Up to 3 turns.",
	"muddle": "Strikes a random foe when several stand in front, and aims a little worse (9 in 10), for 2 turns.",
}

static func exists(status: String) -> bool:
	return RULES.has(status)

static func label(status: String) -> String:
	return str(RULES.get(status, {}).get("label", ""))

## The short tag on the name plate in the current language (item 898): "SCO", in German "BRA".
static func tag(status: String) -> String:
	var t: String = str(RULES.get(status, {}).get("tag", ""))
	return Loc.t(t) if not t.is_empty() else ""

static func _num(status: String, key: String, default: float) -> float:
	if not RULES.has(status):
		return default
	return float(RULES[status].get(key, default))

static func atk_mult(status: String) -> float: return _num(status, "atk_mult", 1.0)
static func spd_mult(status: String) -> float: return _num(status, "spd_mult", 1.0)
static func acc_mult(status: String) -> float: return _num(status, "acc_mult", 1.0)
static func skip_chance(status: String) -> float: return _num(status, "skip_chance", 0.0)
static func tick_div(status: String) -> int: return int(_num(status, "tick_div", 0.0))

static func blocks_swap(status: String) -> bool:
	return bool(RULES.get(status, {}).get("blocks_swap", false))

static func sleeps(status: String) -> bool:
	return bool(RULES.get(status, {}).get("sleeps", false))

static func energy_every(status: String) -> int: return maxi(1, int(_num(status, "energy_every", 1.0)))

static func sure_hit(status: String) -> bool:
	return bool(RULES.get(status, {}).get("sure_hit", false))

static func random_target(status: String) -> bool:
	return bool(RULES.get(status, {}).get("random_target", false))

## The Energy a Spirling with [param status] gains this turn out of [param gain]: with
## energy_every 2 it gets half, the odd point on every second turn, so the sum stays exact.
static func energy_gain(status: String, gain: int, turn: int) -> int:
	var every: int = energy_every(status)
	if every <= 1 or gain <= 0:
		return gain
	return (gain + (every - 1 if turn % every == 0 else 0)) / every

## Turns a boss keeps a status that would last [param turns] (0 = open-ended).
static func boss_turns(turns: int) -> int:
	return BOSS_OPEN_TURNS if turns <= 0 else (turns + 1) / 2

static func text(status: String) -> String:
	return TEXTS.get(status, "")

## Rolls a duration for a newly applied status. 0 means it lasts until the battle ends.
static func roll_turns(status: String, rng: RandomNumberGenerator) -> int:
	var t: Array = RULES.get(status, {}).get("turns", [0, 0])
	if int(t[1]) <= 0:
		return 0
	return rng.randi_range(int(t[0]), int(t[1]))

## A small symbol per status beside its three-letter tag (item 162), so the tag reads by shape too,
## not by colour alone: whole pixels on a 5x5 grid, drawn in the tag's ink. Chimora's own marks.
const SYMBOLS: Dictionary[String, Array] = {
	"scorch": [[2, 0], [1, 1], [2, 1], [1, 2], [2, 2], [3, 2], [0, 3], [1, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4]],
	"soak": [[2, 0], [2, 1], [1, 2], [2, 2], [3, 2], [0, 3], [1, 3], [3, 3], [4, 3], [1, 4], [2, 4], [3, 4]],
	"root": [[0, 0], [1, 0], [0, 1], [2, 1], [1, 2], [3, 2], [2, 3], [4, 3], [3, 4], [4, 4]],
	"jolt": [[3, 0], [4, 0], [2, 1], [3, 1], [1, 2], [2, 2], [3, 2], [1, 3], [2, 3], [0, 4], [1, 4]],
	"daze": [[1, 0], [2, 0], [3, 0], [0, 1], [4, 1], [0, 2], [2, 2], [4, 2], [0, 3], [3, 3], [1, 4], [2, 4]],
	"drowse": [[0, 0], [1, 0], [2, 0], [3, 0], [2, 1], [1, 2], [0, 3], [1, 3], [2, 3], [3, 3], [4, 4]],
	"spent": [[0, 1], [1, 1], [2, 1], [3, 1], [4, 2], [0, 2], [0, 3], [1, 3], [2, 3], [3, 3], [4, 3]],
	"marked": [[0, 0], [4, 0], [1, 1], [3, 1], [2, 2], [1, 3], [3, 3], [0, 4], [4, 4]],
	"muddle": [[1, 0], [2, 0], [3, 0], [4, 1], [3, 2], [2, 2], [2, 4], [1, 2]],
}

## Status combinations (item 169). Only one status sits on a Spirling at a time, so a combo
## replaces the first status: Jolt on a Soaked Spirling washes the Soak off, takes hold anyway
## and the charge running through the water costs it its next turn for sure ("sure_skip").
const COMBOS: Dictionary[String, Dictionary] = {
	"soak>jolt": {"sure_skip": 1, "text": "The charge runs through the water: %s is jolted stiff!"},
}

static func symbol(status: String) -> Array:
	return SYMBOLS.get(status, [])

## The combo of [param status] landing on a Spirling that has [param had], or {}.
static func combo(had: String, status: String) -> Dictionary:
	return COMBOS.get("%s>%s" % [had, status], {})

## Turns left on a status as the info strip shows it under the tag: "" for an open-ended one.
static func turns_tag(turns: int) -> String:
	return str(turns) if turns > 0 else ""
