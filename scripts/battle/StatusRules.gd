class_name StatusRules
extends RefCounted
## The six statuses as data. Battle code reads these tables; nothing switches on status names.

const NONE: String = ""

## Per-status rules:
##   tick_div:    lose max_hp / tick_div at end of turn (0 = none)
##   atk_mult / spd_mult / acc_mult: stat multipliers while afflicted
##   skip_chance: chance to lose the turn
##   turns:       [min, max] duration; [0, 0] = until the battle ends
##   blocks_swap: cannot swap out
##   sleeps:      cannot act while turns remain
const RULES: Dictionary[String, Dictionary] = {
	"scorch": {"label": "Scorch", "tick_div": 12, "atk_mult": 0.75, "turns": [0, 0]},
	"soak":   {"label": "Soak",   "spd_mult": 0.5, "turns": [3, 3]},
	"root":   {"label": "Root",   "tick_div": 12, "blocks_swap": true, "turns": [0, 0]},
	"jolt":   {"label": "Jolt",   "skip_chance": 0.2, "turns": [0, 0]},
	"daze":   {"label": "Daze",   "acc_mult": 0.7, "turns": [3, 3]},
	"drowse": {"label": "Drowse", "sleeps": true, "turns": [2, 2]},
}

static func exists(status: String) -> bool:
	return RULES.has(status)

static func label(status: String) -> String:
	return str(RULES.get(status, {}).get("label", ""))

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

## Rolls a duration for a newly applied status. 0 means it lasts until the battle ends.
static func roll_turns(status: String, rng: RandomNumberGenerator) -> int:
	var t: Array = RULES.get(status, {}).get("turns", [0, 0])
	if int(t[1]) <= 0:
		return 0
	return rng.randi_range(int(t[0]), int(t[1]))
