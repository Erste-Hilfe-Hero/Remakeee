extends MoveEffect
## {"id": "energy_gain", "amount": float}: the user gains that much Energy (up to its cap).

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user == null or ctx.user.is_fainted():
		return
	ctx.model.change_energy(ctx.user_side, maxi(1, int(params.get("amount", 1.0))), ctx.user_slot)
