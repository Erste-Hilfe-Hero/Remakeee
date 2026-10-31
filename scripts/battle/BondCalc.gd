class_name BondCalc
## Bond chance = base rate * (1 - HP%) * timing score * status bonus, + charm bonus
static func chance(target: Spirling, timing_score: float, charm_bonus := 0.0) -> float:
	var hp_factor := 1.0 - float(target.hp) / target.max_hp()
	var status_bonus := 1.5 if target.status != "" else 1.0
	var c := target.data.bond_rate * max(hp_factor, 0.1) * clamp(timing_score, 0.0, 1.0) * status_bonus
	return clamp(c + charm_bonus, 0.0, 0.95)
