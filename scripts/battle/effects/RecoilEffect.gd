extends MoveEffect
## {"id": "recoil", "amount": float}: user takes amount x damage dealt.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.damage_dealt <= 0 or ctx.user.is_fainted():
		return
	ctx.model.deal_damage(ctx.user_side, maxi(1, int(ctx.damage_dealt * float(params.get("amount", 0.25)))), {"recoil": true}, ctx.user_slot)
