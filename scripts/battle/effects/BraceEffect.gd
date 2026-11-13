extends MoveEffect
## {"id": "brace"} (KAMPF_PLAN_1000 item 123): the user braces, and for the rest of this turn the
## foe's arts glance off it (TechniqueRules.blocks_hit). Bracing twice in a row fails.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var st: Dictionary = TechniqueRules.state(ctx.model)
	var b: Dictionary = (st.brace as Dictionary).get(ctx.user, {})
	if int(b.get("turn", -9)) == ctx.model.turn - 1:
		st.brace[ctx.user] = {"turn": -9}
		TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s can't brace twice in a row!")
		return
	st.brace[ctx.user] = {"turn": ctx.model.turn}
	TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s braces itself!")
