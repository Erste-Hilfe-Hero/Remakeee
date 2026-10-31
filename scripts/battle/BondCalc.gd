class_name BondCalc
extends RefCounted
## Bond chance = bond_rate * max(1 - HP%, 0.1) * timing_score * (1.5 if statused) + charm bonus, capped at 0.95.
## The chance is never shown to the player (LEGAL.md: no live capture-odds meter).

const MIN_HP_FACTOR: float = 0.1
const STATUS_BONUS: float = 1.5
const MAX_CHANCE: float = 0.95

static func chance(target: Spirling, timing_score: float, charm_bonus: float = 0.0) -> float:
	var hp_factor: float = maxf(1.0 - target.hp_fraction(), MIN_HP_FACTOR)
	var status_bonus: float = STATUS_BONUS if not target.status.is_empty() else 1.0
	var c: float = target.data.bond_rate * hp_factor * clampf(timing_score, 0.0, 1.0) * status_bonus
	return clampf(c + charm_bonus, 0.0, MAX_CHANCE)
