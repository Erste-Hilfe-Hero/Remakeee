extends MoveEffect
## {"id": "elem_ward"} (item 115): for 3 turns hits of x2 or more on the user's whole side land
## at three quarters.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	(TechniqueRules.state(ctx.model).ward as Array)[ctx.user_side] = ctx.model.turn + TechniqueRules.WARD_TURNS
	TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "A ward circle shields the side of %s from strong hits!")
