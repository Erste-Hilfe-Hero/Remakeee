extends MoveEffect
## {"id": "drain", "amount": float}: user heals amount x damage dealt.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.damage_dealt <= 0 or ctx.user.is_fainted():
		return
	ctx.model.heal(ctx.user_side, maxi(1, int(ctx.damage_dealt * float(params.get("amount", 0.5)))))
