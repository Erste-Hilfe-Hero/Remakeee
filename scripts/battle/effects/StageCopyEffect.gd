extends MoveEffect
## {"id": "stage_copy"} (KAMPF_PLAN_1000 item 224): the user takes on every stage the target
## has right now, raised and lowered alike. Fails with a line when the two already match.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var moved: bool = false
	for stat: String in BattleRules.STAGE_STATS:
		var delta: int = ctx.target.stage(stat) - ctx.user.stage(stat)
		if delta != 0:
			ctx.model.change_stage(ctx.user_side, stat, delta, ctx.user_slot)
			moved = true
	if not moved:
		ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, {"side": ctx.user_side, "slot": ctx.user_slot, "name": ctx.user.display_name()})
