extends MoveEffect
## {"id": "heal_self", "amount": float}: user heals amount x max HP.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user.is_fainted():
		return
	ctx.model.heal(ctx.user_side, maxi(1, int(ctx.user.max_hp() * float(params.get("amount", 0.5)))), ctx.user_slot)
