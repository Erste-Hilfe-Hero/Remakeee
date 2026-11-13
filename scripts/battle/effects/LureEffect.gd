extends MoveEffect
## {"id": "lure"} (item 147): for 3 turns every single-target art of the other side goes to the
## user (TechniqueRules.lured_slot). Arts that sweep all foes are not drawn.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var st: Dictionary = TechniqueRules.state(ctx.model)
	(st.lure as Array)[ctx.user_side] = {"slot": ctx.user_slot, "who": ctx.user, "until": ctx.model.turn + TechniqueRules.LURE_TURNS - 1}
	TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s draws every eye to itself!")
