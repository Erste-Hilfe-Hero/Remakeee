extends MoveEffect
## {"id": "self_cost", "amount": float}: the user pays amount x its max Vigor, but never its last
## point, so an art that costs Vigor can't knock out its own user.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	if ctx.user == null or ctx.user.is_fainted() or ctx.user.hp <= 1:
		return
	var cost: int = mini(ctx.user.hp - 1, maxi(1, int(ctx.user.max_hp() * float(params.get("amount", 0.25)))))
	ctx.model.deal_damage(ctx.user_side, cost, {"recoil": true}, ctx.user_slot)
