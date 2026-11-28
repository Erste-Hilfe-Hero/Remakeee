extends MoveEffect
## {"id": "energy_lock", "amount": float}: the target gains no Energy at the end of this turn and
## the next amount - 1 turns (1 when amount is 0). KAMPF_PLAN item 47.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target == null or ctx.target.is_fainted():
		return
	ctx.target.energy_lock = maxi(ctx.target.energy_lock, maxi(1, int(params.get("amount", 1.0))))
