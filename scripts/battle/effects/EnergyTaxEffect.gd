extends MoveEffect
## {"id": "energy_tax", "amount": turns}: for the next [amount] turns (default 2) every move the
## target uses costs BattleRules.ENERGY_TAX_COST more Energy. A fresh tax replaces an old one.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target == null or ctx.target.is_fainted():
		return
	var turns: int = int(params.get("amount", 0))
	if turns <= 0:
		turns = BattleRules.ENERGY_TAX_TURNS
	ctx.model.apply_energy_tax(ctx.target_side, turns, ctx.target_slot)
