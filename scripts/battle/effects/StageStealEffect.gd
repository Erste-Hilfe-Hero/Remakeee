extends MoveEffect
## {"id": "stage_steal"}: takes one raised stage (Might, Guard, Focus or Pace, the highest first)
## from the target and gives it to the user. Fails with a line when nothing is raised.

func apply(ctx: EffectContext, _params: Dictionary) -> void:
	var best: String = ""
	for stat: String in BattleRules.STAGE_STATS:
		if ctx.target.stage(stat) > 0 and (best.is_empty() or ctx.target.stage(stat) > ctx.target.stage(best)):
			best = stat
	if best.is_empty():
		ctx.model.emit_event(BattleEvent.Type.STATUS_FAILED, {"side": ctx.target_side, "slot": ctx.target_slot, "name": ctx.target.display_name()})
		return
	ctx.model.change_stage(ctx.target_side, best, -1, ctx.target_slot)
	ctx.model.change_stage(ctx.user_side, best, 1, ctx.user_slot)
