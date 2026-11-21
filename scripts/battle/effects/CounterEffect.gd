extends MoveEffect
## {"id": "counter", "amount": 1.5} (item 126): pays back the physical damage the user took this
## turn back at the target, times amount. Acts late (priority -1) so the hits come first.

func apply(ctx: EffectContext, params: Dictionary) -> void:
	var taken: int = TechniqueRules.phys_taken(ctx.model, ctx.user)
	if taken <= 0 or ctx.user.is_fainted():
		TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s has nothing to pay back.")
		return
	var mult: float = float(params.get("amount", 0.0))
	var dmg: int = maxi(1, int(float(taken) * (mult if mult > 0.0 else TechniqueRules.COUNTER_MULT)))
	ctx.damage_dealt = ctx.model.deal_damage(ctx.target_side, dmg, {"move": ctx.move.move_name, "counter": true}, ctx.target_slot)
