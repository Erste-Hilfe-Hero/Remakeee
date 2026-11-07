class_name DamageCalc
extends RefCounted
## Chimora's own damage curve (deliberately not the classic handheld formula):
##   dmg = (P * (A / D)^0.8 * (L / 5 + 3) / 12 + 1) * STAB * E * Crit * R
## Tuned so a same-level, neutral, 40-power move takes 15-25% of a balanced foe's HP
## (pinned by tests/unit/test_damage.gd).

const STAB: float = 1.25
const CRIT_MULT: float = 1.4
const CRIT_CHANCE: float = 1.0 / 12.0
const RATIO_EXP: float = 0.8
const LEVEL_DIV: float = 5.0
const LEVEL_OFFSET: float = 3.0
const SCALE_DIV: float = 12.0
const FLAT: float = 1.0
const ROLL_MIN: float = 0.90
const ROLL_MAX: float = 1.00
const ROLL_MEAN: float = (ROLL_MIN + ROLL_MAX) / 2.0

## Attack and defense stats used for [param move] (PHYSICAL: ATK vs DEF, FOCUS: FOC vs FOC).
## An ignore_stages move leaves the target's raised Guard or Focus stage out.
static func stats_for(user: Spirling, target: Spirling, move: MoveData) -> Vector2:
	if move.kind == MoveData.Kind.PHYSICAL:
		return Vector2(user.effective_atk(), _guarded(target, "def", target.effective_def(), move))
	return Vector2(user.effective_foc(), _guarded(target, "foc", target.effective_foc(), move))

static func _guarded(target: Spirling, stat: String, value: int, move: MoveData) -> float:
	var st: int = target.stage(stat)
	if move.ignore_stages and st > 0:
		return float(value) / BattleRules.stage_mult(st)
	return float(value)

static func stab_for(user: Spirling, move: MoveData) -> float:
	return STAB if move.element in user.elements() else 1.0

static func effectiveness(target: Spirling, move: MoveData) -> float:
	return Elements.multiplier(move.element, target.elements())

## Deterministic core of the formula, exposed for tests and the AI.
static func raw(user: Spirling, target: Spirling, move: MoveData, roll: float, crit: bool) -> float:
	if not move.is_damaging():
		return 0.0
	var ad: Vector2 = stats_for(user, target, move)
	var ratio: float = ad.x / maxf(ad.y, 1.0)
	var base: float = float(move.power) * pow(ratio, RATIO_EXP) * (float(user.level) / LEVEL_DIV + LEVEL_OFFSET) / SCALE_DIV + FLAT
	return base * stab_for(user, move) * effectiveness(target, move) * (CRIT_MULT if crit else 1.0) * roll

## Rolls crit and the random factor. Returns {"damage": int, "eff": float, "crit": bool}.
## [param mult] carries traits, held items, field and Overcharge (see BattleRules.damage_mult).
static func compute(user: Spirling, target: Spirling, move: MoveData, rng: RandomNumberGenerator, mult: float = 1.0, crit_mult: float = 1.0) -> Dictionary:
	if not move.is_damaging():
		return {"damage": 0, "eff": 1.0, "crit": false}
	var crit: bool = rng.randf() < CRIT_CHANCE * crit_mult
	var roll: float = rng.randf_range(ROLL_MIN, ROLL_MAX)
	var eff: float = effectiveness(target, move)
	var dmg: int = int(raw(user, target, move, roll, crit) * mult)
	return {"damage": maxi(dmg, 1) if eff > 0.0 else 0, "eff": eff, "crit": crit}

## Expected damage with the mean roll and no crit. Used by the AI.
static func estimate(user: Spirling, target: Spirling, move: MoveData) -> float:
	return raw(user, target, move, ROLL_MEAN, false)
