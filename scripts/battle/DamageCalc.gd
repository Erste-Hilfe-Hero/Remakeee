class_name DamageCalc
## Damage = ((2L/5+2) * P * A/D / 50 + 2) * STAB * E * C * R
const STAB := 1.25
const CRIT_MULT := 1.5
const CRIT_CHANCE := 0.0625

static func compute(user: Spirling, target: Spirling, move: MoveData, rng := RandomNumberGenerator.new()) -> Dictionary:
	if move.kind == MoveData.Kind.STATUS or move.power <= 0:
		return {"damage": 0, "eff": 1.0, "crit": false}
	var a := user.atk() if move.kind == MoveData.Kind.PHYSICAL else user.foc()
	var d := target.def() if move.kind == MoveData.Kind.PHYSICAL else target.foc()
	if user.status == "scorch" and move.kind == MoveData.Kind.PHYSICAL:
		a = int(a * 0.75)
	var base := ((2.0 * user.level / 5.0 + 2.0) * move.power * float(a) / max(d, 1)) / 50.0 + 2.0
	var stab := STAB if move.element in user.data.elements else 1.0
	var eff := Elements.multiplier(move.element, target.data.elements)
	var crit := rng.randf() < CRIT_CHANCE
	var roll := rng.randf_range(0.90, 1.00)
	var dmg := int(base * stab * eff * (CRIT_MULT if crit else 1.0) * roll)
	return {"damage": max(dmg, 1) if eff > 0 else 0, "eff": eff, "crit": crit}
