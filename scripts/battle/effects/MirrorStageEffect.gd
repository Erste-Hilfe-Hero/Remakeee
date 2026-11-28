extends MoveEffect
## {"id": "mirror_stage"} (item 150): the user copies the last stage change on the other side,
## raise or drop.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var last: Dictionary = (TechniqueRules.state(ctx.model).last_stage as Array)[ctx.target_side]
	if last.is_empty():
		TechniqueRules.say(ctx.model, ctx.user_side, ctx.user_slot, "%s finds nothing to mirror.")
		return
	ctx.model.change_stage(ctx.user_side, str(last.stat), int(last.delta), ctx.user_slot)
