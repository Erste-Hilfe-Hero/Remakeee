extends MoveEffect
## {"id": "energy_drain", "amount": float}: target loses that much Energy, user gains it.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.target.is_fainted():
		return
	var taken: int = mini(ctx.target.energy, int(params.get("amount", 1.0)))
	if taken <= 0:
		return
	ctx.model.change_energy(ctx.target_side, -taken, ctx.target_slot)
	ctx.model.change_energy(ctx.user_side, taken, ctx.user_slot)
