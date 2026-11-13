extends MoveEffect
## {"id": "clear_drops"} (item 131): every lowered stage of the user goes back to 0; raised
## stages stay.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var any: bool = false
	for stat: String in BattleRules.STAGE_STATS:
		if ctx.user.stage(stat) < 0:
			any = true
			ctx.model.change_stage(ctx.user_side, stat, -ctx.user.stage(stat), ctx.user_slot)
	if not any:
		TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s has no drops to shake off.")
